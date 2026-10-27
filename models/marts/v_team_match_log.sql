{{
    config(
        materialized='view'
    )
}}

WITH home_matches AS (
    SELECT
        match_date,
        league_key,
        season_key,
        home_team AS team_name,
        away_team AS opponent_name,
        'home' AS venue,
        home_goals AS goals_for,
        away_goals AS goals_against,
        home_shots AS shots_for,
        away_shots AS shots_against,
        home_shots_on_target AS shots_on_target_for,
        away_shots_on_target AS shots_on_target_against,
        home_corners AS corners_for,
        away_corners AS corners_against,
        home_yellow_cards AS yellow_cards,
        home_red_cards AS red_cards,
        referee,
        CASE 
            WHEN full_time_result = 'h' THEN 3
            WHEN full_time_result = 'd' THEN 1
            ELSE 0 
        END AS points
    FROM {{ ref('stg_matches') }}
),

away_matches AS (
    SELECT
        match_date,
        league_key,
        season_key,
        away_team AS team_name,
        home_team AS opponent_name,
        'away' AS venue,
        away_goals AS goals_for,
        home_goals AS goals_against,
        away_shots AS shots_for,
        home_shots AS shots_against,
        away_shots_on_target AS shots_on_target_for,
        home_shots_on_target AS shots_on_target_against,
        away_corners AS corners_for,
        home_corners AS corners_against,
        away_yellow_cards AS yellow_cards,
        away_red_cards AS red_cards,
        referee,
        CASE 
            WHEN full_time_result = 'a' THEN 3
            WHEN full_time_result = 'd' THEN 1
            ELSE 0 
        END AS points
    FROM {{ ref('stg_matches') }}
),

combined AS (
    SELECT * FROM home_matches
    UNION ALL
    SELECT * FROM away_matches
)

SELECT
    match_date,
    league_key,
    season_key,
    team_name,
    opponent_name,
    venue,
    goals_for,
    goals_against,
    goals_for - goals_against AS goal_difference,
    points,
    shots_for,
    shots_against,
    shots_on_target_for,
    corners_for,
    yellow_cards,
    red_cards,
    referee,
    SUM(points) OVER (
        PARTITION BY league_key, season_key, team_name 
        ORDER BY match_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_points
FROM combined