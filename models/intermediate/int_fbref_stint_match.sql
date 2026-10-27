with fbref as (
    select
        s.*,
        {{ normalize_name("coalesce(pm.understat_player, s.player)") }} as match_name,
        {{ normalize_name("coalesce(tm.understat_team, s.team)") }} as match_team
    from {{ ref('stg_fbref_player_season_stats') }} s
    left join (select distinct fbref_player, understat_player
               from {{ ref('player_name_map') }}) pm
        on {{ normalize_name('s.player') }} = {{ normalize_name('pm.fbref_player') }}
    left join (select distinct fbref_team, understat_team
               from {{ ref('team_name_map') }}) tm
        on {{ normalize_name('s.team') }} = {{ normalize_name('tm.fbref_team') }}
),

understat as (
    select
        league_key, season_key, player_id,
        {{ normalize_name('player') }} as match_name,
        {{ normalize_name('team') }} as match_team
    from {{ ref('stg_understat_player_season_stats') }}
),

per_id as (
    select
        f.league_key, f.season_key, f.player, f.team, u.player_id,
        bool_or(u.match_team = f.match_team) as team_match
    from fbref f
    join understat u
        on u.league_key = f.league_key
       and u.season_key = f.season_key
       and u.match_name = f.match_name
    group by 1, 2, 3, 4, 5
),

resolved as (
    select
        league_key, season_key, player, team,
        count(*) as n_candidates,
        case
            when count(*) = 1 then min(player_id)
            when count(*) filter (where team_match) = 1
                then min(player_id) filter (where team_match)
        end as understat_player_id
    from per_id
    group by 1, 2, 3, 4
)

select
    f.*,
    r.understat_player_id,
    coalesce(r.n_candidates, 0) as n_candidates
from {{ ref('stg_fbref_player_season_stats') }} f
left join resolved r
    on f.league_key = r.league_key
   and f.season_key = r.season_key
   and f.player = r.player
   and f.team = r.team