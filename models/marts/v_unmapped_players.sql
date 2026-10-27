SELECT DISTINCT
    f.player AS fbref_player,
    f.team AS fbref_team,
    f.league_key,
    f.season_key,
    SUM(f.minutes) AS minutes_played
FROM {{ ref('stg_fbref_player_season_stats') }} f
LEFT JOIN {{ ref('int_player_crosswalk') }} c
    ON f.league_key = c.league_key
   AND f.season_key = c.season_key
   AND f.team = c.fbref_team
   AND f.player = c.fbref_player
WHERE c.player_id IS NULL AND f.minutes > 90
GROUP BY 1, 2, 3, 4
ORDER BY minutes_played DESC;