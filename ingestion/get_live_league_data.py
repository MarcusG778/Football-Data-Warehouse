import pandas as pd
import logging
from sqlalchemy import text, inspect
from utils.db import get_engine


logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

engine = get_engine()

leagues = {
    "premier_league": "E0",
    "bundesliga": "D1",
    "la_liga": "SP1",
    "serie_a": "I1",
    "ligue_1": "F1",
}

season = "2627"

def check_if_loaded(league, season):
    if not inspect(engine).has_table("raw_matches"):
        return set()

    query = text("""
        SELECT "Date", "HomeTeam", "AwayTeam"
        FROM raw_matches
        WHERE league = :league AND season = :season
    """)
    with engine.connect() as conn:
        rows = conn.execute(query, {"league": league, "season": season}).fetchall()
    return {(r[0], r[1], r[2]) for r in rows}
    
CORE_COLUMNS = [
    "Div", "Date", "Time", "HomeTeam", "AwayTeam",
    "FTHG", "FTAG", "FTR", "HTHG", "HTAG", "HTR",
    "Referee", "HS", "AS", "HST", "AST",
    "HF", "AF", "HC", "AC", "HY", "AY", "HR", "AR",
]



def insert_raw_data(league, code, season):
    
    url = f"https://www.football-data.co.uk/mmz4281/{season}/{code}.csv"
    try:
        df = pd.read_csv(url)
    except Exception as e:
        logger.warning(f"Failed to fetch {league} {season} ({url}): {e}")
        return
    
    available = [c for c in CORE_COLUMNS if c in df.columns]
    missing = set(CORE_COLUMNS) - set(available)
    if missing:
        logger.warning(f"{league} {season} missing expected columns: {missing}")

    df = df[available].copy()
    df["league"] = league
    df["season"] = season
    df["loaded_at"] = pd.Timestamp.now("UTC") 

    already_loaded = check_if_loaded(league, season)
    is_new = [
        (date, home, away) not in already_loaded
        for date, home, away in zip(df["Date"], df["HomeTeam"], df["AwayTeam"])
    ]
    new_rows = df[is_new]

    if new_rows.empty:
        logger.info(f"{league} {season}: no new matches")
        return

    new_rows.to_sql("raw_matches", engine, if_exists="append", index=False)
    logger.info(f"{league} {season}: loaded {len(new_rows)} new rows")
    
 
def main():
    for league, code in leagues.items():
        insert_raw_data(league, code, season)


if __name__ == "__main__":
    main()
