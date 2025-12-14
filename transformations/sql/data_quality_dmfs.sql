grant execute data metric function on account to role ACCOUNTADMIN;
grant database role snowflake.data_metric_user to role ACCOUNTADMIN;
grant usage on database PC_DATAIKU_DB to role ACCOUNTADMIN;
grant usage on schema PC_DATAIKU_DB.PUBLIC to role ACCOUNTADMIN;
grant create data metric function on schema PC_DATAIKU_DB.PUBLIC to role ACCOUNTADMIN;



-- ============================================================================
-- PART 1: Use Built-in System DMFs with Expectations
-- ============================================================================

-- NULL_COUNT: All ID columns must have 0 NULLs
-- Note: If DMF already exists, use MODIFY instead of ADD
ALTER DYNAMIC TABLE PC_DATAIKU_DB.PUBLIC.MATCHES_SAMPLE_100_CLEAN
ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (tournament_id)
  EXPECTATION no_null_tournament_id (VALUE = 0);

ALTER DYNAMIC TABLE PC_DATAIKU_DB.PUBLIC.MATCHES_SAMPLE_100_CLEAN
ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (match_id)
  EXPECTATION no_null_match_id (VALUE = 0);

ALTER DYNAMIC TABLE PC_DATAIKU_DB.PUBLIC.MATCHES_SAMPLE_100_CLEAN
ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (winner_id)
  EXPECTATION no_null_winner_id (VALUE = 0);

ALTER DYNAMIC TABLE PC_DATAIKU_DB.PUBLIC.MATCHES_SAMPLE_100_CLEAN
ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (loser_id)
  EXPECTATION no_null_loser_id (VALUE = 0);

-- ACCEPTED_VALUES: Round validation - must be one of R16, R32, F, SF, QF
ALTER DYNAMIC TABLE PC_DATAIKU_DB.PUBLIC.MATCHES_SAMPLE_100_CLEAN
ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ACCEPTED_VALUES ON (match_round, match_round -> match_round IN ('R16', 'R32', 'F', 'SF', 'QF'))
  EXPECTATION valid_round (VALUE = 0);

-- ACCEPTED_VALUES: Hand validation - winner hand must be R or L
ALTER DYNAMIC TABLE PC_DATAIKU_DB.PUBLIC.PLAYERS_CLEAN
ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ACCEPTED_VALUES ON (hand, hand -> hand IN ('R', 'L') OR hand IS NULL)
  EXPECTATION valid_winner_hand (VALUE = 0);

-- ============================================================================
-- PART 2: Custom DMFs for Cross-Column Validations
-- ============================================================================

-- Custom DMF: Count invalid dates (dates before 1950)
CREATE OR REPLACE DATA METRIC FUNCTION PC_DATAIKU_DB.PUBLIC.dmf_invalid_match_date(arg_t1 TABLE(arg_match_date DATE))
RETURNS NUMBER
AS
$$
    SELECT COUNT(*)
    FROM arg_t1
    WHERE arg_match_date < '1950-01-01'::DATE
       OR arg_match_date IS NULL
$$;

-- 2. Alter the Dynamic Table with the corrected ON clause
ALTER DYNAMIC TABLE PC_DATAIKU_DB.PUBLIC.MATCHES_SAMPLE_100_CLEAN
ADD DATA METRIC FUNCTION PC_DATAIKU_DB.PUBLIC.dmf_invalid_match_date
  -- CORRECT SYNTAX: List ONLY the single column required by the DMF's TABLE input.
  ON (match_date)
  EXPECTATION valid_dates (VALUE = 0);

-- Custom DMF: Count invalid first serve statistics (points won > serves in)
CREATE OR REPLACE DATA METRIC FUNCTION PC_DATAIKU_DB.PUBLIC.dmf_invalid_first_serve_won(arg_t1 TABLE(arg_winner_first_serve_points_won INT, arg_winner_first_serves_in INT, arg_loser_first_serve_points_won INT, arg_loser_first_serves_in INT))
RETURNS NUMBER
AS
$$
    SELECT COUNT(*)
    FROM arg_t1
    WHERE (arg_winner_first_serve_points_won > arg_winner_first_serves_in AND arg_winner_first_serves_in IS NOT NULL AND arg_winner_first_serve_points_won IS NOT NULL)
       OR (arg_loser_first_serve_points_won > arg_loser_first_serves_in AND arg_loser_first_serves_in IS NOT NULL AND arg_loser_first_serve_points_won IS NOT NULL)
$$;

ALTER DYNAMIC TABLE PC_DATAIKU_DB.PUBLIC.MATCHES_SAMPLE_100_CLEAN
ADD DATA METRIC FUNCTION PC_DATAIKU_DB.PUBLIC.dmf_invalid_first_serve_won
  -- CORRECT SYNTAX: List the columns directly as the arguments for the DMF's TABLE input.
  ON (winner_first_serve_points_won, winner_first_serves_in, loser_first_serve_points_won, loser_first_serves_in)
  EXPECTATION no_invalid_first_serve (VALUE = 0);

-- Custom DMF: Count invalid break point statistics (saved > faced)
CREATE OR REPLACE DATA METRIC FUNCTION PC_DATAIKU_DB.PUBLIC.dmf_invalid_break_points(arg_t1 TABLE(arg_winner_break_points_saved INT, arg_winner_break_points_faced INT, arg_loser_break_points_saved INT, arg_loser_break_points_faced INT))
RETURNS NUMBER
AS
$$
    SELECT COUNT(*)
    FROM arg_t1
    WHERE (arg_winner_break_points_saved > arg_winner_break_points_faced AND arg_winner_break_points_faced IS NOT NULL AND arg_winner_break_points_saved IS NOT NULL)
       OR (arg_loser_break_points_saved > arg_loser_break_points_faced AND arg_loser_break_points_faced IS NOT NULL AND arg_loser_break_points_saved IS NOT NULL)
$$;

ALTER DYNAMIC TABLE PC_DATAIKU_DB.PUBLIC.MATCHES_SAMPLE_100_CLEAN
ADD DATA METRIC FUNCTION PC_DATAIKU_DB.PUBLIC.dmf_invalid_break_points
  -- CORRECT SYNTAX: List the columns directly.
  ON (winner_break_points_saved, winner_break_points_faced, loser_break_points_saved, loser_break_points_faced)
  EXPECTATION no_invalid_break_points (VALUE = 0);

