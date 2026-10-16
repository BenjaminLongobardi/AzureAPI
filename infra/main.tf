locals {
  normalized_workload_name = lower(replace(var.workload_name, "-", ""))
  storage_name_prefix      = substr(local.normalized_workload_name, 0, min(10, length(local.normalized_workload_name)))
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags = {
    workload    = var.workload_name
    managed_by  = "terraform"
    environment = "private"
  }
}

resource "random_string" "suffix12" {
  length  = 12
  lower   = true
  upper   = false
  numeric = true
  special = false
  keepers = {
    resource_group = azurerm_resource_group.main.id
    workload_name  = var.workload_name
  }
}

resource "random_string" "suffix6" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
  keepers = {
    resource_group = azurerm_resource_group.main.id
    workload_name  = var.workload_name
  }
}

resource "random_string" "content_suffix8" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
  keepers = {
    resource_group = azurerm_resource_group.main.id
    workload_name  = var.workload_name
  }
}

locals {
  storage_account_name  = "st${local.storage_name_prefix}${random_string.suffix12.result}"
  function_app_name     = "${var.workload_name}-func-${random_string.suffix6.result}"
  app_service_plan_name = "${var.workload_name}-plan-${random_string.suffix6.result}"
  apim_name             = "${var.workload_name}-apim-${random_string.suffix6.result}"
  vnet_name             = "${var.workload_name}-vnet-${random_string.suffix6.result}"
  content_share_name    = "content${random_string.content_suffix8.result}"
}

resource "azurerm_virtual_network" "main" {
  name                = local.vnet_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vnet_address_prefix]
  tags                = azurerm_resource_group.main.tags
}

resource "azurerm_subnet" "apim" {
  name                 = "snet-apim"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.apim_subnet_prefix]
}

resource "azurerm_subnet" "private_endpoints" {
  name                              = "snet-private-endpoints"
  resource_group_name               = azurerm_resource_group.main.name
  virtual_network_name              = azurerm_virtual_network.main.name
  address_prefixes                  = [var.private_endpoint_subnet_prefix]
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_subnet" "function_integration" {
  name                 = "snet-function-integration"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.function_integration_subnet_prefix]

  delegation {
    name = "webapp-delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
}

resource "azurerm_storage_account" "functions" {
  name                            = local.storage_account_name
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
  tags                            = azurerm_resource_group.main.tags

  network_rules {
    default_action = "Deny"
    bypass         = ["None"]
  }
}

resource "azurerm_storage_share" "content" {
  name                 = local.content_share_name
  storage_account_name = azurerm_storage_account.functions.name
  quota                = 50
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone" "queue" {
  name                = "privatelink.queue.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone" "table" {
  name                = "privatelink.table.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone" "file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone" "webapp" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone" "apim" {
  name                = "azure-api.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "${azurerm_virtual_network.main.name}-blob-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "queue" {
  name                  = "${azurerm_virtual_network.main.name}-queue-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.queue.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "table" {
  name                  = "${azurerm_virtual_network.main.name}-table-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.table.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "file" {
  name                  = "${azurerm_virtual_network.main.name}-file-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.file.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "webapp" {
  name                  = "${azurerm_virtual_network.main.name}-webapp-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.webapp.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "apim" {
  name                  = "${azurerm_virtual_network.main.name}-apim-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.apim.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "${azurerm_storage_account.functions.name}-blob-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = azurerm_resource_group.main.tags

  private_service_connection {
    name                           = "storage-blob"
    private_connection_resource_id = azurerm_storage_account.functions.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}

resource "azurerm_private_endpoint" "storage_queue" {
  name                = "${azurerm_storage_account.functions.name}-queue-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = azurerm_resource_group.main.tags

  private_service_connection {
    name                           = "storage-queue"
    private_connection_resource_id = azurerm_storage_account.functions.id
    subresource_names              = ["queue"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.queue.id]
  }
}

resource "azurerm_private_endpoint" "storage_table" {
  name                = "${azurerm_storage_account.functions.name}-table-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = azurerm_resource_group.main.tags

  private_service_connection {
    name                           = "storage-table"
    private_connection_resource_id = azurerm_storage_account.functions.id
    subresource_names              = ["table"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.table.id]
  }
}

resource "azurerm_private_endpoint" "storage_file" {
  name                = "${azurerm_storage_account.functions.name}-file-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = azurerm_resource_group.main.tags

  private_service_connection {
    name                           = "storage-file"
    private_connection_resource_id = azurerm_storage_account.functions.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.file.id]
  }
}

resource "azurerm_service_plan" "function" {
  name                = local.app_service_plan_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Windows"
  sku_name            = "EP1"
  tags                = azurerm_resource_group.main.tags
}

resource "azurerm_windows_function_app" "hello" {
  name                          = local.function_app_name
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  service_plan_id               = azurerm_service_plan.function.id
  storage_account_name          = azurerm_storage_account.functions.name
  storage_account_access_key    = azurerm_storage_account.functions.primary_access_key
  https_only                    = true
  public_network_access_enabled = false
  virtual_network_subnet_id     = azurerm_subnet.function_integration.id
  functions_extension_version   = "~4"
  tags                          = azurerm_resource_group.main.tags

  site_config {
    minimum_tls_version    = "1.2"
    ftps_state             = "Disabled"
    vnet_route_all_enabled = true
    application_stack {
      powershell_core_version = "7.4"
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME                 = "powershell"
    WEBSITE_RUN_FROM_PACKAGE                 = "1"
    WEBSITE_VNET_ROUTE_ALL                   = "1"
    WEBSITE_CONTENTOVERVNET                  = "1"
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = azurerm_storage_account.functions.primary_connection_string
    WEBSITE_CONTENTSHARE                     = azurerm_storage_share.content.name
    AzureWebJobsStorage                      = azurerm_storage_account.functions.primary_connection_string
  }

  depends_on = [
    azurerm_private_endpoint.storage_blob,
    azurerm_private_endpoint.storage_queue,
    azurerm_private_endpoint.storage_table,
    azurerm_private_endpoint.storage_file
  ]
}

resource "azurerm_private_endpoint" "function_site" {
  name                = "${azurerm_windows_function_app.hello.name}-sites-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = azurerm_resource_group.main.tags

  private_service_connection {
    name                           = "functionapp-sites"
    private_connection_resource_id = azurerm_windows_function_app.hello.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.webapp.id]
  }
}

resource "azurerm_api_management" "main" {
  name                 = local.apim_name
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  publisher_name       = var.apim_publisher_name
  publisher_email      = var.apim_publisher_email
  sku_name             = "${var.apim_sku_name}_${var.apim_sku_capacity}"
  virtual_network_type = "Internal"
  tags                 = azurerm_resource_group.main.tags

  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim.id
  }
}

resource "azurerm_api_management_named_value" "function_backend_host" {
  name                = "function-backend-host"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  display_name        = "function-backend-host"
  value               = azurerm_windows_function_app.hello.default_hostname
}

resource "azurerm_api_management_api" "hello" {
  name                  = "hello-api"
  resource_group_name   = azurerm_resource_group.main.name
  api_management_name   = azurerm_api_management.main.name
  revision              = "1"
  display_name          = "Hello API"
  path                  = "hello"
  protocols             = ["https"]
  subscription_required = false

  import {
    content_format = "openapi+json"
    content_value  = file("${path.module}/apim/openapi.json")
  }
}

resource "azurerm_api_management_api_policy" "hello" {
  api_name            = azurerm_api_management_api.hello.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  xml_content         = file("${path.module}/apim/policy.xml")

  depends_on = [
    azurerm_api_management_named_value.function_backend_host
  ]
}

resource "azurerm_private_dns_a_record" "apim_gateway" {
  name                = azurerm_api_management.main.name
  zone_name           = azurerm_private_dns_zone.apim.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [azurerm_api_management.main.private_ip_addresses[0]]

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.apim
  ]
}
