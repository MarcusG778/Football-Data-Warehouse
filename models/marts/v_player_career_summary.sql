{{
    config(
        materialized='view'
    )
}}

WITH career_aggregated AS (
    SELECT
        entity_player_id,
        MAX(player_name) AS player_name,
        MAX(resolved_understat_player_id) AS understat_id, -- <--- ADDED HERE

        -- Career Span & Teams
        COUNT(DISTINCT season_key) AS total_seasons_played,
        MIN(season_key) AS earliest_season,
        MAX(season_name) AS latest_season,
        STRING_AGG(DISTINCT team_name, ', ' ORDER BY team_name) AS teams_played_for,
        STRING_AGG(DISTINCT league_name, ', ' ORDER BY league_name) AS leagues_played_in,
        STRING_AGG(DISTINCT position, ', ') AS positions_played,

        -- FBref & Combined Playing Time
        SUM(COALESCE(matches_played, 0)) AS total_matches,
        SUM(COALESCE(matches_started, 0)) AS total_starts,
        SUM(COALESCE(minutes_played, 0)) AS total_minutes,
        ROUND(SUM(COALESCE(ninety_minutes, 0)), 1) AS total_90s,

        -- Output Stats
        SUM(COALESCE(goals, 0)) AS total_goals,
        SUM(COALESCE(assists, 0)) AS total_assists,
        SUM(COALESCE(goal_assists, 0)) AS total_goal_contributions,
        SUM(COALESCE(non_penalty_goals, 0)) AS total_non_penalty_goals,

        -- Advanced Metrics (Understat)
        SUM(COALESCE(shots, 0)) AS total_shots,
        SUM(COALESCE(key_passes, 0)) AS total_key_passes,
        ROUND(SUM(COALESCE(expected_goals, 0)), 2) AS total_xg,
        ROUND(SUM(COALESCE(expected_assists, 0)), 2) AS total_xa,
        ROUND(SUM(COALESCE(non_penalty_xg, 0)), 2) AS total_non_penalty_xg,
        ROUND(SUM(COALESCE(xg_chain, 0)), 2) AS total_xg_chain,
        ROUND(SUM(COALESCE(xg_buildup, 0)), 2) AS total_xg_buildup,

        -- Variance & Finishing Clinicality
        ROUND(
            CAST(
                SUM(COALESCE(goals, 0)) - SUM(COALESCE(expected_goals, 0)) 
                AS NUMERIC
            ), 2
        ) AS goals_minus_xg,

        -- Per 90 Rate Metrics Across Career
        ROUND(
            CAST(
                (SUM(COALESCE(goals, 0))::NUMERIC / NULLIF(SUM(COALESCE(minutes_played, 0)), 0)) * 90 
                AS NUMERIC
            ), 2
        ) AS career_goals_per_90,

        ROUND(
            CAST(
                (SUM(COALESCE(expected_goals, 0))::NUMERIC / NULLIF(SUM(COALESCE(minutes_played, 0)), 0)) * 90 
                AS NUMERIC
            ), 2
        ) AS career_xg_per_90

    FROM {{ ref('player_season_combined') }}
    WHERE player_name IS NOT NULL
    GROUP BY entity_player_id
)

SELECT
    DENSE_RANK() OVER (ORDER BY total_goals DESC, total_xg DESC) AS career_goals_rank,
    DENSE_RANK() OVER (ORDER BY total_goal_contributions DESC, (total_xg + total_xa) DESC) AS career_g_plus_a_rank,
    *
FROM career_aggregated
ORDER BY career_goals_rank ASC