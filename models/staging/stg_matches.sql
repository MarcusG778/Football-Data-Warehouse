{{
    config(
        materialized='view'
    )
}}

SELECT
    to_date("Date", 'DD/MM/YYYY') as match_date,
    lower(trim("HomeTeam")) as home_team,
    lower(trim("AwayTeam")) as away_team,
    lower(trim(league)) as league_key,
    season as season_key,
    "FTHG"::int as home_goals,
    "FTAG"::int as away_goals,
    lower("FTR") as full_time_result,
    "HS"::int as home_shots,
    "AS"::int as away_shots,
    "HST"::int as home_shots_on_target,
    "AST"::int as away_shots_on_target,
    "HC"::int as home_corners,
    "AC"::int as away_corners,
    "HY"::int as home_yellow_cards,
    "AY"::int as away_yellow_cards,
    "HR"::int as home_red_cards,
    "AR"::int as away_red_cards,
    lower(trim("Referee")) as referee
FROM {{ source('raw', 'raw_matches') }}