import os
import random
from datetime import datetime, timedelta
from pathlib import Path

import bcrypt
from dotenv import load_dotenv
from fastapi import HTTPException, status
from jose import JWTError, jwt

env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(dotenv_path=env_path)

JWT_SECRET = os.getenv("JWT_SECRET", "dev-secret")
JWT_ALGO = os.getenv("JWT_ALGO", "HS256")
JWT_EXPIRE_MIN = int(os.getenv("JWT_EXPIRE_MIN", "60"))
SOCIAL_LOGIN_HASH = "SOCIAL_LOGIN"


def social_login_marker() -> str:
    return SOCIAL_LOGIN_HASH


def is_social_login_hash(hashed: str | None) -> bool:
    return hashed == SOCIAL_LOGIN_HASH


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, hashed: str) -> bool:
    # Social-login accounts do not store a bcrypt password hash, so they
    # should never pass password verification through the local password flow.
    if is_social_login_hash(hashed):
        return False

    try:
        # Use bcrypt only for real password hashes. Invalid or malformed hash
        # strings should fail closed instead of bubbling up into auth handlers.
        return bcrypt.checkpw(password.encode("utf-8"), hashed.encode("utf-8"))
    except ValueError:
        return False


def create_access_token(user_id: int) -> str:
    expire = datetime.utcnow() + timedelta(minutes=JWT_EXPIRE_MIN)
    payload = {"sub": str(user_id), "exp": expire}
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGO)


def decode_access_token(token: str) -> dict:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGO])
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )


def generate_reset_code() -> str:
    return f"{random.randint(0, 9999):04d}"
