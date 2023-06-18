terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.59.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

# Create a service plan
resource "azurerm_service_plan" "appserviceplan" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "F1"
}

# Create a Linux web app
resource "azurerm_linux_web_app" "appservice" {
  name                = var.app_service_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.appserviceplan.location
  service_plan_id     = azurerm_service_plan.appserviceplan.id

  site_config {
    application_stack {
      dotnet_version = "6.0"
    }
    always_on = false
  }

  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = <<CONNECTION_STRING
	Data Source=tcp:${azurerm_mssql_server.sqlserver.fully_qualified_domain_name},1433;
	Initial Catalog=${azurerm_mssql_database.sqldatabase.name};
	User ID=${azurerm_mssql_server.sqlserver.administrator_login};
	Password=${azurerm_mssql_server.sqlserver.administrator_login_password};
	Trusted_Connection = False;
	MultipleActiveResultSets=True;
CONNECTION_STRING
  }
}

# Connect to GitHub repo
resource "azurerm_app_service_source_control" "appgit" {
  app_id                 = azurerm_linux_web_app.appservice.id
  repo_url               = var.repo_URL
  branch                 = "main"
  use_manual_integration = true
}

# Create a database server
resource "azurerm_mssql_server" "sqlserver" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password
}

# Create a database
resource "azurerm_mssql_database" "sqldatabase" {
  name           = var.sql_database_name
  server_id      = azurerm_mssql_server.sqlserver.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  sku_name       = "S0"
  zone_redundant = false
}

# Configure the database firewall
resource "azurerm_mssql_firewall_rule" "firewall" {
  name             = var.firewall_rule_name
  server_id        = azurerm_mssql_server.sqlserver.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
