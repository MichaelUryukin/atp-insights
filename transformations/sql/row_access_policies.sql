-- Create the role
CREATE ROLE IF NOT EXISTS USA_PLAYERS_VIEWERS
  COMMENT = 'Role for users who can only view players from USA';

-- Grant the role to ACCOUNTADMIN so it can assume this role for testing
GRANT ROLE USA_PLAYERS_VIEWERS TO ROLE ACCOUNTADMIN;

-- Grant needed permissions on PLAYERS_CLEAN table
GRANT USAGE ON DATABASE PC_DATAIKU_DB TO ROLE USA_PLAYERS_VIEWERS;
GRANT USAGE ON SCHEMA PC_DATAIKU_DB.PUBLIC TO ROLE USA_PLAYERS_VIEWERS;
GRANT SELECT ON TABLE PC_DATAIKU_DB.PUBLIC.PLAYERS_CLEAN TO ROLE USA_PLAYERS_VIEWERS;

-- Create the row access policy function
CREATE OR REPLACE ROW ACCESS POLICY PC_DATAIKU_DB.PUBLIC.usa_players_policy
AS (country VARCHAR) RETURNS BOOLEAN ->
  CASE
    -- If the current role is USA_PLAYERS_VIEWERS, only show USA players
    WHEN CURRENT_ROLE() = 'USA_PLAYERS_VIEWERS' THEN country = 'USA'
    -- For all other roles, show all players (no restriction)
    ELSE TRUE
  END;

-- Apply the row access policy to the PLAYERS_CLEAN table
ALTER TABLE PC_DATAIKU_DB.PUBLIC.PLAYERS_CLEAN
ADD ROW ACCESS POLICY PC_DATAIKU_DB.PUBLIC.usa_players_policy ON (country);



