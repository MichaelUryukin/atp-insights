-- ============================================================================
-- Custom Data Metric Functions (DMFs)
-- These functions are used to validate data quality on dynamic tables
-- ============================================================================

-- Custom DMF: Count invalid dates (dates before 1950)
CREATE OR REPLACE DATA METRIC FUNCTION ATP_INSIGHTS.DEFAULT.dmf_invalid_match_date(arg_t1 TABLE(arg_match_date DATE))
RETURNS NUMBER
AS
$$
    SELECT COUNT(*)
    FROM arg_t1
    WHERE arg_match_date < '1950-01-01'::DATE
       OR arg_match_date IS NULL
$$;

-- Custom DMF: Count invalid first serve statistics (points won > serves in)
CREATE OR REPLACE DATA METRIC FUNCTION ATP_INSIGHTS.DEFAULT.dmf_invalid_first_serve_won(arg_t1 TABLE(arg_winner_first_serve_points_won INT, arg_winner_first_serves_in INT, arg_loser_first_serve_points_won INT, arg_loser_first_serves_in INT))
RETURNS NUMBER
AS
$$
    SELECT COUNT(*)
    FROM arg_t1
    WHERE (arg_winner_first_serve_points_won > arg_winner_first_serves_in AND arg_winner_first_serves_in IS NOT NULL AND arg_winner_first_serve_points_won IS NOT NULL)
       OR (arg_loser_first_serve_points_won > arg_loser_first_serves_in AND arg_loser_first_serves_in IS NOT NULL AND arg_loser_first_serve_points_won IS NOT NULL)
$$;

-- Custom DMF: Count invalid break point statistics (saved > faced)
CREATE OR REPLACE DATA METRIC FUNCTION ATP_INSIGHTS.DEFAULT.dmf_invalid_break_points(arg_t1 TABLE(arg_winner_break_points_saved INT, arg_winner_break_points_faced INT, arg_loser_break_points_saved INT, arg_loser_break_points_faced INT))
RETURNS NUMBER
AS
$$
    SELECT COUNT(*)
    FROM arg_t1
    WHERE (arg_winner_break_points_saved > arg_winner_break_points_faced AND arg_winner_break_points_faced IS NOT NULL AND arg_winner_break_points_saved IS NOT NULL)
       OR (arg_loser_break_points_saved > arg_loser_break_points_faced AND arg_loser_break_points_faced IS NOT NULL AND arg_loser_break_points_saved IS NOT NULL)
$$;

