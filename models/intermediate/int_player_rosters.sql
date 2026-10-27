WITH fbref AS (
    SELECT DISTINCT
        'fbref' AS source,
        league,
        league_key,
        season,
        season_key,
        team,
        player,
        nation,
        pos
    FROM {{ ref('stg_fbref_player_season_stats') }}
),

understat AS (
    SELECT DISTINCT
        'understat' AS source,
        league,
        league_key,
        season,
        season_key,
        team,
        player,
        NULL::text AS nation,
        pos
    FROM {{ ref('stg_understat_player_season_stats') }}
)

SELECT * FROM fbref

UNION ALL

SELECT * FROM understat