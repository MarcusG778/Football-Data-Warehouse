select
    league_key,
    season_key,
    player_id,
    max(player) as player,
    string_agg(distinct team, ', ' order by team) as teams,
    count(*) as rows_merged,
    sum(matches_played) as matches_played,
    sum(mins) as mins,
    sum(goals) as goals,
    sum(assists) as assists,
    sum(goals_no_pk) as goals_no_pk,
    sum(xg) as xg,
    sum(xg_no_pk) as xg_no_pk,
    sum(xa) as xa,
    sum(shots) as shots,
    sum(key_passes) as key_passes,
    sum(yellow_cards) as yellow_cards,
    sum(red_cards) as red_cards,
    sum(xg_chain) as xg_chain,
    sum(xg_buildup) as xg_buildup
from {{ ref('stg_understat_player_season_stats') }}
group by league_key, season_key, player_id