resource "snowflake_database" "atp_insights" {
  name    = "ATP_INSIGHTS"
}

resource "snowflake_schema" "default" {
  database = snowflake_database.atp_insights.name
  name     = "DEFAULT"
}

