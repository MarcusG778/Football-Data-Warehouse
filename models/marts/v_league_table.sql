{{
    config(
        materialized='view'
    )
}}

WITH team_season_agg AS (
    SELECT
        league_key,
        season_key,
        team_name,
        COUNT(*) AS matches_played,
        SUM(CASE WHEN points = 3 THEN 1 ELSE 0 END) AS wins,
        SUM(CASE WHEN points = 1 THEN 1 ELSE 0 END) AS draws,
        SUM(CASE WHEN points = 0 THEN 1 ELSE 0 END) AS losses,
        SUM(goals_for) AS goals_for,
        SUM(goals_against) AS goals_against,
        SUM(goals_for) - SUM(goals_against) AS goal_difference,
        SUM(points) AS points,
        SUM(shots_for) AS total_shots_for,
        SUM(shots_on_target_for) AS total_shots_on_target,
        SUM(yellow_cards) AS total_yellow_cards,
        SUM(red_cards) AS total_red_cards
    FROM {{ ref('v_team_match_log') }}
    GROUP BY league_key, season_key, team_name
)

SELECT
    ROW_NUMBER() OVER (
        PARTITION BY league_key, season_key 
        ORDER BY points DESC, goal_difference DESC, goals_for DESC, team_name ASC
    ) AS league_position,
    league_key,
    season_key,
    team_name,
    matches_played,
    wins,
    draws,
    losses,
    goals_for,
    goals_against,
    goal_difference,
    points,
    -- Form metrics / averages
    ROUND(points::numeric / NULLIF(matches_played, 0), 2) AS points_per_match,
    total_shots_for,
    total_shots_on_target,
    total_yellow_cards,
    total_red_cards
FROM team_season_agg