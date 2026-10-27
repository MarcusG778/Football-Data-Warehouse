{{
    config(
        materialized='view'
    )
}}

WITH latest_snapshot AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY league_key, season_key, team, player 
            ORDER BY snapshot_date DESC NULLS LAST, loaded_at DESC NULLS LAST
        ) AS rn
    FROM {{ source('raw', 'raw_fbref_player_season_stats') }}
),

deduplicated AS (
    SELECT * 
    FROM latest_snapshot
    WHERE rn = 1
)

SELECT
    league_key,
    season_key,
    snapshot_date,
    loaded_at,
    lower(trim("league")) as league,
    season,
    lower(trim("team")) as team,
    lower(trim("player")) as player,
    lower("nation") as nation,
    lower("pos") as pos,
    "age"::int as age,
    "Playing Time_MP"::int as matches_played,
    "Playing Time_Starts"::int as starts,
    "Playing Time_Min"::int as mins,
    "Playing Time_90s"::numeric as ninety_minutes,
    "Performance_Gls"::int as goals,
    "Performance_Ast"::int as assists,
    "Performance_G+A"::int as ga,
    "Performance_G-PK"::int as goals_no_pk,
    "Performance_PK"::int as pk_scored,
    "Performance_PKatt"::int as pk_attempted,
    "Performance_CrdY"::int as yellow_cards,
    "Performance_CrdR"::int as red_cards,
    "Per 90 Minutes_Gls"::numeric as goals_per_90,
    "Per 90 Minutes_Ast"::numeric as assists_per_90,
    "Per 90 Minutes_G+A"::numeric as ga_per_90,
    "Per 90 Minutes_G-PK"::numeric as goals_no_pk_per_90,
    "Per 90 Minutes_G+A-PK"::numeric as ga_no_pk_per_90
FROM deduplicated