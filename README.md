# ATP Insights

A Snowflake-native analytics platform for ATP tennis match data, featuring AI-powered match summaries, semantic search, and a conversational agent.

## Features

- **Dynamic Tables** - Automated data pipelines for match and player data with incremental refresh
- **AI Match Summaries** - Cortex-generated narrative summaries of matches using Mistral Large
- **Cortex Search** - Semantic search across match summaries by tournament, round, and characteristics
- **Cortex Agent** - Conversational AI assistant for querying tennis statistics and searching match narratives
- **Data Quality** - Built-in and custom Data Metric Functions (DMFs) with expectations
- **Row Access Policies** - Fine-grained security for data access control

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ATP_INSIGHTS Database                        │
├─────────────────────────────────────────────────────────────────────┤
│  Raw Tables (Dataiku)     →    Dynamic Tables    →    AI Services   │
│  ├─ ATP_MATCHES_RAW            ├─ MATCHES_CLEAN       ├─ Cortex Search
│  └─ ATP_PLAYERS_RAW            ├─ PLAYERS_CLEAN       └─ Cortex Agent
│                                └─ MATCHES_ENRICHED                   │
│                                     └─ AI summaries                  │
└─────────────────────────────────────────────────────────────────────┘
```

## Repository Structure

```
atp-insights/
├── snowflake/                  # Snowflake SQL scripts
│   ├── objects/                # Database objects
│   │   ├── stages/
│   │   ├── tables/             # Dynamic tables
│   │   └── functions/          # Custom DMFs
│   ├── ai/                     # Cortex AI services
│   │   ├── cortex_search.sql
│   │   ├── cortex_agent.sql
│   │   └── semantic_model.yaml
│   └── governance/             # Data governance
│       ├── access/             # Access control (who)
│       │   ├── grants.sql
│       │   └── row_access_policies.sql
│       └── quality/            # Data quality (what)
│           └── data_quality_policies.sql
├── infra/                      # Terraform configuration
│   ├── main.tf                 # Database, schema, roles, users, OAuth integration
│   ├── providers.tf
│   └── vars.tf
└── app/                        # Dataiku Dash application
    └── dash_app.py
```

## Prerequisites

- Snowflake account (Enterprise or Business Critical edition for Cortex AI features)
- Terraform installed (for infrastructure provisioning)
- ACCOUNTADMIN role access (for initial setup)
- Dataiku instance (for data ingestion and app hosting)

> **Note:** Cortex AI features (Cortex Search, Cortex Agent, CORTEX.COMPLETE) are **not available** on trial/free tier accounts. The dynamic tables and data quality features work on all editions.

## Deployment

### Step 1: Infrastructure (Terraform)

Deploy the database, schema, roles, and users:

```bash
cd infra
terraform init
terraform plan
terraform apply
```

This creates:
- Database: `ATP_INSIGHTS`
- Schema: `DEFAULT`
- Role: `DATAIKU_ROLE`
- Service User: `DATAIKU_SERVICE`
- OAuth Integration: `DATAIKU_OAUTH` (for Dataiku connection)

### Step 2: Database Objects

Run in order:

```sql
-- 1. Stages
@snowflake/objects/stages/semantic_models.sql

-- 2. Dynamic Tables
@snowflake/objects/tables/dynamic_tables.sql

-- 3. Custom Data Metric Functions
@snowflake/objects/functions/data_metric_functions.sql
```

### Step 3: AI Services

```sql
-- 1. Cortex Search Service
@snowflake/ai/cortex_search.sql

-- 2. Cortex Agent
@snowflake/ai/cortex_agent.sql
```

Upload the semantic model to the stage:
```sql
PUT file://snowflake/ai/semantic_model.yaml @ATP_INSIGHTS.DEFAULT.SEMANTIC_MODELS AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
```

### Step 4: Governance

```sql
-- 1. Grants for DATAIKU_ROLE
@snowflake/governance/access/grants.sql

-- 2. Row Access Policies (optional)
@snowflake/governance/access/row_access_policies.sql

-- 3. Data Quality Policies
@snowflake/governance/quality/data_quality_policies.sql
```

## Verification

After deployment, verify the objects:

```sql
-- Check dynamic tables
SHOW DYNAMIC TABLES IN SCHEMA ATP_INSIGHTS.DEFAULT;

-- Check Cortex Search (requires Cortex enabled account)
SHOW CORTEX SEARCH SERVICES IN SCHEMA ATP_INSIGHTS.DEFAULT;

-- Check Cortex Agent (requires Cortex enabled account)
SHOW AGENTS IN SCHEMA ATP_INSIGHTS.DEFAULT;

-- Query the enriched data directly
SELECT tournament_name, match_round, winner_id, loser_id, match_score
FROM ATP_INSIGHTS.DEFAULT.MATCHES_ENRICHED
LIMIT 10;
```

> **Note:** The Cortex Agent must be tested via the **Snowflake UI** (Snowsight), not via SQL. The `INVOKE_AGENT()` function is not available for SQL execution.

## Data Pipeline

### Dynamic Tables

| Table | Source | Refresh | Description |
|-------|--------|---------|-------------|
| `MATCHES_CLEAN` | Raw matches | Downstream | Cleaned match data with standardized columns |
| `PLAYERS_CLEAN` | Raw players | 1 day | Player profiles with formatted attributes |
| `MATCHES_ENRICHED` | MATCHES_CLEAN | 1 day | Calculated stats + AI match summaries |

## Governance

### Access Control

| Role | Purpose |
|------|---------|
| `DATAIKU_ROLE` | Full access for Dataiku integration |
| `USA_PLAYERS_VIEWERS` | Example: Can only view USA players |

#### Row Access Policies

The `usa_players_policy` demonstrates fine-grained access control - users with `USA_PLAYERS_VIEWERS` role only see players from the USA.

### Data Quality

Data Metric Functions monitor:
- **Null checks** - Required ID columns must not be null
- **Value validation** - Match rounds, player hand values
- **Cross-column validation** - First serve stats, break point stats
- **Date validation** - Match dates must be valid

## Cortex AI

### Semantic Model

The `semantic_model.yaml` defines:
- **Dimensions** - Tournament, player, match attributes
- **Facts** - Statistics (aces, double faults, break points, etc.)
- **Metrics** - Aggregations (averages, totals, percentages)
- **Filters** - Pre-built filters (Grand Slam, clay court, finals)

### Agent Tools

| Tool | Type | Description |
|------|------|-------------|
| Analyst | Text-to-SQL | Queries the semantic model for statistics |
| Search | Cortex Search | Searches match summaries semantically |

