output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "virtual_network_name" {
  value = azurerm_virtual_network.main.name
}

output "storage_account_name" {
  value = azurerm_storage_account.functions.name
}

output "function_app_name" {
  value = azurerm_windows_function_app.hello.name
}

output "api_management_name" {
  value = azurerm_api_management.main.name
}

output "api_gateway_internal_url" {
  value = "https://${azurerm_api_management.main.name}.azure-api.net/hello"
}
