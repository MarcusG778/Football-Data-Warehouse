with unmatched as (
    select
        s.league_key, s.season_key, s.player, s.team, s.mins,
        {{ normalize_name('s.player') }} as f_name,
        {{ normalize_name("coalesce(tm.understat_team, s.team)") }} as f_team
    from {{ ref('int_fbref_stint_match') }} s
    left join (select distinct fbref_team, understat_team
               from {{ ref('team_name_map') }}) tm
        on {{ normalize_name('s.team') }} = {{ normalize_name('tm.fbref_team') }}
    where s.understat_player_id is null
      and s.mins >= 450
),

understat as (
    select league_key, season_key, player_id, player, team,
           {{ normalize_name('player') }} as u_name,
           {{ normalize_name('team') }} as u_team
    from {{ ref('stg_understat_player_season_stats') }}
),

scored as (
    select
        f.league_key, f.season_key, f.player as fbref_player, f.team as fbref_team, f.mins,
        u.player as understat_player, u.player_id,
        round(similarity(f.f_name, u.u_name)::numeric, 2) as sim,
        (string_to_array(f.f_name, ' ') <@ string_to_array(u.u_name, ' ')
         or string_to_array(u.u_name, ' ') <@ string_to_array(f.f_name, ' ')) as words_contained
    from unmatched f
    join understat u
        on u.league_key = f.league_key
       and u.season_key = f.season_key
       and u.u_team = f.f_team
    where similarity(f.f_name, u.u_name) > 0.3
       or string_to_array(f.f_name, ' ') <@ string_to_array(u.u_name, ' ')
       or string_to_array(u.u_name, ' ') <@ string_to_array(f.f_name, ' ')
)

select *,
       row_number() over (
           partition by league_key, season_key, fbref_player, fbref_team
           order by words_contained desc, sim desc
       ) as candidate_rank
from scored

