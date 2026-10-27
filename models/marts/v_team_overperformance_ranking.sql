{{
    config(
        materialized='view'
    )
}}

WITH team_summary AS (
    SELECT * FROM {{ ref('v_team_season_summary') }}
)

SELECT
    RANK() OVER (PARTITION BY league_key, season_key ORDER BY goals_scored DESC) AS league_goals_rank,
    RANK() OVER (PARTITION BY league_key, season_key ORDER BY xg_scored DESC) AS league_xg_rank,
    RANK() OVER (PARTITION BY league_key, season_key ORDER BY goals_minus_xg_team DESC) AS finishing_overperformance_rank,
    *
FROM team_summary
ORDER BY league_key, season_key, goals_scored DESC