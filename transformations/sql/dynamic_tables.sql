-- Dynamic table for ATP match insights with meaningful column names
CREATE OR REPLACE DYNAMIC TABLE PC_DATAIKU_DB.PUBLIC.MATCHES_SAMPLE_100_CLEAN
TARGET_LAG =  'DOWNSTREAM'
WAREHOUSE = COMPUTE_WH
REFRESH_MODE = INCREMENTAL
AS
SELECT
    -- Tournament identifiers
    CAST("tourney_id" AS VARCHAR) AS tournament_id,
    CAST("tourney_name" AS VARCHAR) AS tournament_name,
    CASE "tourney_level"
        WHEN 'G' THEN 'Grand Slam'
        WHEN 'M' THEN 'Masters'
        WHEN 'A' THEN 'ATP Tour'
        WHEN 'F' THEN 'Futures'
        ELSE "tourney_level"
    END AS tournament_level,
    CAST("draw_size" AS INTEGER) AS tournament_draw_size,
    CAST("league" AS VARCHAR) AS tournament_league,
    CAST("best_of" AS INTEGER) AS tournament_best_of_sets,
    CAST("surface" AS VARCHAR) AS tournament_surface,

    -- Match identifiers
    CAST("match_num" AS VARCHAR) AS match_id,
    CAST("round" AS VARCHAR) AS match_round,
    CAST("tourney_date" AS DATE) AS match_date,
    CAST("minutes" AS INTEGER) AS match_duration_minutes,

    -- Winner information
    CAST("winner_id" AS VARCHAR) AS winner_id,
    CAST(NULLIF("winner_seed", 'nan') AS INTEGER) AS winner_seed,
    CASE NULLIF("winner_entry", 'nan')
        WHEN 'WC' THEN 'Wild Card'
        WHEN 'Q' THEN 'Qualifier'
        WHEN 'LL' THEN 'Lucky Loser'
        WHEN 'PR' THEN 'Protected Rating'
        ELSE 'Draw'
    END AS winner_entry,
    CAST("winner_age" AS FLOAT) AS winner_age,
    CAST("winner_rank" AS INTEGER) AS winner_rank,
    CAST("winner_rank_points" AS INTEGER) AS winner_rank_points,

    -- Loser information
    CAST("loser_id" AS VARCHAR) AS loser_id,
    CAST(NULLIF("loser_seed", 'nan') AS INTEGER) AS loser_seed,
    CASE NULLIF("loser_entry", 'nan')
        WHEN 'WC' THEN 'Wild Card'
        WHEN 'Q' THEN 'Qualifier'
        WHEN 'LL' THEN 'Lucky Loser'
        WHEN 'PR' THEN 'Protected Rating'
        ELSE NULLIF("loser_entry", 'nan')
    END AS loser_entry,
    CAST("loser_age" AS FLOAT) AS loser_age,
    CAST("loser_rank" AS INTEGER) AS loser_rank,
    CAST("loser_rank_points" AS INTEGER) AS loser_rank_points,

    -- Match results
    CAST("score" AS VARCHAR) AS match_score,

    -- Winner statistics (INTEGER)
    CAST("w_ace" AS INTEGER) AS winner_aces,
    CAST("w_df" AS INTEGER) AS winner_double_faults,
    CAST("w_svpt" AS INTEGER) AS winner_service_points,
    CAST("w_1stIn" AS INTEGER) AS winner_first_serves_in,
    CAST("w_1stWon" AS INTEGER) AS winner_first_serve_points_won,
    CAST("w_2ndWon" AS INTEGER) AS winner_second_serve_points_won,
    CAST("w_SvGms" AS INTEGER) AS winner_service_games,
    CAST("w_bpSaved" AS INTEGER) AS winner_break_points_saved,
    CAST("w_bpFaced" AS INTEGER) AS winner_break_points_faced,

    -- Loser statistics (INTEGER)
    CAST("l_ace" AS INTEGER) AS loser_aces,
    CAST("l_df" AS INTEGER) AS loser_double_faults,
    CAST("l_svpt" AS INTEGER) AS loser_service_points,
    CAST("l_1stIn" AS INTEGER) AS loser_first_serves_in,
    CAST("l_1stWon" AS INTEGER) AS loser_first_serve_points_won,
    CAST("l_2ndWon" AS INTEGER) AS loser_second_serve_points_won,
    CAST("l_SvGms" AS INTEGER) AS loser_service_games,
    CAST("l_bpSaved" AS INTEGER) AS loser_break_points_saved,
    CAST("l_bpFaced" AS INTEGER) AS loser_break_points_faced,

FROM
    PC_DATAIKU_DB.PUBLIC."node_7aea55bb_ATP_MATCHES_100_SNOWFLAKE";


-- Create daily schedule for data metrics
ALTER DYNAMIC TABLE PC_DATAIKU_DB.PUBLIC.MATCHES_SAMPLE_100_CLEAN SET DATA_METRIC_SCHEDULE = '1440 MINUTES';


-- Dynamic table for ATP players
CREATE OR REPLACE DYNAMIC TABLE PC_DATAIKU_DB.PUBLIC.PLAYERS_CLEAN
TARGET_LAG = '1 day'
WAREHOUSE = COMPUTE_WH
AS
SELECT
    CAST("player_id" AS VARCHAR) AS player_id,
    CAST("name_first" AS VARCHAR) AS first_name,
    CAST("name_last" AS VARCHAR) AS last_name,
    CASE "hand"
        WHEN 'R' THEN 'Right'
        WHEN 'L' THEN 'Left'
        ELSE "hand"
    END AS hand,
    CAST("country" AS VARCHAR) AS country,
    CAST("gender" AS VARCHAR) AS gender,
    TO_DATE("birthdate", 'YYYYMMDD') AS birthdate,

FROM
    PC_DATAIKU_DB.PUBLIC."node_7aea55bb_ATP_PLAYERS_SNOWFLAKE";

-- Create daily schedule for data metrics
ALTER DYNAMIC TABLE PC_DATAIKU_DB.PUBLIC.PLAYERS_CLEAN SET DATA_METRIC_SCHEDULE = '1440 MINUTES';


-- Enriched dynamic table with per-row calculations
CREATE OR REPLACE DYNAMIC TABLE PC_DATAIKU_DB.PUBLIC.MATCHES_SAMPLE_100_ENRICHED
TARGET_LAG = '1 day'
WAREHOUSE = COMPUTE_WH
REFRESH_MODE = INCREMENTAL
AS
SELECT
    -- All columns from MATCHES_SAMPLE_100_CLEAN
    *,
    
    -- Winner serve statistics (percentages)
    (winner_first_serves_in::FLOAT / winner_service_points) * 100 AS winner_first_serve_percentage,
    (winner_first_serve_points_won::FLOAT / winner_first_serves_in) * 100 AS winner_first_serve_win_percentage,
    (winner_second_serve_points_won::FLOAT / 
     (winner_service_points - winner_first_serves_in)) * 100 AS winner_second_serve_win_percentage,
    
    -- Loser serve statistics (percentages)
    (loser_first_serves_in::FLOAT / loser_service_points) * 100 AS loser_first_serve_percentage,
    (loser_first_serve_points_won::FLOAT / loser_first_serves_in) * 100 AS loser_first_serve_win_percentage,
    (loser_second_serve_points_won::FLOAT / 
     (loser_service_points - loser_first_serves_in)) * 100 AS loser_second_serve_win_percentage,
    
    -- Break point statistics (percentages)
    CASE WHEN loser_break_points_faced > 0
         THEN ((loser_break_points_faced - loser_break_points_saved)::FLOAT / loser_break_points_faced) * 100
         ELSE NULL
    END AS winner_break_point_conversion_rate,
    
    CASE WHEN winner_break_points_faced > 0
         THEN ((winner_break_points_faced - winner_break_points_saved)::FLOAT / winner_break_points_faced) * 100
         ELSE NULL
    END AS loser_break_point_conversion_rate,
    
    CASE WHEN winner_break_points_faced > 0
         THEN (winner_break_points_saved::FLOAT / winner_break_points_faced) * 100
         ELSE NULL
    END AS winner_break_point_save_percentage,
    
    CASE WHEN loser_break_points_faced > 0
         THEN (loser_break_points_saved::FLOAT / loser_break_points_faced) * 100
         ELSE NULL
    END AS loser_break_point_save_percentage,

    -- AI generated match summary
    SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large',
        'Write a tennis match summary (one paragraph maximum) using only the data provided. ' ||
        'focus on top match qualities (e.g. young vs old players, #1 vs #2 , etc. ' ||
        'capture the mood of the match (comeback, battle, domination, tight sets, swings, etc.' || CHR(10) ||
        ' dont exagurate - if the match wasnt a big battle - say it. ' ||   CHR(10) ||
        ' 6-3 is not tight. 7-6 is tight. ' ||   CHR(10) ||
        ' 5 sets match is a battle (in 5 set format). 3 set match is a battle in 3 set format only when tight.' ||   CHR(10) ||
        'try to explain why certain things happened using the statistics, instead of just stating the statistics (aces, first serve percentage, etc.).' ||   CHR(10) ||

        'Match data:' || CHR(10) ||
        'Tournament: ' || tournament_name || ' (' || tournament_level || ')' || CHR(10) ||
        'Surface: ' || tournament_surface || CHR(10) ||
        'Round: ' || match_round || CHR(10) ||
        'Duration: ' || match_duration_minutes || ' minutes' || CHR(10) ||

        'Winner:' || CHR(10) ||
        '- Rank: ' || winner_rank || CHR(10) ||
        '- Aces: ' || winner_aces || CHR(10) ||
        '- Age: ' || winner_age || CHR(10) ||
        '- Double Faults: ' || winner_double_faults || CHR(10) ||
        '- First Serves In: ' || winner_first_serves_in || CHR(10) ||
        '- First Serve Points Won: ' || winner_first_serve_points_won || CHR(10) ||
        '- Second Serve Points Won: ' || winner_second_serve_points_won || CHR(10) ||
        '- Service Games: ' || winner_service_games || CHR(10) ||
        '- Break Points Saved: ' || winner_break_points_saved || CHR(10) ||
        '- First servce percentage: ' || winner_first_serve_percentage || CHR(10) ||
        '- First serve win percentage: ' || winner_first_serve_win_percentage || CHR(10) ||
        '- Break Points Conversion Rate: ' || COALESCE(winner_break_point_conversion_rate::VARCHAR, 'N/A') || CHR(10) ||
        '- Break Points Save Percentage: ' || COALESCE(winner_break_point_save_percentage::VARCHAR, 'N/A') || CHR(10) ||

        'Loser:' || CHR(10) ||
        '- Player ID: ' || loser_id || CHR(10) ||
        '- Rank: ' || loser_rank || CHR(10) ||
        '- Age: ' || loser_age || CHR(10) ||
        '- Aces: ' || loser_aces || CHR(10) ||
        '- Double Faults: ' || loser_double_faults || CHR(10) ||
        '- First Serves In: ' || loser_first_serves_in || CHR(10) ||
        '- First Serve Points Won: ' || loser_first_serve_points_won || CHR(10) ||
        '- Second Serve Points Won: ' || loser_second_serve_points_won || CHR(10) ||
        '- Service Games: ' || loser_service_games || CHR(10) ||
        '- Break Points Saved: ' || loser_break_points_saved || CHR(10) ||
        '- Break Points Faced: ' || loser_break_points_faced || CHR(10) ||
        '- First servce percentage: ' || loser_first_serve_percentage || CHR(10) ||
        '- First serve win percentage: ' || loser_first_serve_win_percentage || CHR(10) ||
        '- Break Points Conversion Rate: ' || COALESCE(loser_break_point_conversion_rate::VARCHAR, 'N/A') || CHR(10) ||
        '- Break Points Save Percentage: ' || COALESCE(loser_break_point_save_percentage::VARCHAR, 'N/A') || CHR(10) ||
        'Score: ' || match_score) AS match_summary
    
FROM
    PC_DATAIKU_DB.PUBLIC.MATCHES_SAMPLE_100_CLEAN;

-- Create daily schedule for data metrics
ALTER DYNAMIC TABLE PC_DATAIKU_DB.PUBLIC.MATCHES_SAMPLE_100_ENRICHED SET DATA_METRIC_SCHEDULE = '5 MINUTE';



