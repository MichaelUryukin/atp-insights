variable "snowflake_organization_name" {
  description = "Snowflake organization name (e.g., 'LVJDWFU'). Can also be set via SNOWFLAKE_ORGANIZATION_NAME env var."
  type        = string
  default     = "LVJDWFU"
}

variable "snowflake_account_name" {
  description = "Snowflake account locator (e.g., 'UA41514'). Can also be set via SNOWFLAKE_ACCOUNT_NAME env var."
  type        = string
  default     = "UA41514"
}

variable "snowflake_role" {
  description = "Role used for database creation (falls back to env default when null)."
  type        = string
  default     = "ACCOUNTADMIN"
}

variable "snowflake_warehouse" {
  description = "Warehouse used for DDL execution (falls back to env default when null)."
  type        = string
  default     = "COMPUTE_WH"
}

variable "dataiku_oauth_redirect_uri" {
  description = "OAuth redirect URI for Dataiku integration"
  type        = string
  default     = "https://dss-7aea55bb-7e5a0c43-dku.eu-west-2.app.dataiku.io/dip/api/oauth2-callback"
}

