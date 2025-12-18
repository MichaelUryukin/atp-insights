-- ============================================================================
-- Data Quality Policies
-- Apply Data Metric Functions to Dynamic Tables
-- ============================================================================

-- Set data metric schedules for dynamic tables
ALTER DYNAMIC TABLE ATP_INSIGHTS.DEFAULT.MATCHES_CLEAN SET DATA_METRIC_SCHEDULE = '30 MINUTES';
ALTER DYNAMIC TABLE ATP_INSIGHTS.DEFAULT.PLAYERS_CLEAN SET DATA_METRIC_SCHEDULE = '30 MINUTES';

-- ============================================================================
-- Built-in System DMFs with Expectations
-- ============================================================================

-- NULL_COUNT: All ID columns must have 0 NULLs
ALTER DYNAMIC TABLE ATP_INSIGHTS.DEFAULT.MATCHES_CLEAN
ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (tournament_id)
  EXPECTATION no_null_tournament_id (VALUE = 0);

ALTER DYNAMIC TABLE ATP_INSIGHTS.DEFAULT.MATCHES_CLEAN
ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (match_id)
  EXPECTATION no_null_match_id (VALUE = 0);

ALTER DYNAMIC TABLE ATP_INSIGHTS.DEFAULT.MATCHES_CLEAN
ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (winner_id)
  EXPECTATION no_null_winner_id (VALUE = 0);

ALTER DYNAMIC TABLE ATP_INSIGHTS.DEFAULT.MATCHES_CLEAN
ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (loser_id)
  EXPECTATION no_null_loser_id (VALUE = 0);

-- ACCEPTED_VALUES: Round validation - must be one of R16, R32, F, SF, QF
ALTER DYNAMIC TABLE ATP_INSIGHTS.DEFAULT.MATCHES_CLEAN
ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ACCEPTED_VALUES ON (match_round, match_round -> match_round IN ('R16', 'R32', 'F', 'SF', 'QF'))
  EXPECTATION valid_round (VALUE = 0);

-- ACCEPTED_VALUES: Hand validation - winner hand must be R or L
ALTER DYNAMIC TABLE ATP_INSIGHTS.DEFAULT.PLAYERS_CLEAN
ADD DATA METRIC FUNCTION SNOWFLAKE.COREßß.ACCEPTED_VALUES ON (hand, hand -> hand IN ('Right', 'Left', 'Unknown') OR hand IS NULL)
  EXPECTATION valid_winner_hand (VALUE = 0);

-- ============================================================================
-- Custom DMFs Applied to Tables
-- ============================================================================

-- Apply custom DMF for invalid match dates
ALTER DYNAMIC TABLE ATP_INSIGHTS.DEFAULT.MATCHES_CLEAN
ADD DATA METRIC FUNCTION ATP_INSIGHTS.DEFAULT.dmf_invalid_match_date
  ON (match_date)
  EXPECTATION valid_dates (VALUE = 0);

-- Apply custom DMF for invalid first serve statistics
ALTER DYNAMIC TABLE ATP_INSIGHTS.DEFAULT.MATCHES_CLEAN
ADD DATA METRIC FUNCTION ATP_INSIGHTS.DEFAULT.dmf_invalid_first_serve_won
  ON (winner_first_serve_points_won, winner_first_serves_in, loser_first_serve_points_won, loser_first_serves_in)
  EXPECTATION no_invalid_first_serve (VALUE = 0);

-- Apply custom DMF for invalid break point statistics
ALTER DYNAMIC TABLE ATP_INSIGHTS.DEFAULT.MATCHES_CLEAN
ADD DATA METRIC FUNCTION ATP_INSIGHTS.DEFAULT.dmf_invalid_break_points
  ON (winner_break_points_saved, winner_break_points_faced, loser_break_points_saved, loser_break_points_faced)
  EXPECTATION no_invalid_break_points (VALUE = 0);

