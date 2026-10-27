{{
    config(
        materialized='table'
    )
}}

WITH fbref_players AS (
    SELECT DISTINCT
        league_key,
        season_key,
        team AS fbref_team,
        player AS fbref_player
    FROM {{ ref('stg_fbref_player_season_stats') }}
),

understat_players AS (
    SELECT DISTINCT
        league_key,
        season_key,
        team AS understat_team,
        player AS understat_player,
        player_id,
        team_id
    FROM {{ ref('stg_understat_player_season_stats') }}
),

seeds AS (
    SELECT 
        fbref_player,
        understat_player_name AS understat_player,
        understat_player_id::INT AS understat_player_id
    FROM {{ ref('player_name_map') }}
),

-- PASS 1: Seed Overrides WITH Team Verification (Resolves collisions like Rodri)
pass1_seed_with_team AS (
    SELECT
        f.league_key,
        f.season_key,
        f.fbref_player,
        f.fbref_team,
        s.understat_player,
        u.understat_team,
        s.understat_player_id AS player_id,
        u.team_id,
        'SEED_TEAM_VERIFIED' AS match_status
    FROM fbref_players f
    JOIN seeds s
        ON LOWER(f.fbref_player) = LOWER(s.fbref_player)
    JOIN understat_players u
        ON f.season_key = u.season_key
       AND s.understat_player_id = u.player_id
       AND LOWER(f.fbref_team) = LOWER(u.understat_team)
),

-- PASS 2: Global Seed Match for Transfers (For mid-season transfers across teams)
pass2_seed_global AS (
    SELECT
        f.league_key,
        f.season_key,
        f.fbref_player,
        f.fbref_team,
        s.understat_player,
        u.understat_team,
        s.understat_player_id AS player_id,
        u.team_id,
        'SEED_GLOBAL' AS match_status
    FROM fbref_players f
    JOIN seeds s
        ON LOWER(f.fbref_player) = LOWER(s.fbref_player)
    JOIN understat_players u
        ON f.season_key = u.season_key
       AND s.understat_player_id = u.player_id
),

-- Combine & prioritize Team-Verified Matches first to prevent duplicate fan-outs
unioned AS (
    SELECT * FROM pass1_seed_with_team
    UNION ALL
    SELECT * FROM pass2_seed_global
)

SELECT DISTINCT ON (league_key, season_key, fbref_team, fbref_player)
    *
FROM unioned
ORDER BY 
    league_key, 
    season_key, 
    fbref_team, 
    fbref_player,
    CASE match_status 
        WHEN 'SEED_TEAM_VERIFIED' THEN 1
        WHEN 'SEED_GLOBAL' THEN 2
        ELSE 3 
    END