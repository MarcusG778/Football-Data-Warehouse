import pandas as pd 
from pathlib import Path
import numpy as np

script_folder = Path(__file__).parent.parent

prem_csv = script_folder / "data" / "raw" / "premier_league" / "premier_league_2526.csv"
laliga_csv = script_folder / "data" / "raw" / "la_liga" / "la_liga_2526.csv"
ligue_1_csv = script_folder / "data" / "raw" / "ligue_1" / "ligue_1_2526.csv"
bundesliga_csv = script_folder / "data" / "raw" / "bundesliga" / "bundesliga_2526.csv"
serie_a_csv = script_folder / "data" / "raw" / "serie_a" / "serie_a_2526.csv"

def get_league_table(league_csv, league, year):

    df = pd.read_csv(league_csv)

    teams = df["HomeTeam"].unique()

    team_dfs = {}

    for team in teams:

        home_df = df[df["HomeTeam"] == team]
        away_df = df[df["AwayTeam"] == team]

        total_games = len(home_df) + len(away_df)
        wins = (home_df["FTR"] == "H").sum() + (away_df["FTR"] == "A").sum()
        draws = (home_df["FTR"] == "D").sum() + (away_df["FTR"] == "D").sum()
        losses = (home_df["FTR"] == "A").sum() + (away_df["FTR"] == "H").sum()
        shots_total = home_df["HS"].sum() + away_df["AS"].sum()
        sot_total = home_df["HST"].sum() + away_df["AST"].sum()
        fouls_total = home_df["HF"].sum() + away_df["AF"].sum()
        corners_total = home_df["HC"].sum() + away_df["AC"].sum()
        yc_total = home_df["HY"].sum() + away_df["AY"].sum()
        rc_total = home_df["HR"].sum() + away_df["AR"].sum()

        shots_against_total = home_df["AS"].sum() + away_df["HS"].sum()
        sot_against_total = home_df["AST"].sum() + away_df["HST"].sum()
        fouls_against_total = home_df["AF"].sum() + away_df["HF"].sum()
        corners_against_total = home_df["AC"].sum() + away_df["HC"].sum()
        yc_against_total = home_df["AY"].sum() + away_df["HY"].sum()
        rc_against_total = home_df["AR"].sum() + away_df["HR"].sum()

        stats = {
            "Team": [team],
            "Games": [total_games],
            "FTG": [home_df["FTHG"].sum() + away_df["FTAG"].sum()],
            "FTGA": [home_df["FTAG"].sum() + away_df["FTHG"].sum()],
            "Wins": [wins],
            "Draws": [draws],
            "Losses": [losses],
            "HTG": [home_df["HTHG"].sum() + away_df["HTAG"].sum()],
            "HTWins": [(home_df["HTR"] == "H").sum() + (away_df["HTR"] == "A").sum()],
            "HTDraws": [(home_df["HTR"] == "D").sum() + (away_df["HTR"] == "D").sum()],
            "HTLosses": [(home_df["HTR"] == "A").sum() + (away_df["HTR"] == "H").sum()],
            "Shots_total": [shots_total],
            "SOT_total": [sot_total],
            "Fouls_total": [fouls_total],
            "Corners_total": [corners_total],
            "YC_total": [yc_total],
            "RC_total": [rc_total],
            "Shots_against_total": [shots_against_total],
            "SOT_against_total": [sot_against_total],
            "Fouls_against_total": [fouls_against_total],
            "Corners_against_total": [corners_against_total],
            "YC_against_total": [yc_against_total],
            "RC_against_total": [rc_against_total],
            "Win_rate_%": [round((wins) / total_games * 100, 1)],
            "Draw_rate_%": [round((draws) / total_games * 100, 1)],
            "Loss_rate_%": [round((losses) / total_games * 100, 1)],
            "Shots_avg": [round((shots_total) / total_games, 1)],
            "SOT_avg": [round((sot_total) / total_games, 1)],
            "Fouls_avg": [round((fouls_total) / total_games, 1)],
            "Corners_avg": [round((corners_total) / total_games, 1)],
            "YC_avg": [round((yc_total) / total_games, 1)],
            "RC_avg": [round((rc_total) / total_games, 1)],
            "Shots_against_avg": [round((shots_against_total) / total_games, 1)],
            "SOT_against_avg": [round((sot_against_total) / total_games, 1)],
            "Fouls_against_avg": [round((fouls_against_total) / total_games, 1)],
            "Corners_against_avg": [round((corners_against_total) / total_games, 1)],
            "YC_against_avg": [round((yc_against_total) / total_games, 1)],
            "RC_against_avg": [round((rc_against_total) / total_games, 1)],
        }

        team_dfs[team] = pd.DataFrame(stats)

    all_teams_df = pd.concat(team_dfs.values(), ignore_index=True)

    top_5_FTG = all_teams_df.sort_values(by="FTG", ascending=False).head(5)

    win_points = 3
    draw_points = 1 
    loss_points = 0 

    all_teams_df["Points"] = (
        (all_teams_df["Wins"] * win_points) + (all_teams_df["Draws"] * draw_points) + (all_teams_df["Losses"] * loss_points)
    )

    all_teams_df["GD"] = (
        (all_teams_df["FTG"] - all_teams_df["FTGA"])
    )
    table = all_teams_df[["Team", "Wins", "Draws", "Losses", "Points", "GD", "FTG", "FTGA"]].sort_values(by=["Points", "GD", "FTG"], ascending=[False, False, False])
    table["Position"] = range(1, len(all_teams_df) + 1)

    rules = {
        "premier_league": {
            "Champions": 1,
            "UCL": (2, 5),
            "UEL": (6, 7),
            "UECL": 8,
            "Relegated": (18, 20)
        },
        "la_liga": {
                    "Champions": 1,
                    "UCL": (2, 5),
                    "UEL": 6,
                    "UECL": 7,
                    "Relegated": (18, 20)
        },
        "bundesliga": {
                    "Champions": 1,
                    "UCL": (2, 4),
                    "UEL": 5,
                    "UECL": 6,
                    "Relegated": (17, 18)
                },
        "serie_a": {
                    "Champions": 1,
                    "UCL": (2, 4),
                    "UEL": (5, 6),
                    "UECL": 7,
                    "Relegated": (18, 20)
                },
        "ligue_1": {
                    "Champions": 1,
                    "UCL": (2, 3),
                    "UEL": 4,
                    "UECL": 5,
                    "Relegated": (17, 18)
                }
    }

    Prem_conditions = [
        table["Position"] == 1,
        table["Position"].between(2,5),
        table["Position"].between(6,7),
        table["Position"] == 8,
        table["Position"].between(18,20)
    ]

    Laliga_conditions = [
            table["Position"] == 1,
            table["Position"].between(2,5),
            table["Position"] == 6,
            table["Position"] == 7,
            table["Position"].between(18,20)
        ]
    
    Bundesliga_conditions = [
            table["Position"] == 1,
            table["Position"].between(2,4),
            table["Position"] == 5,
            table["Position"] == 6,
            table["Position"].between(17,18)
        ]

    Seriea_conditions = [
            table["Position"] == 1,
            table["Position"].between(2,4),
            table["Position"].between(5,6),
            table["Position"] == 7,
            table["Position"].between(18,20)
        ]

    Ligue1_conditions = [
                table["Position"] == 1,
                table["Position"].between(2,3),
                table["Position"] == 4,
                table["Position"] == 5,
                table["Position"].between(17,18)
            ]
    
    choices = ["Champions","UCL","UEL","UECL","Relegated"]

    league_rules = rules[league]

    print(league_rules.items(

    ))

    print(table)

    output_dir = Path(__file__).parent.parent / "data" / "league_tables"
    output_dir.mkdir(parents=True, exist_ok=True)
    file_path = output_dir / f"{league}_{year}_table.csv"
    table.to_csv(file_path, index=False)
    return file_path

get_league_table(prem_csv, "premier_league", "2526")
get_league_table(laliga_csv, "la_liga", "2526")
get_league_table(ligue_1_csv, "ligue_1", "2526")
get_league_table(bundesliga_csv, "bundesliga", "2526")
get_league_table(serie_a_csv, "serie_a", "2526")

