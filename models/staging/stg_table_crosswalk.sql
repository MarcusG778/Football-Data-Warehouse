WITH fbref_players AS (
    SELECT DISTINCT
        player,
        team,
        season_key
    FROM {{ ref('stg_fbref_player_season_stats') }}
),

understat_players AS (
    SELECT DISTINCT
        player,
        team,
        player_id,
        team_id,
        season_key
    FROM {{ ref('stg_understat_player_season_stats') }}
),

team_name_map AS (
    SELECT fbref_team, understat_team
    FROM {{ ref('team_name_map') }}
),

player_name_map AS (
    SELECT fbref_player, understat_player
    FROM {{ ref('player_name_map') }}
),

fbref_mapped AS (
    SELECT
        f.player AS fbref_player,
        f.team AS fbref_team,
        COALESCE(p.understat_player, f.player) AS matched_player,
        COALESCE(t.understat_team, f.team) AS matched_team,
        f.season_key
    FROM fbref_players f
    LEFT JOIN team_name_map t
        ON LOWER(TRIM(f.team)) = LOWER(TRIM(t.fbref_team))
    LEFT JOIN player_name_map p
        ON LOWER(TRIM(f.player)) = LOWER(TRIM(p.fbref_player))
)

SELECT
    f.fbref_player,
    f.fbref_team,
    u.player AS understat_player,
    u.team AS understat_team,
    u.player_id,
    u.team_id,
    f.season_key
FROM fbref_mapped f
LEFT JOIN understat_players u
    ON LOWER(TRIM(f.matched_player)) = LOWER(TRIM(u.player))
    AND LOWER(TRIM(f.matched_team)) = LOWER(TRIM(u.team))
    AND f.season_key = u.season_key