{{
    config(
        materialized='view'
    )
}}

with ranked as (
    select
        *,
        ROW_NUMBER() OVER (
            PARTITION BY league_key, season_key, team_id, player_id 
            ORDER BY snapshot_date DESC NULLS LAST, loaded_at DESC NULLS LAST
        ) AS rn
    from {{ source('raw', 'raw_understat_player_season_stats') }}
) 

select
    league_key,
    season_key,
    snapshot_date,
    player_id,
    team_id,
    lower(trim("league")) as league,
    season,
    lower(trim("team")) as team,
    lower(trim("player")) as player,
    lower("position") as pos,
    "matches"::int as matches_played,
    "minutes"::int as mins,
    "goals"::int as goals,
    "assists"::int as assists,
    "np_goals"::int as goals_no_pk,
    "xg"::numeric as xg,
    "np_xg"::numeric as xg_no_pk,
    "xa"::numeric as xa,
    "shots"::int as shots,
    "key_passes"::int as key_passes,
    "yellow_cards"::int as yellow_cards,
    "red_cards"::int as red_cards,
    "xg_chain"::numeric as xg_chain,
    "xg_buildup"::numeric as xg_buildup
from ranked
where rn = 1