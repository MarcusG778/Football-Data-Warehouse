import pandas as pd
import logging
from sqlalchemy import text, inspect
from utils.db import get_engine
import soccerdata as sd


logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

engine = get_engine()


LEAGUES = {
    "premier_league": "ENG-Premier League",
    "bundesliga": "GER-Bundesliga",
    "la_liga": "ESP-La Liga",
    "serie_a": "ITA-Serie A",
    "ligue_1": "FRA-Ligue 1",
}

START_YEAR = 2020
END_YEAR = 2025


def season_code(year):
    return f"{str(year)[2:]}{str(year + 1)[2:]}"


SEASONS = [season_code(y) for y in range(START_YEAR, END_YEAR + 1)]

VALID_SOURCES = ("fbref", "understat")

def check_if_loaded(league, season, source):
    if source not in VALID_SOURCES:
        raise ValueError(f"Unknown source: {source}")

    table = f"raw_{source}_player_season_stats"

    inspector = inspect(engine)
    if not inspector.has_table(table):
        return False

    query = text(f"""
        SELECT 1 FROM {table}
        WHERE league_key = :league AND season_key = :season
        LIMIT 1
    """)
    with engine.connect() as conn:
        result = conn.execute(query, {"league": league, "season": season}).fetchone()
    return result is not None

def get_player_season_stats(league_key, league, season, source):
    if check_if_loaded(league_key, season, source):
        logger.info(f"Skipping {source} {league_key} {season} — already loaded")
        return

    if source == "fbref":
        try:
            fbref = sd.FBref(leagues=[league], seasons=[season])
            df = fbref.read_player_season_stats(stat_type="standard")
        except Exception as e:
            logger.warning(f"Failed to fetch {source} {league_key} {season}: {e}")
            return
    elif source == "understat":
        try:
            understat = sd.Understat(leagues=[league], seasons=[season])
            df = understat.read_player_season_stats()
        except Exception as e:
                logger.warning(f"Failed to fetch {source} {league_key} {season}: {e}")
                return

    if df.empty:
        logger.warning(f"No data returned for {source} {league_key} {season}")
        return
    
    df = df.reset_index()

    if isinstance(df.columns, pd.MultiIndex):
        df.columns = [
            "_".join(str(level) for level in col if level).strip()
            for col in df.columns
        ]

    df["league_key"] = league_key
    df["season_key"] = season
    df["loaded_at"] = pd.Timestamp.now("UTC") 

    df.to_sql(f"raw_{source}_player_season_stats", engine, if_exists="append", index=False)
    logger.info(f"Loaded {len(df)} player rows for {source} {league_key} {season}")
    return 


def main():
    for source in VALID_SOURCES:
        for league_key, league in LEAGUES.items():
            for season in SEASONS:
                get_player_season_stats(league_key, league, season, source)


if __name__ == "__main__":
    main()


