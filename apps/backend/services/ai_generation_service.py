import base64
import json
import logging
import os
import re
from io import BytesIO
from itertools import product
from pathlib import Path
from typing import Optional
from urllib.parse import urlparse

import httpx
from dotenv import load_dotenv
from fastapi import HTTPException, status

from models import User, UserPreference, UserProfile
from schemas import GenerateOutfitImageRequest
from services.ai_history_image_service import STATIC_DIR
from services.ai_identity_service import build_generation_seed
from services.ai_weather_service import build_weather_scene_rules, normalize_weather_label
from services.wardrobe_item_image_service import resolve_managed_wardrobe_item_image_path
from utils.ai_normalizers import (
    calculate_age,
    clean_text,
    format_measurement,
    limit_text,
    normalize_body_shape,
    normalize_gender,
    normalize_skin_tone,
    normalize_style,
    parse_temperature_c,
    safe_prompt_value,
    try_float,
)

try:
    from PIL import Image, ImageDraw, ImageFont, ImageOps
except ImportError:
    Image = None
    ImageDraw = None
    ImageFont = None
    ImageOps = None

logger = logging.getLogger(__name__)

env_path = Path(__file__).resolve().parents[1] / ".env"
load_dotenv(dotenv_path=env_path)

IMAGE_API_KEY = os.getenv("IMAGE_API_KEY")
IMAGE_API_BASE_URL = os.getenv(
    "IMAGE_API_BASE_URL",
    "https://media.srv1466555.hstgr.cloud",
)
IMAGE_API_MODEL = os.getenv("IMAGE_API_MODEL", "flux1-dev-fp8")

PROMPT_MAX_LENGTH = 2600
IMAGE_WIDTH = 1024
IMAGE_HEIGHT = 1024
HTTP_TIMEOUT_SECONDS = 180.0
IMAGE_CFG = 2
IMAGE_STEPS = 28

EDIT_IMAGE_STRENGTH = 0.94
EDIT_IMAGE_STEPS = 36
EDIT_IMAGE_CFG = 1.6

# ✅ NEW: constants for full-body avatar pre-generation
FULL_BODY_AVATAR_STRENGTH = 0.9
FULL_BODY_AVATAR_STEPS = 32
FULL_BODY_AVATAR_CFG = 1.5
# Portrait selfies and bust shots are often taller than wide, so the threshold
# needs to be high enough that they still count as headshots and trigger the
# full-body expansion step before dressing.
HEADSHOT_ASPECT_RATIO_THRESHOLD = 2.0
MAX_CANDIDATES_PER_TYPE = 6

NO_MATCHING_WARDROBE_WARNING = (
    "We didn't find a matching outfit in your selected wardrobe, so I "
    "suggested one based on your preferences and the weather."
)


def _build_image_quota_detail(response: httpx.Response) -> dict:
    detail = {
        "code": "daily_quota_exceeded",
        "message": "Daily image limit reached. Try again tomorrow.",
        "reset_policy": "daily",
    }

    try:
        payload = response.json()
    except (ValueError, json.JSONDecodeError):
        return detail

    if not isinstance(payload, dict):
        return detail

    provider_message = clean_text(payload.get("error"), "")
    if provider_message:
        detail["provider_error"] = provider_message

    quota = payload.get("quota")
    if isinstance(quota, dict):
        used = quota.get("used")
        limit = quota.get("limit")
        if isinstance(used, int):
            detail["used"] = used
        if isinstance(limit, int):
            detail["limit"] = limit

    return detail


SUPPORTED_OUTFIT_COLORS = (
    "black",
    "white",
    "beige",
    "blue",
    "red",
    "green",
    "pink",
    "brown",
    "gray",
    "purple",
)
ITEM_SUBTYPE_OPTIONS = {
    "top": {"t_shirt", "polo", "shirt", "dress_shirt", "hoodie", "sweater", "tank_top"},
    "bottom": {"shorts", "jeans", "joggers", "trousers"},
    "shoe": {"sneakers", "running_shoes", "boots", "loafers", "sandals"},
    "outwear": {"blazer", "coat", "raincoat", "puffer_jacket", "denim_jacket"},
    "accessory": {"bag", "watch", "scarf", "hat", "belt"},
}
ITEM_SUBTYPE_NAME_PATTERNS = (
    ("t_shirt", (r"\bt[\s\-_]*shirt\b", r"\btshirt\b")),
    ("hoodie", (r"\bhoodie\b",)),
    ("sweater", (r"\bsweater\b", r"\btriko\b")),
    ("shorts", (r"\bshorts?\b",)),
    ("bag", (r"\bbag\b", r"\bsac\b")),
    ("polo", (r"\bpolo\b",)),
    ("dress_shirt", (r"\bdress[\s\-_]*shirt\b", r"\bbutton[\s\-_]*up\b", r"\bbutton[\s\-_]*down\b", r"\bchemise\b")),
    ("shirt", (r"\bshirt\b", r"\bchemise\b")),
    ("tank_top", (r"\btank[\s\-_]*top\b", r"\btank\b")),
    ("jeans", (r"\bjeans?\b", r"\bdenim\b")),
    ("joggers", (r"\bjoggers?\b", r"\bsweatpants?\b")),
    ("trousers", (r"\btrousers?\b", r"\bpants\b", r"\bslacks\b", r"\bpantalons?\b")),
    ("running_shoes", (r"\brunning[\s\-_]*shoes?\b",)),
    ("sneakers", (r"\bsneakers?\b", r"\btrainers?\b")),
    ("boots", (r"\bboots?\b",)),
    ("loafers", (r"\bloafers?\b",)),
    ("sandals", (r"\bsandals?\b",)),
    ("blazer", (r"\bblazer\b",)),
    ("coat", (r"\bcoat\b",)),
    ("raincoat", (r"\brain[\s\-_]*coat\b",)),
    ("puffer_jacket", (r"\bpuffer\b",)),
    ("denim_jacket", (r"\bdenim[\s\-_]*jacket\b",)),
    ("watch", (r"\bwatch\b",)),
    ("scarf", (r"\bscarf\b",)),
    ("hat", (r"\bhat\b", r"\bcap\b")),
    ("belt", (r"\bbelt\b",)),
)


def _enum_value(value) -> str:
    if value is None:
        return ""
    return getattr(value, "value", str(value))


def _item_ai_metadata(item) -> dict:
    metadata = getattr(item, "ai_detected_metadata", None)
    return metadata if isinstance(metadata, dict) else {}


def _item_string_value(item, attribute: str, *, ai_key: str | None = None) -> str:
    raw = _enum_value(getattr(item, attribute, ""))
    if raw:
        return raw
    if ai_key:
        ai_value = _item_ai_metadata(item).get(ai_key)
        if ai_value is not None:
            return str(ai_value)
    return ""


def _item_bool_value(item, attribute: str, *, ai_key: str | None = None) -> bool:
    value = getattr(item, attribute, None)
    if value is not None:
        return bool(value)
    if ai_key:
        ai_value = _item_ai_metadata(item).get(ai_key)
        if isinstance(ai_value, bool):
            return ai_value
    return False


def _reference_item_sort_key(item) -> int:
    item_type = _enum_value(getattr(item, "type", "")).lower()
    order = {
        "top": 0,
        "bottom": 1,
        "shoe": 2,
        "accessory": 3,
        "outwear": 4,
    }
    return order.get(item_type, 99)


def _ordered_reference_items(selected_items: list) -> list:
    ordered = []
    seen_types = set()
    for item in sorted(selected_items or [], key=_reference_item_sort_key):
        item_type = _enum_value(getattr(item, "type", "")).lower()
        if item_type not in {"top", "bottom", "shoe", "accessory", "outwear"}:
            continue
        if item_type in seen_types:
            continue
        ordered.append(item)
        seen_types.add(item_type)
    return ordered


def _extract_image_api_url(result: dict) -> str:
    if not isinstance(result, dict):
        return ""
    response_payload = result.get("response")
    if isinstance(response_payload, dict):
        response_url = clean_text(response_payload.get("url"), "")
        if response_url:
            return response_url
    return clean_text(result.get("url"), "")


def _resolve_static_image_path(image_url: str) -> Optional[Path]:
    parsed = urlparse(image_url)
    image_path = parsed.path or image_url

    if not image_path.startswith("/static/"):
        return None

    relative_path = image_path.removeprefix("/static/").strip("/")
    if not relative_path:
        return None

    # ✅ STATIC folder is inside backend/
    backend_root = Path(__file__).resolve().parents[1]  # backend/
    static_root = (backend_root / "static").resolve()

    resolved = (static_root / relative_path).resolve()

    if not resolved.exists():
        logger.warning(
            "Static image file is missing image_url=%s resolved_path=%s",
            image_url,
            resolved,
        )
        return None

    return resolved

async def _load_reference_image_bytes(image_url: str) -> bytes:
    cleaned_url = clean_text(image_url, "")
    if not cleaned_url:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing image source image.",
        )

    parsed = urlparse(cleaned_url)
    image_path = parsed.path or cleaned_url

    # ✅ 1. Handle ALL /static/... paths first (profile_images, wardrobe_items, etc.)
    if image_path.startswith("/static/"):
        local_path = _resolve_static_image_path(cleaned_url)
        if local_path is not None:
            return local_path.read_bytes()

    # ✅ 2. Fallback to managed wardrobe path (optional)
    local_path = resolve_managed_wardrobe_item_image_path(cleaned_url)
    if local_path is not None:
        return local_path.read_bytes()

    # ✅ 3. Download if it's an external URL
    if parsed.scheme in {"http", "https"}:
        try:
            async with httpx.AsyncClient(
                timeout=HTTP_TIMEOUT_SECONDS,
                follow_redirects=True,
            ) as client:
                response = await client.get(cleaned_url)
        except httpx.TimeoutException:
            logger.exception("Timed out downloading reference image: %s", cleaned_url)
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail="Reference image download timed out.",
            )
        except httpx.RequestError as exc:
            logger.exception("Unable to download reference image %s: %s", cleaned_url, exc)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Unable to download reference image.",
            )

        if response.status_code >= 400:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Unable to download reference image.",
            )

        return response.content

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Unsupported image reference URL.",
    )

def _fit_reference_image(image_bytes: bytes, max_size: tuple[int, int]):
    if Image is None or ImageOps is None:
        return None

    try:
        image = Image.open(BytesIO(image_bytes))
        image = ImageOps.exif_transpose(image)

        # ✅ Convert safely
        if image.mode != "RGBA":
            image = image.convert("RGBA")

        image = ImageOps.contain(image, max_size)
        return image

    except Exception as exc:
        logger.exception("Image processing failed: %s", exc)
        return None

# ---------------------------------------------------------------------------
# ✅ NEW: Detect whether an avatar image is a headshot / bust (not full-body)
# ---------------------------------------------------------------------------
def _detect_is_headshot(image_bytes: bytes) -> bool:
    """
    Return *True* when the avatar image is likely a headshot or bust crop
    rather than a full-body photo.  Full-body portraits are typically taller
    than wide (aspect ratio ≥ 1.25).
    """
    if Image is None:
        return False
    try:
        img = Image.open(BytesIO(image_bytes))
        img.load()
        width, height = img.size
        if width == 0:
            return False
        aspect_ratio = height / width
        is_headshot = aspect_ratio < HEADSHOT_ASPECT_RATIO_THRESHOLD
        logger.info(
            "Avatar analysis: size=%dx%d aspect_ratio=%.2f is_headshot=%s",
            width, height, aspect_ratio, is_headshot,
        )
        return is_headshot
    except Exception as exc:
        logger.warning("Could not analyse avatar image: %s", exc)
        return False


# ---------------------------------------------------------------------------
# ✅ NEW: Pre-generate a full-body avatar in neutral clothing from a headshot
# ---------------------------------------------------------------------------
async def _generate_full_body_avatar(
    headshot_bytes: bytes,
    data: dict,
) -> Optional[bytes]:
    """
    Call edit-image once to expand a face or portrait reference into a
    full-body person wearing a neutral base layer with minimal clothing
    identity. Returns the raw image bytes of the full-body avatar, or *None*
    on failure.
    """
    if not IMAGE_API_KEY:
        return None

    headshot_b64 = base64.b64encode(headshot_bytes).decode("utf-8")

    gender = data.get("gender", "person")
    skin_tone = data.get("skin_tone", "medium")
    body_shape = data.get("body_shape", "regular")
    height_text = data.get("height_text", "")
    weight_text = data.get("weight_text", "")
    age_text = data.get("age_text", "adult")

    profile_parts = [
        gender,
        f"age {age_text}",
        f"skin tone {skin_tone}",
        f"body shape {body_shape}",
    ]
    if height_text:
        profile_parts.append(f"height {height_text}")
    if weight_text:
        profile_parts.append(f"weight {weight_text}")
    profile_text = ", ".join(profile_parts)

    prompt = (
        "Using the provided face and identity reference, generate a realistic "
        "full-body photo of this EXACT same person standing naturally. "
        "PRESERVE the exact face, hairstyle, facial hair, facial features, "
        "and skin tone from the input image — the person must be recognisable. "
        "The person must be visible from head to feet, standing upright, "
        "facing the camera, arms slightly away from the body. "
        "Wearing a simple neutral fitted base layer only: plain light gray "
        "close-fitting top and plain light gray close-fitting bottoms with no "
        "visible fashion identity, no logos, no accessories, and no standout "
        "colors. Keep the base clothing minimal and easy to replace later. "
        "Clean plain light gray studio background. "
        f"Person: {profile_text}. "
        "FULL BODY visible from head to feet. Show the full body clearly. "
        "Ultra-realistic photo, DSLR quality, sharp focus, natural lighting. "
        "No cropping. No text. No watermark. No extra people. One person only. "
        "This step is only to create a neutral full-body avatar, not the final outfit."
    )

    headers = {
        "Authorization": f"Bearer {IMAGE_API_KEY}",
        "Content-Type": "application/json",
    }
    request_body = {
        "model": IMAGE_API_MODEL,
        "prompt": prompt,
        "imageBase64": headshot_b64,
        "stream": False,
        "options": {
            "strength": FULL_BODY_AVATAR_STRENGTH,
            "steps": FULL_BODY_AVATAR_STEPS,
            "cfg": FULL_BODY_AVATAR_CFG,
        },
    }

    try:
        logger.info("Pre-generating full-body avatar from headshot …")
        async with httpx.AsyncClient(timeout=HTTP_TIMEOUT_SECONDS) as client:
            response = await client.post(
                f"{IMAGE_API_BASE_URL}/api/edit-image",
                json=request_body,
                headers=headers,
            )

        if response.status_code >= 400:
            logger.warning(
                "Full-body avatar pre-generation failed status=%s body=%s",
                response.status_code,
                response.text[:300],
            )
            return None

        result = response.json()
        image_url = _extract_image_api_url(result)
        if not image_url:
            logger.warning("Full-body avatar pre-generation returned no URL: %s", result)
            return None

        logger.info("Full-body avatar generated, downloading from %s", image_url)
        async with httpx.AsyncClient(
            timeout=HTTP_TIMEOUT_SECONDS, follow_redirects=True,
        ) as dl_client:
            img_response = await dl_client.get(image_url)

        if img_response.status_code >= 400:
            logger.warning("Failed to download generated full-body avatar")
            return None

        logger.info(
            "Full-body avatar ready (%d bytes)",
            len(img_response.content),
        )
        return img_response.content

    except Exception as exc:
        logger.warning(
            "Full-body avatar pre-generation error (%s): %r",
            type(exc).__name__,
            exc,
            exc_info=True,
        )
        return None


# ---------------------------------------------------------------------------
# ✅ CHANGED: dynamic edit-image prompt — Variante 2 from supervisor
# ---------------------------------------------------------------------------
def build_edit_image_prompt(data: dict, selected_items: list) -> str:
    """
    Build a dynamic edit-image prompt following the supervisor's Variante 2.
    Lists every selected wardrobe item explicitly so the model knows
    exactly which garments to dress the avatar with.
    """
    gender = data.get("gender", "person")
    skin_tone = data.get("skin_tone", "")
    body_shape = data.get("body_shape", "")
    height_text = data.get("height_text", "")
    weight_text = data.get("weight_text", "")

    # ---- Build explicit per-item descriptions ----
    clothing_lines = []
    accessory_lines = []

    for item in selected_items:
        item_type = _enum_value(getattr(item, "type", "")).lower()
        subtype = resolve_item_subtype(item)
        color = _enum_value(getattr(item, "color", "")).lower() or "matching"
        name = clean_text(getattr(item, "name", ""), "")
        material = clean_text(getattr(item, "material", ""), "")
        subtype_label = _readable_subtype_label(subtype) if subtype else item_type

        desc_parts = [color]
        if material:
            desc_parts.append(material)
        if name:
            desc_parts.append(f'"{name}"')
        desc_parts.append(f"({subtype_label})")
        label = " ".join(desc_parts)

        if item_type == "top":
            clothing_lines.append(f"- TOP: {label}")
        elif item_type == "bottom":
            clothing_lines.append(f"- BOTTOM: {label}")
        elif item_type == "shoe":
            clothing_lines.append(f"- SHOES: {label}")
        elif item_type == "outwear":
            clothing_lines.append(f"- OUTWEAR: {label}")
        elif item_type == "accessory":
            accessory_lines.append(f"- ACCESSORY: {label}")

    all_items = clothing_lines + accessory_lines
    items_text = (
        "\n".join(all_items)
        if all_items
        else "- the selected clothing items shown on the right side of the image"
    )

    exact_match_rules = []
    subtype_specific_rules = []
    for item in selected_items:
        item_type = _enum_value(getattr(item, "type", "")).lower()
        subtype = resolve_item_subtype(item)
        subtype_label = _readable_subtype_label(subtype) if subtype else item_type
        color = _enum_value(getattr(item, "color", "")).lower() or "matching"
        name = clean_text(getattr(item, "name", ""), "")
        descriptor = f"{color} {subtype_label}".strip()
        if name:
            descriptor = f'{descriptor} named "{name}"'

        if item_type == "top":
            exact_match_rules.append(
                f"- The avatar must wear the exact selected top: {descriptor}."
            )
            if subtype == "dress_shirt" and _name_mentions_chemise(name):
                subtype_specific_rules.append(
                    "- If the selected dress_shirt top name contains chemise, render it specifically as a chemise: visible collar, front button placket, long sleeves, and shirt cuffs."
                )
                subtype_specific_rules.append(
                    "- Do not turn a selected chemise into a T-shirt, tee, polo, or short-sleeve casual shirt."
                )
        elif item_type == "bottom":
            exact_match_rules.append(
                f"- The avatar must wear the exact selected bottom: {descriptor}."
            )
        elif item_type == "shoe":
            exact_match_rules.append(
                f"- The avatar must wear the exact selected shoes: {descriptor}."
            )
        elif item_type == "outwear":
            exact_match_rules.append(
                f"- The avatar must wear the exact selected outerwear: {descriptor}."
            )
        elif item_type == "accessory":
            exact_match_rules.append(
                f"- The avatar must wear or carry the exact selected accessory: {descriptor}."
            )

        if subtype == "dress_shirt":
            subtype_specific_rules.append(
                "- If the selected top subtype is dress shirt, it must stay a real dress shirt or button-up silhouette."
            )
            subtype_specific_rules.append(
                "- A dress shirt must have a visible collar, front button placket, long sleeves, and shirt cuffs."
            )
            subtype_specific_rules.append(
                "- Do not turn a selected dress shirt into a T-shirt, tee, polo, short-sleeve casual shirt, hoodie, or sweater."
            )

    exact_match_block = (
        "\n".join(exact_match_rules)
        if exact_match_rules
        else "- Dress the avatar in exactly the provided wardrobe items."
    )
    subtype_specific_block = (
        "\n".join(dict.fromkeys(subtype_specific_rules))
        if subtype_specific_rules else ""
    )
    subtype_specific_text = (
        f"{subtype_specific_block}\n" if subtype_specific_block else ""
    )

    profile_parts = [f"gender {gender}"]
    if skin_tone:
        profile_parts.append(f"skin tone {skin_tone}")
    if body_shape:
        profile_parts.append(f"body shape {body_shape}")
    if height_text:
        profile_parts.append(f"height {height_text}")
    if weight_text:
        profile_parts.append(f"weight {weight_text}")
    profile_text = ", ".join(profile_parts)

    return (
        "Use the input avatar image as the identity reference. "
        "Preserve the same face, hair, skin tone, and person identity from that avatar reference.\n"
        "\n"
        "CLOTHING ITEMS THE PERSON MUST WEAR "
        "(selected from the wardrobe and listed below):\n"
        f"{items_text}\n"
        "\n"
        "TASK — generate ONE realistic full-body photo where:\n"
        "1. The person is the SAME person from the avatar reference — preserve face, "
        "hairstyle, facial hair, and skin tone exactly.\n"
        "2. The person is wearing ALL the clothing items listed above — "
        "replace the current plain neutral clothes with the selected wardrobe items.\n"
        "3. Full body visible from head to shoes — shoes MUST be visible.\n"
        "4. Person standing naturally, front-facing, arms slightly away from body.\n"
        "5. Clean neutral studio background.\n"
        "\n"
        "STRICT RULES:\n"
        "- Dress the avatar in exactly the selected wardrobe items listed above.\n"
        "- Do not invent new clothes.\n"
        "- Do not change a selected T-shirt into a hoodie, sweater, jacket, or long-sleeve top.\n"
        "- Do not change selected shorts into pants, jeans, joggers, or trousers.\n"
        "- Do not change selected sneakers into boots, loafers, sandals, or formal shoes.\n"
        "- Match the selected item color, subtype, shape, and silhouette as closely as possible.\n"
        f"{subtype_specific_text}"
        "- Show each selected item on the avatar, not as floating objects.\n"
        "- Do NOT keep the neutral placeholder clothes — replace them entirely "
        "with the listed wardrobe items.\n"
        "- Do NOT show floating or separated clothing items.\n"
        "- Do NOT show split-screen or side-by-side layout.\n"
        "- Do NOT add extra people.\n"
        "- The output is a single realistic photo of one fully-dressed person.\n"
        "- Ultra-realistic DSLR quality, sharp focus, natural lighting.\n"
        f"- Person profile: {profile_text}\n"
        "\n"
        "EXACT ITEM MATCH RULES:\n"
        f"{exact_match_block}\n"
        "\n"
        "The final output must show the avatar FULLY dressed in the EXACT "
        "selected wardrobe items, standing naturally on a clean background. "
        "No collage. No layout. One person. Fully dressed in the chosen outfit."
    )


# ---------------------------------------------------------------------------
# ✅ CHANGED: Build composite — handles full-body avatar pre-generation
# ---------------------------------------------------------------------------
async def _build_edit_image_reference_base64(
    avatar_image_url: str,
    selected_items: list,
    data: dict,
) -> tuple[str, list]:
    """
    Build a 1024×1024 composite image:
      • LEFT  half — full-body avatar in neutral clothing
      • RIGHT half — wardrobe items clearly laid out with labels

    If the avatar is only a headshot / bust the function will first call
    the image API to generate a full-body version in neutral clothing,
    following the supervisor's recommendation.
    """
    ordered_items = _ordered_reference_items(selected_items)
    if not clean_text(avatar_image_url, "") or not ordered_items:
        return "", []

    # ---- Load avatar bytes ----
    try:
        avatar_bytes = await _load_reference_image_bytes(avatar_image_url)
    except HTTPException:
        logger.warning("Avatar reference image could not be loaded")
        return "", []

    # ---- ✅ NEW: Ensure full-body avatar ----
    logger.info("Attempting unconditional neutral full-body avatar generation")
    unconditional_full_body_bytes = await _generate_full_body_avatar(
        avatar_bytes,
        data,
    )
    if unconditional_full_body_bytes:
        avatar_bytes = unconditional_full_body_bytes
        logger.info("Using unconditional full-body avatar for downstream edit")

    if _detect_is_headshot(avatar_bytes):
        logger.info("Avatar is a headshot — generating full-body version first")
        full_body_bytes = await _generate_full_body_avatar(avatar_bytes, data)
        if full_body_bytes:
            avatar_bytes = full_body_bytes
            logger.info("Using pre-generated full-body avatar for composite")
        else:
            logger.warning(
                "Full-body avatar generation failed — using original headshot"
            )

    try:
        avatar_image = _fit_reference_image(avatar_bytes, (460, 920))
    except HTTPException:
        logger.warning("Avatar image could not be processed for composite")
        return "", []

    if Image is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Pillow is required for avatar reference preparation.",
        )

    avatar_canvas = Image.new("RGB", (IMAGE_WIDTH, IMAGE_HEIGHT), (245, 245, 245))
    avatar_bg = Image.new("RGB", avatar_image.size, (245, 245, 245))
    if avatar_image.mode == "RGBA":
        avatar_bg.paste(avatar_image, mask=avatar_image.split()[-1])
    else:
        avatar_bg.paste(avatar_image)

    avatar_x = (IMAGE_WIDTH - avatar_image.width) // 2
    avatar_y = max(24, (IMAGE_HEIGHT - avatar_image.height) // 2)
    avatar_canvas.paste(avatar_bg, (avatar_x, avatar_y))

    avatar_out = BytesIO()
    avatar_canvas.save(avatar_out, format="JPEG", quality=93, optimize=True)
    avatar_encoded = base64.b64encode(avatar_out.getvalue()).decode("utf-8")

    logger.info(
        "Avatar-only edit reference built: avatar=%s items=%d b64_len=%d",
        avatar_image.size,
        len(ordered_items),
        len(avatar_encoded),
    )
    return avatar_encoded, ordered_items

    item_images = []
    for item in ordered_items:
        item_image_url = clean_text(getattr(item, "image_url", ""), "")
        if not item_image_url:
            logger.warning(
                "Selected wardrobe item has no image URL and will be skipped: %s",
                clean_text(getattr(item, "name", ""), "?"),
            )
            continue

        try:
            item_bytes = await _load_reference_image_bytes(item_image_url)
            item_image = _fit_reference_image(item_bytes, (220, 220))
        except HTTPException:
            logger.warning(
                "Selected wardrobe item image could not be processed and will be skipped: %s",
                clean_text(getattr(item, "name", ""), "?"),
            )
            continue

        item_images.append((item, item_image))

    if not item_images:
        logger.warning(
            "No selected wardrobe item images could be loaded for composite; using avatar-only reference"
        )
        avatar_canvas = Image.new("RGB", (IMAGE_WIDTH, IMAGE_HEIGHT), (245, 245, 245))
        avatar_draw = ImageDraw.Draw(avatar_canvas)
        avatar_bg = Image.new("RGB", avatar_image.size, (245, 245, 245))
        if avatar_image.mode == "RGBA":
            avatar_bg.paste(avatar_image, mask=avatar_image.split()[-1])
        else:
            avatar_bg.paste(avatar_image)

        avatar_x = (IMAGE_WIDTH - avatar_image.width) // 2
        avatar_y = max(24, (IMAGE_HEIGHT - avatar_image.height) // 2)
        avatar_canvas.paste(avatar_bg, (avatar_x, avatar_y))
        avatar_draw.text(
            (24, 20),
            "Identity reference only - generate one full-body dressed person",
            fill=(60, 60, 60),
        )

        avatar_out = BytesIO()
        avatar_canvas.save(avatar_out, format="JPEG", quality=93, optimize=True)
        avatar_encoded = base64.b64encode(avatar_out.getvalue()).decode("utf-8")

        logger.info(
            "Avatar edit reference built: avatar=%s items=%d b64_len=%d",
            avatar_image.size,
            len(ordered_items),
            len(avatar_encoded),
        )
        return avatar_encoded, ordered_items

    # ---- Build canvas ----
    CANVAS = 1024
    LABEL_H = 34
    DIVIDER_X = 512

    canvas = Image.new("RGB", (CANVAS, CANVAS), (245, 245, 245))
    draw = ImageDraw.Draw(canvas)

    # Header labels
    draw.rectangle([(0, 0), (DIVIDER_X - 1, LABEL_H)], fill=(30, 90, 200))
    draw.text((12, 8), "IDENTITY — preserve face & body", fill="white")

    draw.rectangle([(DIVIDER_X, 0), (CANVAS, LABEL_H)], fill=(180, 30, 30))
    draw.text((DIVIDER_X + 8, 8), "CLOTHES — dress avatar with these", fill="white")

    # Vertical divider
    draw.line([(DIVIDER_X, 0), (DIVIDER_X, CANVAS)], fill=(120, 120, 120), width=3)

    # ---- Paste avatar centred in LEFT half ----
    bg = Image.new("RGB", avatar_image.size, (245, 245, 245))
    if avatar_image.mode == "RGBA":
        bg.paste(avatar_image, mask=avatar_image.split()[-1])
    else:
        bg.paste(avatar_image)

    ax = (DIVIDER_X - avatar_image.width) // 2
    ay = LABEL_H + max(4, (CANVAS - LABEL_H - avatar_image.height) // 2)
    canvas.paste(bg, (ax, ay))

    # ---- Paste items evenly in RIGHT half ----
    usable_h = CANVAS - LABEL_H - 10
    n_items = len(item_images)
    slot_h = usable_h // max(n_items, 1)
    right_w = CANVAS - DIVIDER_X

    for idx, (item, item_img) in enumerate(item_images):
        ibg = Image.new("RGB", item_img.size, (255, 255, 255))
        if item_img.mode == "RGBA":
            ibg.paste(item_img, mask=item_img.split()[-1])
        else:
            ibg.paste(item_img)

        ix = DIVIDER_X + (right_w - item_img.width) // 2
        slot_top = LABEL_H + idx * slot_h
        iy = slot_top + max(0, (slot_h - item_img.height - 18) // 2)
        canvas.paste(ibg, (ix, iy))

        # Label below item
        item_type = _enum_value(getattr(item, "type", "")).upper()
        subtype = resolve_item_subtype(item)
        color = _enum_value(getattr(item, "color", "")).lower()
        name = clean_text(getattr(item, "name", ""), "")
        label = f"{item_type}: {color} {subtype or ''} {name}".strip()
        label_y = iy + item_img.height + 2
        if label_y < CANVAS - 12:
            draw.text((ix, label_y), label[:50], fill=(40, 40, 40))

    # ---- Encode ----
    out = BytesIO()
    canvas.save(out, format="JPEG", quality=93, optimize=True)
    encoded = base64.b64encode(out.getvalue()).decode("utf-8")

    logger.info(
        "Composite built: avatar=%s items=%d b64_len=%d",
        avatar_image.size,
        len(item_images),
        len(encoded),
    )
    return encoded, [itm for itm, _ in item_images]


def _item_visual_description(item) -> str:
    return clean_text(getattr(item, "visual_description", ""), "")


def _normalize_item_subtype_value(value) -> str:
    normalized = _enum_value(value).strip().lower()
    return normalized


def _name_mentions_chemise(name: str) -> bool:
    normalized_name = clean_text(name, "").lower()
    return "chemise" in normalized_name


def infer_item_subtype_from_name(name: str, item_type: str = "") -> str:
    normalized_name = clean_text(name, "").lower()
    if not normalized_name:
        return ""
    allowed_subtypes = ITEM_SUBTYPE_OPTIONS.get(item_type.lower(), set())
    for subtype, patterns in ITEM_SUBTYPE_NAME_PATTERNS:
        if allowed_subtypes and subtype not in allowed_subtypes:
            continue
        if any(re.search(pattern, normalized_name) for pattern in patterns):
            return subtype
    return ""


def resolve_item_subtype(item) -> str:
    item_type = _enum_value(getattr(item, "type", "")).lower()
    explicit_subtype = _normalize_item_subtype_value(getattr(item, "item_subtype", ""))
    allowed_subtypes = ITEM_SUBTYPE_OPTIONS.get(item_type, set())
    if explicit_subtype and (not allowed_subtypes or explicit_subtype in allowed_subtypes):
        return explicit_subtype
    name = clean_text(getattr(item, "name", ""), "")
    inferred_subtype = infer_item_subtype_from_name(name, item_type)
    if inferred_subtype:
        return inferred_subtype
    ai_subtype = _normalize_item_subtype_value(_item_ai_metadata(item).get("item_subtype"))
    if ai_subtype and (not allowed_subtypes or ai_subtype in allowed_subtypes):
        return ai_subtype
    return ""


def _subtype_prompt_rule(subtype: str) -> str:
    rules = {
        "t_shirt": "If subtype is t_shirt, it must stay a short-sleeve T-shirt and must never become a hoodie, sweatshirt, sweater, jacket, coat, or long-sleeve top.",
        "dress_shirt": "If subtype is dress_shirt, it must stay a tailored dress shirt or button-up silhouette and must never become a T-shirt, hoodie, sweatshirt, sweater, or casual knit top.",
        "shirt": "If subtype is shirt, it must stay a structured shirt silhouette and must never become a T-shirt, hoodie, sweatshirt, sweater, or jacket.",
        "hoodie": "If subtype is hoodie, never generate a T-shirt or polo silhouette.",
        "shorts": "If subtype is shorts, it must stay above-knee shorts with visible lower legs and must never become joggers, pants, trousers, jeans, or leggings.",
        "jeans": "If subtype is jeans, the bottom must visibly be jeans denim.",
        "sneakers": "If subtype is sneakers, the shoes must stay visible athletic sneakers.",
        "running_shoes": "If subtype is running_shoes, the shoes must stay visible athletic running shoes.",
        "hat": "If subtype is hat, a visible hat or cap must stay on the head and must not be omitted.",
        "bag": "If subtype is bag, a visible bag must appear in the final image.",
    }
    return rules.get(subtype, "")


def _build_subtype_priority_block(selected_items: list) -> str:
    if not selected_items:
        return ""
    rules = [
        "Subtype has higher priority than generic type for garment shape.",
        "Use name plus subtype as the main identity for each selected item, and use type only as a fallback bucket.",
        "If a subtype is present or inferred from the name, reproduce that exact clothing shape instead of a generic alternative.",
    ]
    seen = set()
    for item in selected_items:
        subtype = resolve_item_subtype(item)
        if not subtype or subtype in seen:
            continue
        seen.add(subtype)
        rule = _subtype_prompt_rule(subtype)
        if rule:
            rules.append(rule)
        if subtype == "dress_shirt" and _name_mentions_chemise(clean_text(getattr(item, "name", ""), "")):
            rules.append(
                "If the selected dress_shirt item name contains chemise, it must visibly remain a chemise: real button-up shirt, visible collar, front buttons, long sleeves, and shirt cuffs."
            )
    return "\n".join(rules)


def build_subtype_negative_prompt(selected_items: list) -> str:
    negative_terms = []
    for item in selected_items:
        subtype = resolve_item_subtype(item)
        item_name = clean_text(getattr(item, "name", ""), "")
        if subtype == "t_shirt":
            negative_terms.extend(["hoodie", "sweatshirt", "sweater", "jacket", "coat", "long sleeve top"])
        elif subtype == "dress_shirt":
            negative_terms.extend([
                "t-shirt",
                "tee",
                "polo shirt silhouette",
                "short-sleeve casual shirt",
                "hoodie",
                "sweatshirt",
                "sweater",
                "casual knit top",
            ])
            if _name_mentions_chemise(item_name):
                negative_terms.extend(["short sleeves", "short-sleeve shirt", "tee shirt"])
        elif subtype == "shirt":
            negative_terms.extend(["t-shirt", "hoodie", "sweatshirt", "sweater", "jacket", "polo shirt silhouette"])
        elif subtype == "hoodie":
            negative_terms.extend(["t-shirt silhouette", "polo shirt silhouette"])
        elif subtype == "shorts":
            negative_terms.extend(["joggers", "long pants", "trousers", "jeans", "leggings"])
        elif subtype == "jeans":
            negative_terms.extend(["non-denim trousers", "generic pants"])
        elif subtype in {"sneakers", "running_shoes"}:
            negative_terms.extend(["formal shoes", "boots", "loafers", "barefoot", "missing shoes"])
        elif subtype == "hat":
            negative_terms.extend(["missing hat", "no hat", "sunglasses"])
        elif subtype == "bag":
            negative_terms.extend(["missing bag", "hidden bag", "no bag"])
    return ", ".join(dict.fromkeys(negative_terms))


def _readable_subtype_label(subtype: str) -> str:
    return subtype.replace("_", " ").strip()


def _build_visual_item_instruction(item) -> str:
    item_type = _enum_value(getattr(item, "type", "")).lower()
    subtype = resolve_item_subtype(item)
    name = clean_text(getattr(item, "name", ""), "")
    color = _enum_value(getattr(item, "color", "")).lower() or "matching"
    category = _enum_value(getattr(item, "category", "")).lower() or "selected"
    season = _enum_value(getattr(item, "season", "")).lower()
    subtype_label = _readable_subtype_label(subtype) if subtype else item_type
    season_text = f" for {season}" if season else ""
    identity = f"selected item name \"{name}\"" if name else "selected wardrobe item"

    if subtype == "t_shirt":
        return (
            f"Top: Wear a {color} short-sleeve {category} T-shirt{season_text}. "
            f"Preserve {identity}. This must remain a short-sleeve T-shirt. "
            "Do not generate a hoodie, sweatshirt, sweater, jacket, coat, or long-sleeve top for this item."
        )
    if subtype == "dress_shirt":
        if _name_mentions_chemise(name):
            return (
                f"Top: Wear a visible {color} {category} chemise or dress shirt{season_text}. "
                f"Preserve {identity}. This must remain a real chemise with a visible collar, front buttons, long sleeves, and shirt cuffs. "
                "Do not generate a T-shirt, tee, polo, short-sleeve shirt, hoodie, sweatshirt, sweater, or casual knit top for this item."
            )
        return (
            f"Top: Wear a visible {color} {category} dress shirt{season_text}. "
            f"Preserve {identity}. This must remain a tailored dress shirt or button-up silhouette. "
            "Do not generate a T-shirt, hoodie, sweatshirt, sweater, or casual knit top for this item."
        )
    if subtype == "shirt":
        return (
            f"Top: Wear a visible {color} {category} shirt{season_text}. "
            f"Preserve {identity}. This must remain a shirt with a structured shirt silhouette. "
            "Do not generate a T-shirt, hoodie, sweatshirt, sweater, or jacket for this item."
        )
    if subtype == "shorts":
        return (
            f"Bottom: Wear {color} {category} shorts above the knee{season_text}. "
            f"Preserve {identity}. Legs below the knee must be visible. "
            "Do not generate joggers, pants, trousers, jeans, or leggings for this item."
        )
    if subtype in {"sneakers", "running_shoes"}:
        shoe_label = "running shoes" if subtype == "running_shoes" else "sneakers"
        return (
            f"Shoes: Wear visible {color} {category} athletic {shoe_label}{season_text}. "
            f"Preserve {identity}. The shoes must stay visible and must not be replaced with formal footwear."
        )
    if subtype == "hat":
        return (
            f"Accessory: Wear a visible {color} {category} hat or cap on the head{season_text}. "
            f"Preserve {identity}. Do not omit this selected accessory and do not replace it with sunglasses."
        )
    if subtype == "bag":
        return (
            f"Accessory: Show a visible {color} {category} bag carried or worn{season_text}. "
            f"Preserve {identity}. Do not omit this selected accessory."
        )
    if item_type == "top":
        return (
            f"Top: Wear a visible {color} {category} {subtype_label}{season_text}. "
            f"Preserve {identity} and keep the exact top shape."
        )
    if item_type == "bottom":
        return (
            f"Bottom: Wear visible {color} {category} {subtype_label}{season_text}. "
            f"Preserve {identity} and keep the exact bottom shape."
        )
    if item_type == "shoe":
        return (
            f"Shoes: Wear visible {color} {category} {subtype_label}{season_text}. "
            f"Preserve {identity} and keep the exact shoe shape."
        )
    if item_type == "accessory":
        return (
            f"Accessory: Show visible {color} {category} {subtype_label}{season_text}. "
            f"Preserve {identity} and do not omit this accessory."
        )
    return (
        f"Selected item: Preserve the exact {color} {category} {subtype_label}{season_text} "
        f"for {identity}."
    )


def build_body_shape_instruction(body_shape: str) -> str:
    value = normalize_body_shape(body_shape)
    if value == "Slim":
        return "Body shape slim, visibly lean and narrow."
    if value == "Athletic":
        return "Body shape athletic, visibly fit and toned."
    if value == "Regular":
        return "Body shape regular, balanced average proportions."
    if value == "Curvy":
        return "Body shape curvy, visible fuller hips and thighs with rounded silhouette."
    if value == "Plus Size":
        return "Body shape plus size, visibly fuller torso, waist, hips, thighs, arms, and legs."
    return "Body shape regular, balanced average proportions."


def build_skin_tone_instruction(skin_tone: str) -> str:
    value = normalize_skin_tone(skin_tone)
    if value == "Fair":
        return "Skin tone fair."
    if value == "Light":
        return "Skin tone light."
    if value == "Medium":
        return "Skin tone medium."
    if value == "Tan":
        return "Skin tone tan."
    if value == "Dark":
        return "Skin tone dark brown."
    return "Skin tone medium."


def build_height_weight_instruction(height, weight) -> str:
    height_value = try_float(height)
    weight_value = try_float(weight)
    parts = []
    if height_value is not None:
        if height_value < 160:
            parts.append(f"Height visually short around {height_value:g} cm.")
        elif height_value <= 175:
            parts.append(f"Height visually average around {height_value:g} cm.")
        elif height_value <= 190:
            parts.append(f"Height visually tall around {height_value:g} cm.")
        else:
            parts.append(f"Height visually very tall around {height_value:g} cm.")
    if weight_value is not None:
        if weight_value < 55:
            parts.append(f"Weight visually light around {weight_value:g} kg.")
        elif weight_value <= 75:
            parts.append(f"Weight visually medium around {weight_value:g} kg.")
        elif weight_value <= 95:
            parts.append(f"Weight visually fuller around {weight_value:g} kg.")
        else:
            parts.append(f"Weight visually heavy around {weight_value:g} kg.")
    return " ".join(parts).strip()


def build_outfit_hint(
    weather_label: str,
    temperature_value: Optional[float],
    style: str,
    color: str,
    body_shape: str,
) -> str:
    shape = normalize_body_shape(body_shape)
    normalized_style = normalize_style(style)
    style_core = {
        "Casual": (
            "relaxed everyday casual outfit with jeans, denim, hoodie, sweatshirt, bomber jacket, "
            "relaxed pants, and simple sneakers, with a natural daily lifestyle vibe"
        ),
        "Sport": (
            "athletic sport outfit with tracksuit, running jacket, compression wear, gym hoodie, joggers, "
            "and performance sneakers, with clear training or running energy"
        ),
        "Chic": (
            "chic polished outfit with elegant refined clothing, tailored structure, and a sophisticated finish"
        ),
    }.get(normalized_style, "relaxed everyday casual outfit with a natural daily lifestyle vibe")

    fit_hint = {
        "Slim": "with a silhouette suited to a slim body",
        "Athletic": "with a silhouette suited to an athletic body",
        "Regular": "with a silhouette suited to a regular body",
        "Curvy": "with a silhouette suited to a curvy body",
        "Plus Size": "with a silhouette suited to a plus-size body",
    }.get(shape, "with a natural silhouette")

    posture_hint = (
        "with more athletic body posture and sporty energy"
        if normalized_style == "Sport"
        else "with a relaxed real-life posture"
    )

    if weather_label == "Rainy":
        return (
            f"{style_core} with the main visible top and bottom in dominant {color} color, "
            f"weather-ready shoes, precipitation-resistant outwear, {fit_hint}, {posture_hint}."
        )
    if weather_label == "Snowy":
        return (
            f"{style_core} with the main visible top and bottom in dominant {color} color, "
            f"warm layers and weather-appropriate shoes, {fit_hint}, {posture_hint}."
        )
    if temperature_value is not None and temperature_value >= 28:
        return (
            f"{style_core} with the main visible top and bottom in dominant {color} color, "
            f"breathable light clothing and matching shoes for warm weather, {fit_hint}, {posture_hint}."
        )
    if weather_label in {"Cloudy", "Windy"} or (
        temperature_value is not None and temperature_value <= 18
    ):
        return (
            f"{style_core} with the main visible top and bottom in dominant {color} color, "
            f"layered weather-appropriate clothing and matching shoes, {fit_hint}, {posture_hint}."
        )
    return (
        f"{style_core} with the main visible top and bottom in dominant {color} color, "
        f"weather-appropriate top, bottom, and shoes, {fit_hint}, {posture_hint}."
    )


def build_style_priority_rule(style: str) -> str:
    normalized_style = normalize_style(style)
    common_rule = (
        f"Style priority is absolute: the outfit must read immediately as {normalized_style}. "
        "Weather may only adapt fabric weight, layering, footwear, and protective outerwear. "
        "Color may only change the palette inside the selected style. "
        "Do not let weather, color, background, or extra instructions change the chosen style category."
    )
    if normalized_style == "Casual":
        return (
            f"{common_rule} "
            "Casual means relaxed everyday fashion only: jeans, denim, hoodie, sweatshirt, bomber jacket, relaxed pants, simple sneakers, casual skirts, or easy daily dresses. "
            "Keep the look natural, wearable, effortless, and grounded in normal day-to-day lifestyle. "
            "Avoid gymwear, athletic training outfits, running gear, performance compression pieces, luxury eveningwear, formal tailoring, and polished elegant chic clothing."
        )
    if normalized_style == "Sport":
        return (
            f"{common_rule} "
            "Sport means athletic activewear and training fashion only: tracksuit, running jacket, compression wear, gym hoodie, joggers, performance tops, sporty sets, and performance sneakers. "
            "The outfit must look designed for gym, training, running, or athletic movement, with a more athletic body posture and sporty energy. "
            "Avoid blazers, formalwear, elegant chic styling, luxury dresswear, office tailoring, polished evening outfits, and normal casual streetwear."
        )
    if normalized_style == "Chic":
        return (
            f"{common_rule} "
            "Chic means elegant polished clothing only: refined blouse, tailored trousers, elegant skirt, polished dress, structured coat, sleek knitwear, heeled shoes, loafers, or other sophisticated pieces. "
            "The outfit must look elevated, neat, and intentionally styled. "
            "Do not use hoodie, joggers, tracksuit, gym clothes, oversized streetwear, casual athleticwear, or sloppy relaxed street styling."
        )
    return common_rule


def build_selected_color_rule(color: str) -> str:
    selected_color = clean_text(color, "black").lower()
    readable_color = selected_color.capitalize()
    disallowed_colors = [
        item.capitalize()
        for item in SUPPORTED_OUTFIT_COLORS
        if item != selected_color
    ]
    disallowed_text = ", ".join(disallowed_colors)
    return (
        f"The dominant color of the main outfit must be {readable_color}. "
        f"The sweatshirt, shirt, jacket, top, trousers, pants, skirt, or dress must read clearly as {readable_color}. "
        f"Do not make {disallowed_text} the dominant clothing color. "
        f"If small accents are needed, keep them minimal and neutral, but the outfit must still look clearly {readable_color} at first glance. "
        f"A viewer should immediately describe the outfit as {readable_color}."
    )


def build_color_negative_prompt(color: str) -> str:
    selected_color = clean_text(color, "black").lower()
    other_colors = [item for item in SUPPORTED_OUTFIT_COLORS if item != selected_color]
    return ", ".join(
        [
            "wrong clothing color",
            "different dominant outfit color",
            "mismatched color palette",
            "outfit not matching requested color",
            "top or bottom in a different dominant color",
            *[f"dominant {item} outfit" for item in other_colors],
        ]
    )


def build_edit_item_color_negative_prompt(selected_items: list) -> str:
    negative_terms = []
    for item in selected_items:
        item_type = _enum_value(getattr(item, "type", "")).lower()
        item_color = clean_text(_enum_value(getattr(item, "color", "")), "").lower()
        if item_type not in {"top", "bottom", "shoe", "outwear", "accessory"}:
            continue
        if not item_color or item_color not in SUPPORTED_OUTFIT_COLORS:
            continue

        other_colors = [
            color for color in SUPPORTED_OUTFIT_COLORS if color != item_color
        ]
        slot_label = {
            "top": "top",
            "bottom": "bottom",
            "shoe": "shoes",
            "outwear": "outerwear",
            "accessory": "accessory",
        }.get(item_type, item_type)

        negative_terms.append(f"wrong {slot_label} color")
        negative_terms.append(f"{slot_label} not {item_color}")
        negative_terms.extend(
            f"{other_color} {slot_label}" for other_color in other_colors
        )

    return ", ".join(dict.fromkeys(negative_terms))


def build_style_negative_prompt(style: str) -> str:
    normalized_style = normalize_style(style)
    base_terms = [
        "wrong clothing style",
        "outfit not matching selected style",
        "mixed conflicting fashion styles",
        "style dominated by the wrong aesthetic",
    ]
    if normalized_style == "Casual":
        style_terms = [
            "gym-only outfit", "performance training clothes", "full athletic kit",
            "tracksuit", "running jacket", "compression wear", "formal elegant outfit",
            "luxury eveningwear", "tailored blazer look",
        ]
    elif normalized_style == "Sport":
        style_terms = [
            "normal casual streetwear", "everyday denim outfit", "lifestyle casual look",
            "jeans and bomber casual styling", "blazer", "formalwear", "elegant chic outfit",
            "office tailoring", "evening dresswear", "polished formal styling",
        ]
    elif normalized_style == "Chic":
        style_terms = [
            "hoodie", "joggers", "tracksuit", "gym clothes", "oversized streetwear",
            "athletic training outfit", "casual street style",
        ]
    else:
        style_terms = []
    return ", ".join([*base_terms, *style_terms])


def _style_to_item_category(style: str) -> str:
    normalized = clean_text(style, "").strip().lower()
    mapping = {"casual": "casual", "sport": "sport", "chic": "chic"}
    return mapping.get(normalized, normalized)


def _is_rainy_weather(data: dict) -> bool:
    weather_label = clean_text(data.get("weather_label"), "").lower()
    precipitation = clean_text(data.get("precipitation"), "").lower()
    weather = clean_text(data.get("weather"), "").lower()
    return (
        "rain" in weather_label
        or precipitation == "yes"
        or "rain" in weather
        or "drizzle" in weather
        or "shower" in weather
    )


def _is_cold_weather(data: dict) -> bool:
    weather_label = clean_text(data.get("weather_label"), "").lower()
    temperature_value = data.get("temperature_value")
    if temperature_value is not None and temperature_value <= 18:
        return True
    return weather_label in {"snowy", "windy"}


def _preferred_seasons(data: dict) -> set[str]:
    temperature_value = data.get("temperature_value")
    weather_label = clean_text(data.get("weather_label"), "").lower()
    if _is_rainy_weather(data):
        return {"spring", "autumn", "winter", "summer"}
    if weather_label == "snowy":
        return {"winter"}
    if temperature_value is not None:
        if temperature_value >= 28:
            return {"summer"}
        if temperature_value <= 18:
            return {"winter", "autumn"}
        if temperature_value <= 24:
            return {"spring", "summer", "autumn"}
        return {"spring", "summer", "autumn"}
    return set()


def _season_weather_score(item, preferred_seasons: set[str], data: dict) -> int:
    item_season = _enum_value(getattr(item, "season", "")).lower()
    if not item_season:
        return 1
    if not preferred_seasons:
        return 2
    if item_season in preferred_seasons:
        return 6
    temperature_value = data.get("temperature_value")
    weather_label = clean_text(data.get("weather_label"), "").lower()
    if item_season == "summer" and temperature_value is not None and temperature_value >= 22:
        return 4
    if item_season == "spring" and temperature_value is not None and 20 <= temperature_value <= 28:
        return 4
    if item_season == "autumn" and temperature_value is not None and 16 <= temperature_value <= 24:
        return 4
    if item_season == "winter" and (
        weather_label == "snowy" or (temperature_value is not None and temperature_value <= 18)
    ):
        return 4
    return -2


def _matches_selected_color(item, data: dict) -> bool:
    selected_color = clean_text(data.get("color"), "").lower()
    item_color = _enum_value(getattr(item, "color", "")).lower()
    if not selected_color or not item_color:
        return True
    return item_color == selected_color


def _material_weather_score(material: str, data: dict) -> int:
    normalized = clean_text(material, "").lower()
    if not normalized:
        return 0
    rainy = _is_rainy_weather(data)
    cold = _is_cold_weather(data)
    temperature_value = data.get("temperature_value")
    score = 0
    if rainy and any(
        keyword in normalized
        for keyword in ("waterproof", "water-resistant", "rain", "nylon", "shell")
    ):
        score += 4
    if cold and any(
        keyword in normalized
        for keyword in ("wool", "fleece", "knit", "cashmere", "down", "leather", "denim")
    ):
        score += 3
    if temperature_value is not None and temperature_value >= 28 and any(
        keyword in normalized
        for keyword in ("cotton", "linen", "mesh", "jersey", "dry-fit", "polyester")
    ):
        score += 3
    return score


def _item_quality_score(item) -> int:
    score = 0
    if clean_text(getattr(item, "name", ""), ""):
        score += 1
    if resolve_item_subtype(item):
        score += 2
    if clean_text(getattr(item, "material", ""), ""):
        score += 1
    if clean_text(getattr(item, "image_url", ""), ""):
        score += 1
    if _item_visual_description(item):
        score += 3
    if _item_ai_metadata(item):
        score += 2
    usage_count = getattr(item, "usage_count", 0) or 0
    if usage_count > 0:
        score += min(int(usage_count), 3)
    return score


# ---------------------------------------------------------------------------
# ✅ CHANGED: Only hard-filter on logical constraints (outwear rules).
#    Color & category are now SOFT preferences handled entirely by scoring.
# ---------------------------------------------------------------------------
def _matches_common_preferences(item, data: dict, preferred_seasons: set[str]) -> bool:
    """Hard constraints only — colour & category moved to scoring."""
    item_type = _enum_value(getattr(item, "type", "")).lower()

    # Outwear only when rainy
    if item_type == "outwear" and not _is_rainy_weather(data):
        return False
    # Outwear must be precipitation-resistant
    if item_type == "outwear" and not getattr(item, "precipitation_resistant", False):
        return False

    return True


# ---------------------------------------------------------------------------
# ✅ CHANGED: colour & category now give bonus points instead of excluding
# ---------------------------------------------------------------------------
def _score_matching_item(item, data: dict, preferred_seasons: set[str]) -> int:
    score = 0
    item_type = _enum_value(getattr(item, "type", "")).lower()
    item_color = _enum_value(getattr(item, "color", "")).lower()
    item_category = _enum_value(getattr(item, "category", "")).lower()
    item_material = clean_text(getattr(item, "material", ""), "")
    selected_color = clean_text(data.get("color"), "").lower()
    selected_category = _style_to_item_category(data.get("style", ""))

    # Colour — bonus when matching, small base otherwise
    if selected_color and item_color == selected_color:
        score += 10
    elif selected_color and item_color and item_color != selected_color:
        score += 2           # ✅ usable, not ideal
    elif not item_color:
        score += 3

    # Category — bonus when matching, small base otherwise
    if selected_category and item_category == selected_category:
        score += 10
    elif selected_category and item_category and item_category != selected_category:
        score += 2           # ✅ usable, not ideal
    elif not item_category:
        score += 3

    score += _season_weather_score(item, preferred_seasons, data)

    if _is_rainy_weather(data):
        if item_type == "outwear" and getattr(item, "precipitation_resistant", False):
            score += 10
        if item_type == "shoe" and getattr(item, "precipitation_resistant", False):
            score += 5

    if item_type in {"top", "bottom", "shoe"}:
        score += 3
    elif item_type == "accessory":
        score += 1
    elif item_type == "outwear":
        score += 2

    score += _material_weather_score(item_material, data)
    score += _item_quality_score(item)

    return score


def _score_outfit_combination(items: list, data: dict, preferred_seasons: set[str]) -> int:
    score = sum(_score_matching_item(item, data, preferred_seasons) for item in items)
    colors = [
        _enum_value(getattr(item, "color", "")).lower()
        for item in items
        if _enum_value(getattr(item, "color", "")).lower()
    ]
    categories = [
        _enum_value(getattr(item, "category", "")).lower()
        for item in items
        if _enum_value(getattr(item, "category", "")).lower()
    ]
    materials = [
        clean_text(getattr(item, "material", ""), "").lower()
        for item in items
        if clean_text(getattr(item, "material", ""), "")
    ]
    if colors:
        dominant_color = max(colors, key=colors.count)
        score += colors.count(dominant_color) * 2
    if categories:
        dominant_category = max(categories, key=categories.count)
        score += categories.count(dominant_category) * 2
    if materials:
        repeated_material_family = max(materials, key=materials.count)
        if materials.count(repeated_material_family) > 1:
            score += 2
    if any(_enum_value(getattr(item, "type", "")).lower() == "shoe" for item in items):
        score += 3
    if _is_rainy_weather(data):
        if any(_enum_value(getattr(item, "type", "")).lower() == "outwear" for item in items):
            score += 4
    else:
        if any(_enum_value(getattr(item, "type", "")).lower() == "outwear" for item in items):
            score -= 8
    return score


def _choose_best_accessory(items, data: dict, preferred_seasons: set[str]):
    if not items:
        return None
    ranked = sorted(
        items,
        key=lambda item: _score_matching_item(item, data, preferred_seasons),
        reverse=True,
    )
    best = ranked[0]
    if _score_matching_item(best, data, preferred_seasons) < 8:
        return None
    return best


def _prefer_selected_color_items(items: list, selected_color: str) -> list:
    normalized_color = clean_text(selected_color, "").lower()
    if not normalized_color:
        return items

    exact_matches = [
        item
        for item in items
        if _enum_value(getattr(item, "color", "")).lower() == normalized_color
    ]
    return exact_matches or items


# ---------------------------------------------------------------------------
# ✅ CHANGED: Relax selection — require top+bottom, shoes optional,
#    limit candidates per type so product() stays fast.
# ---------------------------------------------------------------------------
def _select_matching_wardrobe_outfit(wardrobe_items, data: dict) -> tuple[list, Optional[str]]:
    if not wardrobe_items:
        return [], NO_MATCHING_WARDROBE_WARNING

    preferred_seasons = _preferred_seasons(data)
    grouped: dict[str, list] = {
        "top": [], "bottom": [], "shoe": [], "outwear": [], "accessory": [],
    }

    for item in wardrobe_items:
        item_type = _enum_value(getattr(item, "type", "")).lower()
        if item_type not in grouped:
            continue
        if _matches_common_preferences(item, data, preferred_seasons):
            grouped[item_type].append(item)

    # ✅ Require at least top AND bottom
    if not grouped["top"] or not grouped["bottom"]:
        return [], NO_MATCHING_WARDROBE_WARNING

    # Pre-sort and limit to top-N per type to keep product() fast
    for key in grouped:
        grouped[key].sort(
            key=lambda it: _score_matching_item(it, data, preferred_seasons),
            reverse=True,
        )
        grouped[key] = grouped[key][:MAX_CANDIDATES_PER_TYPE]

    # When the requested color exists in wardrobe, keep that color for the
    # main outfit pieces so the generator does not drift to mismatched tones.
    selected_color = clean_text(data.get("color"), "").lower()
    grouped["top"] = _prefer_selected_color_items(grouped["top"], selected_color)
    grouped["bottom"] = _prefer_selected_color_items(grouped["bottom"], selected_color)
    grouped["shoe"] = _prefer_selected_color_items(grouped["shoe"], selected_color)
    if requires_outwear := _is_rainy_weather(data):
        grouped["outwear"] = _prefer_selected_color_items(grouped["outwear"], selected_color)

    shoe_options = grouped["shoe"] if grouped["shoe"] else [None]
    outwear_options = grouped["outwear"] if requires_outwear and grouped["outwear"] else [None]

    best_combo = None
    best_score = None

    for top, bottom, shoe, outwear in product(
        grouped["top"], grouped["bottom"], shoe_options, outwear_options,
    ):
        combo = [top, bottom]
        if shoe is not None:
            combo.append(shoe)
        if outwear is not None:
            combo.append(outwear)
        combo_score = _score_outfit_combination(combo, data, preferred_seasons)
        if best_score is None or combo_score > best_score:
            best_score = combo_score
            best_combo = combo

    if not best_combo:
        return [], NO_MATCHING_WARDROBE_WARNING

    # Informational warning when shoes are missing from wardrobe
    has_shoes = any(
        _enum_value(getattr(it, "type", "")).lower() == "shoe"
        for it in best_combo
    )
    warning = (
        None if has_shoes
        else "No matching shoes found in your wardrobe — the AI will suggest appropriate footwear."
    )

    logger.info(
        "Wardrobe outfit selected: items=%s score=%s has_shoes=%s",
        [clean_text(getattr(it, "name", ""), "?") for it in best_combo],
        best_score,
        has_shoes,
    )
    return best_combo, warning


def _format_wardrobe_item(item) -> str:
    name = clean_text(getattr(item, "name", ""), "")
    item_type = _enum_value(getattr(item, "type", ""))
    item_subtype = resolve_item_subtype(item)
    category = _enum_value(getattr(item, "category", ""))
    color = _enum_value(getattr(item, "color", ""))
    material = clean_text(getattr(item, "material", ""), "")
    season = _enum_value(getattr(item, "season", ""))
    precipitation_resistant = getattr(item, "precipitation_resistant", False)
    parts = []
    if name:
        parts.append(name)
    if item_subtype:
        parts.append(f"subtype {item_subtype}")
    if item_type:
        parts.append(f"type {item_type}")
    if category:
        parts.append(f"style/category {category}")
    if color:
        parts.append(f"color {color}")
    if material:
        parts.append(f"material {material}")
    if season:
        parts.append(f"season {season}")
    if precipitation_resistant:
        parts.append("rain resistant")
    return ", ".join(parts)


def serialize_wardrobe_item_detail(item) -> dict:
    return {
        "id": str(getattr(item, "id", "") or ""),
        "name": clean_text(getattr(item, "name", ""), ""),
        "type": _enum_value(getattr(item, "type", "")),
        "itemSubtype": resolve_item_subtype(item),
        "category": _enum_value(getattr(item, "category", "")),
        "color": _enum_value(getattr(item, "color", "")),
        "material": clean_text(getattr(item, "material", ""), ""),
        "season": _enum_value(getattr(item, "season", "")),
        "imageUrl": clean_text(getattr(item, "image_url", ""), ""),
        "visualDescription": _item_visual_description(item),
        "precipitationResistant": bool(getattr(item, "precipitation_resistant", False)),
        "wardrobeMatched": True,
        "summary": _format_wardrobe_item(item),
    }


def build_wardrobe_prompt_block(data: dict) -> str:
    selected_items = data.get("selected_wardrobe_items") or []
    if not selected_items:
        return ""
    lines = []
    visual_instructions = []
    for item in selected_items:
        formatted = _format_wardrobe_item(item)
        if formatted:
            lines.append(f"- {formatted}")
        visual_instruction = _build_visual_item_instruction(item)
        if visual_instruction:
            visual_instructions.append(f"- {visual_instruction}")
    if not lines:
        return ""
    required_lines = []
    for item in selected_items:
        item_type = _enum_value(getattr(item, "type", "")).lower()
        item_subtype = resolve_item_subtype(item)
        item_name = clean_text(getattr(item, "name", ""), "")
        item_color = _enum_value(getattr(item, "color", "")).lower()
        item_category = _enum_value(getattr(item, "category", "")).lower()
        item_season = _enum_value(getattr(item, "season", "")).lower()
        if item_type in {"top", "bottom", "shoe", "accessory", "outwear"}:
            detail_parts = []
            if item_name:
                detail_parts.append(f"name={item_name}")
            if item_subtype:
                detail_parts.append(f"subtype={item_subtype}")
            if item_type:
                detail_parts.append(f"type={item_type}")
            if item_color:
                detail_parts.append(f"color={item_color}")
            if item_category:
                detail_parts.append(f"style={item_category}")
            if item_season:
                detail_parts.append(f"season={item_season}")
            if detail_parts:
                required_lines.append("- " + ", ".join(detail_parts))
    return (
        "\nSelected wardrobe items from the user's chosen wardrobe:\n"
        + "\n".join(lines)
        + (
            "\nExact matched wardrobe items to reproduce in the final image:\n"
            + "\n".join(required_lines)
            if required_lines else ""
        )
        + (
            "\nMandatory visual instructions for the selected wardrobe items:\n"
            + "\n".join(visual_instructions)
            if visual_instructions else ""
        )
        + "\nThe generated outfit must be based on these wardrobe items first and follow them closely. "
        + "Use name, subtype, type, color, style/category, season, material, and weather properties for each item when visible. "
        "Subtype is stronger than style, weather, and generic type and must control the garment shape. "
        "If subtype is missing, infer it from the item name before falling back to generic type. "
        "Accurately reproduce the selected wardrobe pieces instead of inventing different garments. "
        "Style may influence aesthetic only and must not change the selected subtype. "
        "Weather may adapt background and small details only and must not replace a T-shirt with hoodie or shorts with pants when those wardrobe items are selected. "
        "Top, bottom, and shoes are required. Shoes must always be visible. "
        "Outwear is only allowed when the weather is rainy or precipitation is yes, and then it must be precipitation resistant. "
        "Accessory is optional only if it matches the outfit. "
        "Do not invent a completely different outfit if these wardrobe items can satisfy the weather, style, and selected color. "
        "The selected wardrobe items are mandatory. Preserve the exact subtype, color, and clothing shape of every selected wardrobe item. "
        "Do not replace selected wardrobe pieces with visually different garments. "
        "The final outfit should look coordinated, realistic, and not ugly or mismatched.\n"
        + _build_subtype_priority_block(selected_items)
        + "\n"
    )


def resolve_generation_data(
    current_user: User,
    payload: GenerateOutfitImageRequest,
    profile: Optional[UserProfile],
    preference: Optional[UserPreference],
) -> dict:
    profile_birth_date = getattr(profile, "birth_date", None) if profile else None
    age = calculate_age(payload.birth_date or profile_birth_date)
    gender = normalize_gender(
        payload.gender or (getattr(profile, "gender", None) if profile else None)
    )
    style = normalize_style(payload.style)
    color = safe_prompt_value(payload.color, "neutral")
    if preference:
        if not payload.style and getattr(preference, "favorite_styles", None):
            first_style = preference.favorite_styles[0] if preference.favorite_styles else "Casual"
            style = normalize_style(first_style)
        if not payload.color and getattr(preference, "favorite_colors", None):
            first_color = preference.favorite_colors[0] if preference.favorite_colors else "neutral"
            color = safe_prompt_value(first_color, "neutral")
    body_shape = normalize_body_shape(
        payload.body_shape or (getattr(profile, "body_shape", None) if profile else None)
    )
    skin_tone = normalize_skin_tone(
        payload.skin_tone or (getattr(profile, "skin_tone", None) if profile else None)
    )
    height = (
        payload.height if payload.height is not None
        else getattr(profile, "height", None) if profile else None
    )
    weight = (
        payload.weight if payload.weight is not None
        else getattr(profile, "weight", None) if profile else None
    )
    city = safe_prompt_value(payload.city, "Outdoor Street")
    country = safe_prompt_value(payload.country, "")
    temperature = clean_text(payload.temperature, "not specified")
    temperature_value = parse_temperature_c(payload.temperature)
    weather = clean_text(payload.weather, "cloudy")
    precipitation = clean_text(payload.precipitation, "No")
    humidity = clean_text(payload.humidity, "not specified")
    wind = clean_text(payload.wind, "not specified")
    time_of_day = clean_text(payload.time_of_day, "daytime")
    extra_instructions = clean_text(payload.extra_instructions, "")
    weather_label = normalize_weather_label(weather, precipitation)
    scene_rules = build_weather_scene_rules(weather_label, temperature_value, time_of_day)
    outfit_hint = build_outfit_hint(
        weather_label=weather_label,
        temperature_value=temperature_value,
        style=style,
        color=color,
        body_shape=body_shape,
    )
    age_text = f"{age} years old" if age is not None else "adult"
    height_text = format_measurement(height, "cm")
    weight_text = format_measurement(weight, "kg")
    return {
        "gender": gender,
        "style": style,
        "color": color,
        "body_shape": body_shape,
        "skin_tone": skin_tone,
        "height": height,
        "weight": weight,
        "height_text": height_text,
        "weight_text": weight_text,
        "age_text": age_text,
        "city": city,
        "country": country,
        "temperature": temperature,
        "temperature_value": temperature_value,
        "weather": weather,
        "weather_label": weather_label,
        "precipitation": precipitation,
        "humidity": humidity,
        "wind": wind,
        "time_of_day": time_of_day,
        "extra_instructions": extra_instructions,
        "scene_rules": scene_rules,
        "outfit_hint": outfit_hint,
        "body_shape_instruction": build_body_shape_instruction(body_shape),
        "skin_tone_instruction": build_skin_tone_instruction(skin_tone),
        "height_weight_instruction": build_height_weight_instruction(height, weight),
    }


def build_outfit_ai_prompt(data: dict) -> str:
    extra_instruction_block = ""
    if data.get("extra_instructions"):
        extra_instruction_block = (
            "\nUser requested outfit changes:\n"
            f"{data['extra_instructions']}\n"
        )
    wardrobe_block = build_wardrobe_prompt_block(data)
    prompt = f"""
One real full-body {data["gender"]} person standing outdoors on a natural street.

Generate the person using the current selected attributes only.
If gender, skin tone, body shape, height, or weight changes, the generated person must change accordingly.

Current person attributes:
Gender {data["gender"]}.
Age {data["age_text"]}.
Skin tone {data["skin_tone"]}.
Body shape {data["body_shape"]}.
Height {data["height_text"]}.
Weight {data["weight_text"]}.

Current outfit inputs:
Weather and background {data["weather_label"]}, {data["temperature"]} C, {data["time_of_day"]}.
Style {data["style"]}.
Selected color {data["color"]}.

The image must show one person only, full body from head to shoes, centered in frame.
The person is the main subject.
The weather must be visible in the background and may adapt layering and fabric choices only.
Shoes are mandatory in every outfit and must be visible.
If selected wardrobe items include subtype metadata, subtype overrides generic type when deciding the clothing shape.

Style rule:
{build_style_priority_rule(data["style"])}

Color rule:
{build_selected_color_rule(data["color"])}
If the selected color is Red, the outfit must be red.
If the selected color is Green, the outfit must be green.
If the selected color is Black, the outfit must be black.
If the selected color is Purple, the outfit must be purple.

Wardrobe and weather rules:
Top, bottom, and shoes are always required.
Shoes must match the selected outfit color, style, and weather.
Outwear is required only when precipitation is yes or the weather is rainy.
If outwear is used for rain, it must be precipitation resistant.
Accessory is optional and should be used only if it matches the outfit.

Avatar details:
{data["skin_tone_instruction"]}
{data["body_shape_instruction"]}
{data["height_weight_instruction"]}

Outfit:
{data["outfit_hint"]}
{wardrobe_block}
{extra_instruction_block}

Background and weather:
Location {data["city"]} {data["country"]}.
{data["scene_rules"]}

Ultra realistic professional fashion photography.
Real human model.
Sharp focus.
Highly detailed face and clothing textures.
Natural skin texture.
Realistic fabric folds.
Realistic proportions.
Modern fashion photoshoot matching the selected style exactly.
DSLR quality.
Crisp details.
Clear shoes.
Clear hands.
Clean lighting.
Editorial fashion photography.

The outfit must look realistic and wearable in real life.
Avoid cartoon, painting, illustration, CGI, anime, 3D render, game art, dreamy style, overexposed clothing, blurry face, soft focus, melted clothes, glowing outfit, white blob clothing.

No text, watermark, logo, UI, extra people, duplicate limbs, distorted anatomy, unrealistic body, blurred outfit.
""".strip()
    return limit_text(prompt, PROMPT_MAX_LENGTH)


# ---------------------------------------------------------------------------
# ✅ CHANGED: main generation function — two-step avatar + wardrobe dressing
# ---------------------------------------------------------------------------
async def generate_outfit_image_payload(
    current_user: User,
    payload: GenerateOutfitImageRequest,
    profile: Optional[UserProfile],
    preference: Optional[UserPreference],
    db,
    wardrobe_items=None,
) -> dict:
    if not IMAGE_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Image API key is missing in backend .env",
        )

    data = resolve_generation_data(
        current_user=current_user,
        payload=payload,
        profile=profile,
        preference=preference,
    )
    logger.info("===== DEBUG GENERATION INPUT =====")
    logger.info("payload.style=%s", payload.style)
    logger.info("payload.color=%s", payload.color)
    logger.info("payload.weather=%s", payload.weather)
    logger.info("payload.temperature=%s", payload.temperature)
    logger.info("payload.wardrobe_id=%s", payload.wardrobe_id)
    logger.info("payload.avatar_reference_image_url=%s", payload.avatar_reference_image_url)
    logger.info("=================================")
    selected_wardrobe_items = []
    wardrobe_warning = None

    if payload.wardrobe_id is not None:
        selected_wardrobe_items, wardrobe_warning = _select_matching_wardrobe_outfit(
            wardrobe_items or [],
            data,
        )
        logger.info(
            "Wardrobe selection wardrobe_id=%s selected_count=%s warning=%s "
            "items=%s",
            payload.wardrobe_id,
            len(selected_wardrobe_items),
            wardrobe_warning,
            [clean_text(getattr(it, "name", ""), "?") for it in selected_wardrobe_items],
        )

    data["selected_wardrobe_items"] = selected_wardrobe_items
    wardrobe_warning = None if selected_wardrobe_items else wardrobe_warning

    fallback_prompt = build_outfit_ai_prompt(data)
    generation_seed = build_generation_seed(current_user, data)

    avatar_image_url = clean_text(
        payload.avatar_reference_image_url
        or (getattr(profile, "profile_image_url", None) if profile else None),
        "",
    )

    headers = {
        "Authorization": f"Bearer {IMAGE_API_KEY}",
        "Content-Type": "application/json",
    }

    # ---- Build composite & choose generation mode ----
    reference_base64 = ""
    image_generation_mode = "generate"
    selected_reference_items = selected_wardrobe_items

    if avatar_image_url and selected_wardrobe_items:
        # ✅ CHANGED: pass `data` so composite builder can generate full-body
        reference_base64, selected_reference_items = (
            await _build_edit_image_reference_base64(
                avatar_image_url,
                selected_wardrobe_items,
                data,
            )
        )

    logger.info(
        "Generation decision: avatar_url=%s has_composite=%s "
        "wardrobe_count=%s ref_count=%s",
        bool(avatar_image_url),
        bool(reference_base64),
        len(selected_wardrobe_items),
        len(selected_reference_items),
    )

    if avatar_image_url and selected_reference_items and reference_base64:
        # ✅ edit-image path — dress the avatar with wardrobe items
        image_generation_mode = "edit-image"
        prompt = build_edit_image_prompt(data, selected_reference_items)
        endpoint_path = "/api/edit-image"
        request_body = {
            "model": IMAGE_API_MODEL,
            "prompt": prompt,
            "imageBase64": reference_base64,
            "stream": False,
            "options": {
                "strength": EDIT_IMAGE_STRENGTH,
                "steps": EDIT_IMAGE_STEPS,
                "cfg": EDIT_IMAGE_CFG,
                "negativePrompt": (
                    "plain white t-shirt, neutral placeholder clothes, gray joggers, "
                    "white sneakers, wrong outfit, different clothes, invented garments, "
                    "missing selected item, floating clothes, clothing collage, split screen, "
                    "side-by-side layout, extra garments, duplicate accessories, "
                    "headshot crop, close-up face crop, portrait crop, bust crop, half body crop, "
                    "missing legs, missing lower body, missing feet, "
                    f"{build_style_negative_prompt(data['style'])}, "
                    f"{build_color_negative_prompt(data['color'])}, "
                    f"{build_edit_item_color_negative_prompt(selected_reference_items)}, "
                    f"{build_subtype_negative_prompt(selected_reference_items)}"
                ),
            },
        }
    else:
        prompt = fallback_prompt
        endpoint_path = "/api/generate"
        request_body = {
            "model": IMAGE_API_MODEL,
            "prompt": fallback_prompt,
            "stream": False,
            "options": {
                "width": IMAGE_WIDTH,
                "height": IMAGE_HEIGHT,
                "steps": IMAGE_STEPS,
                "cfg": IMAGE_CFG,
                "negativePrompt": (
                    "blurry, low quality, soft focus, out of focus, "
                    "cartoon, anime, illustration, painting, CGI, 3d render, "
                    "white blob clothing, glowing clothes, melted clothes, "
                    "bad anatomy, distorted body, unrealistic proportions, "
                    "duplicate limbs, bad hands, blurry face, washed colors, "
                    "foggy image, motion blur, cropped body, missing shoes, "
                    "extra people, watermark, logo, text, ugly outfit, "
                    f"{build_style_negative_prompt(data['style'])}, "
                    f"{build_color_negative_prompt(data['color'])}, "
                    f"{build_subtype_negative_prompt(selected_wardrobe_items)}"
                ),
            },
        }
        if not avatar_image_url:
            logger.info("Using /api/generate — no avatar reference image")
        elif not selected_wardrobe_items:
            logger.info("Using /api/generate — no wardrobe items selected")
        elif not reference_base64:
            logger.info("Using /api/generate — composite image build failed")

    if not clean_text(prompt, ""):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing prompt for image generation.",
        )

    logger.info(
        "Image API request mode=%s endpoint=%s prompt_length=%s items=%s",
        image_generation_mode,
        endpoint_path,
        len(prompt),
        len(selected_reference_items or []),
    )

    try:
        async with httpx.AsyncClient(timeout=HTTP_TIMEOUT_SECONDS) as client:
            response = await client.post(
                f"{IMAGE_API_BASE_URL}{endpoint_path}",
                json=request_body,
                headers=headers,
            )

        if response.status_code == status.HTTP_401_UNAUTHORIZED:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or missing Image API key.",
            )
        if response.status_code == status.HTTP_429_TOO_MANY_REQUESTS:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=_build_image_quota_detail(response),
            )
        if response.status_code >= 400:
            logger.warning(
                "Image API failed status=%s body=%s",
                response.status_code,
                response.text[:500],
            )
            raise HTTPException(
                status_code=response.status_code,
                detail="Image generation failed. Please try again.",
            )

        result = response.json()
        image_url = _extract_image_api_url(result)

        logger.info("Image API result image_url=%s", image_url)

        if not image_url:
            logger.warning("Image API returned no image URL: %s", result)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Image API did not return an image URL.",
            )

        return {
            "success": True,
            "imageUrl": image_url,
            "prompt": prompt,
            "seed": generation_seed,
            "model": IMAGE_API_MODEL,
            "gender": data["gender"],
            "weather": data["weather_label"],
            "style": data["style"],
            "color": data["color"],
            "bodyShape": data["body_shape"],
            "skinTone": data["skin_tone"],
            "height": data["height_text"],
            "weight": data["weight_text"],
            "width": IMAGE_WIDTH,
            "heightPx": IMAGE_HEIGHT,
            "generationMode": image_generation_mode,
            "warning": wardrobe_warning,
            "wardrobeWarning": wardrobe_warning,
            "usedSelectedWardrobeItems": bool(selected_wardrobe_items),
            "wardrobeItemsUsed": [
                _format_wardrobe_item(item) for item in selected_wardrobe_items
            ],
            "wardrobeItemsUsedDetails": [
                serialize_wardrobe_item_detail(item)
                for item in selected_wardrobe_items
            ],
        }

    except HTTPException:
        raise
    except httpx.TimeoutException:
        logger.exception("Image API generation timed out")
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="Image generation timed out.",
        )
    except httpx.RequestError as exc:
        logger.exception("Unable to reach Image API: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to reach Image API service.",
        )
    except Exception as exc:
        logger.exception("Image API generation error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to generate outfit image. Please try again.",
        )
