{{
    config(
        materialized='table'
    )
}}

WITH crosswalk AS (
    SELECT DISTINCT ON (league_key, season_key, fbref_team, fbref_player)
        league_key,
        season_key,
        fbref_player,
        fbref_team,
        understat_player,
        understat_team,
        player_id AS understat_player_id,
        team_id AS understat_team_id,
        match_status
    FROM {{ ref('int_player_crosswalk') }}
    ORDER BY league_key, season_key, fbref_team, fbref_player
),

fbref_stats AS (
    SELECT * FROM {{ ref('stg_fbref_player_season_stats') }}
),

understat_stats AS (
    SELECT DISTINCT ON (season_key, player_id)
        *
    FROM {{ ref('stg_understat_player_season_stats') }}
    ORDER BY season_key, player_id
),

-- Fallback mapping when team/league strings differ slightly across providers
fallback_understat_map AS (
    SELECT DISTINCT ON (season_key, REPLACE(LOWER(unaccent(player)), '-', ' '))
        season_key,
        REPLACE(LOWER(unaccent(player)), '-', ' ') AS clean_player_name,
        player_id AS fallback_player_id,
        team_id AS fallback_team_id
    FROM {{ ref('stg_understat_player_season_stats') }}
    ORDER BY season_key, REPLACE(LOWER(unaccent(player)), '-', ' ')
),

-- Map team history to prevent cross-player name collisions
player_team_master_ids AS (
    SELECT 
        fbref_player,
        fbref_team,
        MAX(player_id) AS canonical_understat_id
    FROM {{ ref('int_player_crosswalk') }}
    WHERE player_id IS NOT NULL
    GROUP BY fbref_player, fbref_team
),

combined AS (
    SELECT
        -- 1. Grain Identifiers
        md5(
            COALESCE(f.league_key, '') || '|' ||
            COALESCE(f.season_key, '') || '|' ||
            COALESCE(f.team, '') || '|' ||
            COALESCE(f.player, '')
        ) AS row_key,

        -- Resolved Understat Player ID
        COALESCE(
            c.understat_player_id::INT,
            ptm.canonical_understat_id::INT,
            fbs.fallback_player_id::INT
        ) AS resolved_understat_player_id,

        COALESCE(
            c.understat_team_id::INT,
            fbs.fallback_team_id::INT
        ) AS resolved_understat_team_id,

        -- Composite Entity ID
        COALESCE(
            c.understat_player_id::text,
            ptm.canonical_understat_id::text,
            fbs.fallback_player_id::text,
            'fbref_' || md5(f.player || '|' || f.team)
        ) AS entity_player_id,

        -- 2. League & Season Dimensions
        f.league_key,
        f.season_key,
        f.league AS league_name,
        f.season AS season_name,
        f.snapshot_date,

        -- 3. Player & Team Naming Dimensions
        f.player AS player_name,
        f.team AS team_name,
        c.understat_player AS understat_player_name,
        c.understat_team AS understat_team_name,
        c.match_status,

        -- 4. FBref Core Stats
        f.pos AS position,
        f.matches_played,
        f.starts AS matches_started,
        f.mins AS minutes_played,
        f.ninety_minutes,
        f.goals,
        f.assists,
        f.ga AS goal_assists,
        f.goals_no_pk AS non_penalty_goals,

        -- 5. Understat Advanced Metrics (Joined via Resolved ID & Season)
        u.matches_played AS understat_matches_played,
        u.mins AS understat_minutes_played,
        u.goals AS understat_goals,
        u.assists AS understat_assists,
        u.goals_no_pk AS understat_goals_no_pk,
        u.xg AS expected_goals,
        u.xg_no_pk AS non_penalty_xg,
        u.xa AS expected_assists,
        u.shots,
        u.key_passes,
        u.xg_chain,
        u.xg_buildup,

        -- 6. Rate Metrics
        ROUND(
            CAST(
                (COALESCE(u.xg, 0) / NULLIF(u.mins, 0)) * 90 
                AS NUMERIC
            ), 2
        ) AS expected_goals_per_90

    FROM fbref_stats f

    LEFT JOIN crosswalk c
        ON f.league_key = c.league_key
       AND f.season_key = c.season_key
       AND f.team = c.fbref_team
       AND f.player = c.fbref_player

    LEFT JOIN player_team_master_ids ptm
        ON f.player = ptm.fbref_player
       AND f.team = ptm.fbref_team

    -- Fallback mapping in player_season_combined.sql
    LEFT JOIN fallback_understat_map fbs
        ON f.season_key = fbs.season_key
    AND (
        -- Exact match
        REPLACE(LOWER(unaccent(f.player)), '-', ' ') = fbs.clean_player_name
        OR
        -- Handles "kylian mbappe" matching "kylian mbappe lottin"
        fbs.clean_player_name LIKE REPLACE(LOWER(unaccent(f.player)), '-', ' ') || '%'
    )
    
    LEFT JOIN understat_stats u
        ON COALESCE(c.understat_player_id::INT, ptm.canonical_understat_id::INT, fbs.fallback_player_id::INT) = u.player_id
       AND f.season_key = u.season_key
)

SELECT * FROM combined