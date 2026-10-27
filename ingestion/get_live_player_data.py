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

season = "2627"

VALID_SOURCES = ("fbref", "understat")

KEY_COLUMNS = {
    "fbref": ("player", "team"),
    "understat": ("player_id", "team_id"),
}

def ensure_snapshot_date_column(table):
    inspector = inspect(engine)
    if not inspector.has_table(table):
        return False  # Return False if table doesn't exist yet

    columns = {col["name"] for col in inspector.get_columns(table)}

    if "snapshot_date" not in columns:
        logger.info(f"Adding snapshot_date column to {table}")
        with engine.begin() as conn:
            conn.execute(
                text(f"""
                    ALTER TABLE {table}
                    ADD COLUMN snapshot_date DATE NULL
                """)
            )
        logger.info(f"Added snapshot_date column to {table}")
    return True

def check_if_loaded(league_key, season, source, snapshot_date):
    if source not in VALID_SOURCES:
        raise ValueError(f"Unknown source: {source}")

    table = f"raw_{source}_player_season_stats"

    if not ensure_snapshot_date_column(table):
        return False

    query = text(f"""
        SELECT 1
        FROM {table}
        WHERE league_key = :league
          AND season_key = :season
          AND snapshot_date = :snap
        LIMIT 1
    """)

    with engine.connect() as conn:
        return conn.execute(
            query, {"league": league_key, "season": season, "snap": snapshot_date}
        ).fetchone() is not None

def get_player_season_stats(league_key, league, season, source, snapshot_date):
    if check_if_loaded(league_key, season, source, snapshot_date):
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
        
    if "age" in df.columns:
        df["age"] = (
        df["age"]
        .astype(str)
        .str.extract(r"^(\d+)")[0]
        .astype("Int64")
    )

    df["league_key"] = league_key
    df["season_key"] = season
    df["loaded_at"] = pd.Timestamp.now("UTC")
    df["snapshot_date"] = snapshot_date

    df.to_sql(f"raw_{source}_player_season_stats", engine, if_exists="append", index=False)
    logger.info(f"Loaded {len(df)} player rows for {source} {league_key} {season}")
    return 


def main():
    snapshot_date = pd.Timestamp.now("UTC").date()
    for source in VALID_SOURCES:
        for league_key, league in LEAGUES.items():
            get_player_season_stats(league_key, league, season, source, snapshot_date)


if __name__ == "__main__":
    main()


