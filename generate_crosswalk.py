import os
from pathlib import Path
import pandas as pd
import psycopg2
from dotenv import load_dotenv
from rapidfuzz import fuzz, process

# 1. Load .env file safely
env_path = Path(__file__).parent.parent / ".env"
if not env_path.exists():
    # Fallback to current working directory
    env_path = Path.cwd() / ".env"

load_dotenv(dotenv_path=env_path)

# Retrieve credentials
db_user = os.getenv("DB_USER")
db_password = os.getenv("DB_PASSWORD")
db_host = os.getenv("DB_HOST")
db_port = os.getenv("DB_PORT")
db_name = os.getenv("DB_NAME")

print(f"Attempting to connect to database '{db_name}' on {db_host}...")

try:
    conn = psycopg2.connect(
        user=db_user,
        password=db_password,
        host=db_host,
        port=db_port,
        dbname=db_name
    )
    print("Connected to PostgreSQL successfully.")
except Exception as e:
    print(f"\n[ERROR] Connection failed: {e}")
    print("Please verify your .env file credentials and PostgreSQL server status.")
    exit(1)

# 2. Extract unmapped high-minute FBref players
query_unmapped = """
SELECT DISTINCT
    f.league_key,
    f.season_key,
    f.player AS fbref_player,
    f.team AS fbref_team
FROM stg_fbref_player_season_stats f
LEFT JOIN player_season_combined p 
    ON f.player = p.player_name 
   AND f.season_key = p.season_key 
   AND f.team = p.team_name
WHERE p.resolved_understat_player_id IS NULL
  AND f.mins > 300;
"""

# 3. Extract all available Understat players as candidates
query_understat = """
SELECT DISTINCT
    season_key,
    player AS understat_player,
    team AS understat_team,
    player_id
FROM stg_understat_player_season_stats;
"""

try:
    df_unmapped = pd.read_sql(query_unmapped, conn)
    df_understat = pd.read_sql(query_understat, conn)
finally:
    conn.close()

print(f"Found {len(df_unmapped)} unmapped FBref player-seasons.")

# Helper function to normalize player names for accurate matching
def clean_str(s):
    if not s:
        return ""
    import unicodedata
    s = unicodedata.normalize('NFD', s).encode('ascii', 'ignore').decode('utf-8')
    return s.lower().replace('-', ' ').strip()

df_understat['clean_name'] = df_understat['understat_player'].apply(clean_str)

new_matches = []
confidence_threshold = 80.0  # Similarity percentage (0-100)

# 4. Fuzzy match unmapped players within the same season
for _, row in df_unmapped.iterrows():
    fb_name_clean = clean_str(row['fbref_player'])
    season = row['season_key']
    
    candidates = df_understat[df_understat['season_key'] == season]
    if candidates.empty:
        continue
        
    choices = candidates['clean_name'].tolist()
    
    # Use token_sort_ratio to handle word-reorders (e.g., "Lee Jae-sung" vs "Jae-sung Lee")
    match = process.extractOne(fb_name_clean, choices, scorer=fuzz.token_sort_ratio)
    
    if match and match[1] >= confidence_threshold:
        matched_candidate = candidates.iloc[match[2]]
        new_matches.append({
            'fbref_player': row['fbref_player'],
            'understat_player_name': matched_candidate['understat_player'],
            'understat_player_id': str(matched_candidate['player_id']),
            'match_score': round(match[1], 1)
        })

if new_matches:
    df_new = pd.DataFrame(new_matches).drop_duplicates(subset=['fbref_player'])
    print(f"Successfully auto-matched {len(df_new)} new players!")

    # 5. Append new matches to seeds/player_name_map.csv
    seed_path = Path(__file__).parent / 'seeds' / 'player_name_map.csv'
    if not seed_path.exists():
        seed_path = Path.cwd() / 'seeds' / 'player_name_map.csv'

    if seed_path.exists():
        df_existing = pd.read_csv(seed_path, dtype=str)
        
        # Merge and keep unique fbref_player rows
        df_combined = pd.concat([
            df_existing, 
            df_new[['fbref_player', 'understat_player_name', 'understat_player_id']]
        ]).drop_duplicates(subset=['fbref_player'], keep='first')
        
        df_combined.to_csv(seed_path, index=False)
        print(f"Appended new matches and saved updated seed to {seed_path}!")
    else:
        print(f"[ERROR] Could not find {seed_path}. Please make sure seeds/player_name_map.csv exists.")
else:
    print("No new matches found above the confidence threshold.")