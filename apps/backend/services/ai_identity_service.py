import hashlib
from typing import Any

from models import User
from utils.ai_normalizers import clean_text

MAX_IMAGE_SEED= 2_147_483_647


def build_seed(*parts: Any) -> int:
    seed_source = "||".join(clean_text(part, "") for part in parts)
    digest = hashlib.sha256(seed_source.encode("utf-8")).hexdigest()
    seed = int(digest[:12], 16) % MAX_IMAGE_SEED

    if seed <= 0:
        seed = 1

    return seed


def build_generation_seed(current_user: User, data: dict) -> int:
    return build_seed(
        "outfit-image",
        str(current_user.id),
        data["gender"],
        data["skin_tone"],
        data["body_shape"],
        data["height_text"],
        data["weight_text"],
        data["style"],
        data["color"],
        data["weather_label"],
        data["temperature"],
        data["city"],
        data["country"],
        data["time_of_day"],
        data.get("extra_instructions", ""),
    )