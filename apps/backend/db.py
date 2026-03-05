import os
from pathlib import Path
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

# charge .env depuis le dossier backend (même si on lance depuis ailleurs)
env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(dotenv_path=env_path)

DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    raise RuntimeError(f"DATABASE_URL not set. Expected in: {env_path}")

engine = create_engine(DATABASE_URL, pool_pre_ping=True)

def ping_db() -> bool:
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False