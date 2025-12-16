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

# Service User
resource "snowflake_service_user" "dataiku_service" {
  name         = "DATAIKU_SERVICE"
  comment      = "Service user for Dataiku integration"
  default_role = "DATAIKU_ROLE"
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

# Assign DATAIKU_ROLE to DATAIKU_SERVICE user
resource "snowflake_grant_account_role" "dataiku_service_role" {
  role_name = snowflake_account_role.dataiku_role.name
  user_name = snowflake_service_user.dataiku_service.name
}
