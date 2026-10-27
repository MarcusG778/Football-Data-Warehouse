{{
    config(
        materialized='view'
    )
}}

SELECT
    league_key,
    season_key,
    team_name,
    COUNT(DISTINCT entity_player_id) AS squad_size,
    SUM(COALESCE(matches_played, 0)) AS total_appearances,
    SUM(COALESCE(minutes_played, 0)) AS total_minutes_played,
    SUM(COALESCE(goals, 0)) AS goals_scored,
    ROUND(SUM(COALESCE(expected_goals, 0))::numeric, 2) AS xg_scored,
    SUM(COALESCE(assists, 0)) AS total_assists,
    ROUND(SUM(COALESCE(expected_assists, 0))::numeric, 2) AS xa_scored,
    SUM(COALESCE(shots, 0)) AS total_shots,
    ROUND(
        CAST(
            SUM(COALESCE(goals, 0)) - SUM(COALESCE(expected_goals, 0)) 
            AS NUMERIC
        ), 2
    ) AS goals_minus_xg_team
FROM {{ ref('player_season_combined') }}
WHERE team_name IS NOT NULL
GROUP BY league_key, season_key, team_name