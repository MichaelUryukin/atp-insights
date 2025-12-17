# Database
resource "snowflake_database" "atp_insights" {
  name    = "ATP_INSIGHTS"
  comment = "ATP Insights database"
}

# Schema
resource "snowflake_schema" "default" {
  database = snowflake_database.atp_insights.name
  name     = "DEFAULT"
  comment  = "Default schema for ATP Insights"
}

# Role
resource "snowflake_account_role" "dataiku_role" {
  name    = "DATAIKU_ROLE"
  comment = "Role for Dataiku service user"
}

# Grant DATAIKU_ROLE to ACCOUNTADMIN role
resource "snowflake_grant_account_role" "dataiku_role_accountadmin" {
  role_name       = snowflake_account_role.dataiku_role.name
  parent_role_name = "ACCOUNTADMIN"
}

# OAuth Security Integration for Dataiku
resource "snowflake_oauth_integration_for_custom_clients" "dataiku_oauth" {
  name                         = "DATAIKU_OAUTH"
  oauth_client_type            = "CONFIDENTIAL"
  oauth_redirect_uri           = var.dataiku_oauth_redirect_uri
  enabled                      = true
  oauth_issue_refresh_tokens   = true
  comment                      = "OAuth security integration for Dataiku connection"
}
