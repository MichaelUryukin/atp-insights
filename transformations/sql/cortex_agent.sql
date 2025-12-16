-- Create Cortex Agent with SQL tools and semantic model
CREATE OR REPLACE AGENT ATP_INSIGHTS.DEFAULT.ATP_CORTEX_AGENT
  COMMENT = 'ATP Insights Agent with Cortex Search and Analyst tools'
  FROM SPECIFICATION
  $$

orchestration:
  budget:
    seconds: 60
    tokens: 32000

instructions:
  response: "You are a helpful assistant for ATP tennis match insights. Provide clear, concise answers about tennis matches, players, and statistics."
  orchestration: "For data analysis questions use Analyst; for searching match summaries use Search"
  system: "You are an expert tennis analyst assistant that helps users understand ATP match data, player statistics, and tournament information."

tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "Analyst"
      description: "Converts natural language to SQL queries for analyzing ATP match data, player statistics, and tournament information"
  - tool_spec:
      type: "cortex_search"
      name: "Search"
      description: "Searches through ATP match summaries to find relevant matches based on tournament, round, and match characteristics"

tool_resources:
  Analyst:
    semantic_model_file: "@ATP_INSIGHTS.DEFAULT.SEMANTIC_MODELS/semantic_model.yaml"
    execution_environment:
      type: "warehouse"
      warehouse: "COMPUTE_WH"
      query_timeout: 60
  Search:
    name: "ATP_INSIGHTS.DEFAULT.ATP_CORTEX_SEARCH"
    max_results: 1
$$;

-- Grant USAGE on the agent
GRANT USAGE ON AGENT ATP_INSIGHTS.DEFAULT.ATP_CORTEX_AGENT TO ROLE PC_DATAIKU_ROLE;
