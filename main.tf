# Azure Private Endpoint to a target PaaS resource (Private Link). Gives a
# service a private IP inside your VNet so traffic never traverses the public
# internet.
#
# Flexible by design:
#   - Consume an EXISTING subnet (var.subnet_id) and EXISTING target
#     (var.target_resource_id) — the normal production wiring; or
#   - Set create_network = true to have the module build its own VNet + subnet,
#     and/or create_demo_target = true to stand up a locked-down demo Storage
#     Account target. With both on, one `tofu apply` produces a complete,
#     self-contained Private Link example (VNet + subnet + storage + endpoint).
#
# Secure defaults:
#   - Auto-approved connection to first-party targets (manual only when you opt
#     in for cross-tenant scenarios).
#   - The demo target Storage Account has public network access OFF, shared keys
#     OFF, TLS 1.2+, infrastructure (double) encryption ON and blob/container
#     soft delete (7 days) ON.
#   - Module-created subnets disable private-endpoint network policies so the
#     endpoint attaches cleanly.

locals {
  # Resolve the subnet/target from either the module-created resources or the
  # caller-supplied IDs. The conditional short-circuits, so the [0] index is only
  # evaluated when the matching create_* toggle is on (count = 1).
  subnet_id          = var.create_network ? azurerm_subnet.this[0].id : var.subnet_id
  target_resource_id = var.create_demo_target ? azurerm_storage_account.demo[0].id : var.target_resource_id

  # NOTE: a nested conditional (not coalesce) is required here. coalesce()
  # evaluates ALL its arguments eagerly, so it would dereference
  # random_string.demo_suffix[0] even when the caller supplied an explicit
  # demo_storage_account_name (in which case the random_string count is 0 and
  # [0] is an "Invalid index" error). The ternary short-circuits, so the
  # random suffix is only read on the branch where the resource exists.
  demo_storage_account_name = var.create_demo_target ? (
    var.demo_storage_account_name != null ? var.demo_storage_account_name : "stpe${random_string.demo_suffix[0].result}"
  ) : null

  # All private DNS zones the endpoint should register A records in: the
  # module-created zone (if any) plus any existing zones the caller passed.
  private_dns_zone_ids = concat(
    var.create_private_dns_zone ? [azurerm_private_dns_zone.this[0].id] : [],
    var.private_dns_zone_ids,
  )
}

# -----------------------------------------------------------------------------
# Optional dedicated network (create_network = true)
# -----------------------------------------------------------------------------

resource "azurerm_virtual_network" "this" {
  count = var.create_network ? 1 : 0

  name                = "vnet-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  # checkov:skip=CKV2_AZURE_31: optional convenience subnet that exists solely to host the private endpoint — the module disables private-endpoint network policies so the endpoint attaches cleanly, and with policies disabled NSG rules are not enforced on endpoint NICs
  count = var.create_network ? 1 : 0

  name                 = "snet-${var.name}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this[0].name
  address_prefixes     = var.subnet_address_prefixes

  # Private endpoints require endpoint network policies to be disabled on the
  # hosting subnet.
  private_endpoint_network_policies = "Disabled"
}

# -----------------------------------------------------------------------------
# Optional demo target (create_demo_target = true)
# -----------------------------------------------------------------------------

resource "random_string" "demo_suffix" {
  count = var.create_demo_target && var.demo_storage_account_name == null ? 1 : 0

  length  = 16
  lower   = true
  upper   = false
  numeric = true
  special = false
}

# Locked-down Storage Account used solely as a Private Link target. Public
# network access is OFF — it is reachable only through the private endpoint —
# which also means the provider performs no data-plane property poll on it.
resource "azurerm_storage_account" "demo" {
  # checkov:skip=CKV_AZURE_33: optional demo Private Link target (off by default) — public network access and shared keys are disabled, so the provider cannot manage data-plane queue logging properties, and the account stores no queue data
  # checkov:skip=CKV_AZURE_43: false positive — local.demo_storage_account_name resolves to "stpe" + 16 lowercase alphanumerics (20 chars, meets the 3-24 lowercase-alphanumeric rule); checkov cannot evaluate the local/random_string
  # checkov:skip=CKV_AZURE_206: LRS is deliberate for the disposable demo target (holds no data); production targets are caller-supplied via target_resource_id
  # checkov:skip=CKV2_AZURE_33: false positive — this module's azurerm_private_endpoint connects to this very account via local.target_resource_id; checkov cannot resolve the conditional local
  # checkov:skip=CKV2_AZURE_1: CMEK is out of scope for the disposable demo target (holds no data); platform-managed keys plus infrastructure (double) encryption are enabled
  count = var.create_demo_target ? 1 : 0

  name                = local.demo_storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"
  public_network_access_enabled     = false
  shared_access_key_enabled         = false
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true

  # Blob/container soft delete (management-plane properties, so they apply
  # cleanly even with public network access off).
  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  tags = merge(var.tags, { component = "private-endpoint-demo-target" })
}

# -----------------------------------------------------------------------------
# Optional private DNS zone + VNet link (create_private_dns_zone = true)
# -----------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "this" {
  count = var.create_private_dns_zone ? 1 : 0

  name                = var.private_dns_zone_name
  resource_group_name = var.resource_group_name
  tags                = var.tags

  lifecycle {
    precondition {
      condition     = var.private_dns_zone_name != null
      error_message = "private_dns_zone_name is required when create_private_dns_zone = true (e.g. \"privatelink.blob.core.windows.net\")."
    }
  }
}

# Link the created zone to the module-created VNet so workloads there resolve the
# privatelink record. Only meaningful when the module also created the network.
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  count = var.create_private_dns_zone && var.create_network ? 1 : 0

  name                  = "pdnsl-${var.name}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[0].name
  virtual_network_id    = azurerm_virtual_network.this[0].id
  registration_enabled  = false
  tags                  = var.tags
}

# -----------------------------------------------------------------------------
# The private endpoint
# -----------------------------------------------------------------------------

resource "azurerm_private_endpoint" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  subnet_id                     = local.subnet_id
  custom_network_interface_name = var.custom_network_interface_name
  tags                          = var.tags

  private_service_connection {
    name                           = "psc-${var.name}"
    private_connection_resource_id = local.target_resource_id
    subresource_names              = var.subresource_names
    is_manual_connection           = var.is_manual_connection
    request_message                = var.is_manual_connection ? var.request_message : null
  }

  dynamic "private_dns_zone_group" {
    for_each = length(local.private_dns_zone_ids) > 0 ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = local.private_dns_zone_ids
    }
  }

  lifecycle {
    precondition {
      condition     = local.subnet_id != null
      error_message = "No subnet for the endpoint: set subnet_id to an existing subnet, or create_network = true to have the module create one."
    }
    precondition {
      condition     = local.target_resource_id != null
      error_message = "No target for the endpoint: set target_resource_id to an existing PaaS resource, or create_demo_target = true to use the built-in demo Storage Account."
    }
    precondition {
      condition     = !var.is_manual_connection || var.request_message != null
      error_message = "request_message is required when is_manual_connection = true."
    }
  }
}
