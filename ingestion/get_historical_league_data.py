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

START_YEAR = 2020  
END_YEAR = 2025     


def season_code(year):
    return f"{str(year)[2:]}{str(year + 1)[2:]}"

def check_if_loaded(league, season):
    inspector = inspect(engine)
    if not inspector.has_table("raw_matches"):
        return False 
    query = text("""
    SELECT 1 FROM raw_matches
    WHERE league = :league AND season = :season
    LIMIT 1 
    """)
    with engine.connect() as conn:
        result = conn.execute(query, {"league": league, "season": season}).fetchone()
    return result is not None
    
CORE_COLUMNS = [
    "Div", "Date", "Time", "HomeTeam", "AwayTeam",
    "FTHG", "FTAG", "FTR", "HTHG", "HTAG", "HTR",
    "Referee", "HS", "AS", "HST", "AST",
    "HF", "AF", "HC", "AC", "HY", "AY", "HR", "AR",
]

def insert_raw_data(league, code, year):
    season = season_code(year)

    if check_if_loaded(league, season):
        logger.info(f"Skipping {league} {season} already loaded")
        return
    
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

    df.to_sql("raw_matches", engine, if_exists="append", index=False)
    logger.info(f"Loaded {len(df)} rows for {league} {season} into raw_matches")

    
 
def main():
    for league, code in leagues.items():
        for year in range(START_YEAR, END_YEAR + 1):
            insert_raw_data(league, code, year)


if __name__ == "__main__":
    main()