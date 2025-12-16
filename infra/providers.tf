terraform {
  required_providers {
    snowflake = {
      source = "snowflakedb/snowflake"
    }
  }
}

locals {
  private_key_path  = "~/.ssh/snowflake_tf_snow_key.p8"
}

provider "snowflake" {
    organization_name = var.snowflake_organization_name
    account_name      = var.snowflake_account_name
    user              = "TERRAFORM_SVC"
    role              = var.snowflake_role
    authenticator     = "SNOWFLAKE_JWT"
    private_key       = file(local.private_key_path)
}
