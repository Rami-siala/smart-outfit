import re
from datetime import datetime, timezone
from typing import Any, Optional


def clean_text(value: Any, default: str = "not specified") -> str:
    if value is None:
        return default
    text = str(value).strip()
    return text if text else default


def limit_text(value: str, max_length: int = 1100) -> str:
    value = " ".join(value.strip().split())
    if len(value) <= max_length:
        return value
    truncated = value[:max_length].rsplit(" ", 1)[0].strip()
    return truncated or value[:max_length].strip()


def try_float(value: Any) -> Optional[float]:
    try:
        if value is None or value == "":
            return None
        return float(value)
    except Exception:
        return None


def format_measurement(value: Any, suffix: str) -> str:
    number = try_float(value)
    return f"{number:g} {suffix}" if number is not None else "not specified"


def safe_prompt_value(value: Any, default: str = "") -> str:
    text = clean_text(value, default)
    text = re.sub(r"\s+", " ", text).strip()

    bad_words = [
        "mobile",
        "app",
        "screen",
        "ui",
        "filter",
        "request",
        "dashboard",
        "page",
        "phone",
        "android",
        "ios",
        "emulator",
        "button",
        "dialog",
        "form",
        "loading",
        "overlay",
        "card",
    ]

    lowered = text.lower()
    for word in bad_words:
        lowered = lowered.replace(word, "")

    cleaned = " ".join(lowered.split())
    return cleaned.title() if cleaned else default


def parse_temperature_c(value: Any) -> Optional[float]:
    if value is None:
        return None

    text = str(value).strip().replace(",", ".")
    match = re.search(r"-?\d+(\.\d+)?", text)
    if not match:
        return None

    return try_float(match.group(0))


def normalize_gender(value: Optional[str]) -> str:
    normalized = clean_text(value, "person").lower().strip()

    if normalized in {"male", "man", "boy", "masculine", "m"}:
        return "male"

    if normalized in {"female", "woman", "girl", "feminine", "f"}:
        return "female"

    return "person"


def normalize_style(value: Optional[str]) -> str:
    normalized = clean_text(value, "Casual").lower().strip()

    mapping = {
        "casual": "Casual",
        "sport": "Sport",
        "sporty": "Sport",
        "chic": "Chic",
    }

    return mapping.get(normalized, "Casual")


def normalize_body_shape(value: Optional[str]) -> str:
    normalized = clean_text(value, "Regular").lower().strip()

    mapping = {
        "slim": "Slim",
        "athletic": "Athletic",
        "regular": "Regular",
        "normal": "Regular",
        "average": "Regular",
        "curvy": "Curvy",
        "plus size": "Plus Size",
        "plus-size": "Plus Size",
        "plus": "Plus Size",
    }

    return mapping.get(normalized, "Regular")


def normalize_skin_tone(value: Optional[str]) -> str:
    normalized = clean_text(value, "Medium").lower().strip()

    mapping = {
        "fair": "Fair",
        "light": "Light",
        "medium": "Medium",
        "tan": "Tan",
        "dark": "Dark",
    }

    return mapping.get(normalized, "Medium")


def calculate_age(birth_date: Any) -> Optional[int]:
    if not birth_date:
        return None

    try:
        if isinstance(birth_date, str):
            birth = datetime.fromisoformat(birth_date.replace("Z", "+00:00")).date()
        else:
            birth = birth_date

        today = datetime.now(timezone.utc).date()
        age = today.year - birth.year

        if (today.month, today.day) < (birth.month, birth.day):
            age -= 1

        return age
    except Exception:
        return None
