import base64
import json
import logging
import mimetypes
import os
from pathlib import Path
from typing import Any, Optional
from urllib.parse import urlparse
from uuid import uuid4

import httpx
from dotenv import load_dotenv
from fastapi import HTTPException, UploadFile, status

logger = logging.getLogger(__name__)

BASE_DIR = Path(__file__).resolve().parents[1]
STATIC_DIR = BASE_DIR / "static"
WARDROBE_ITEMS_DIR = STATIC_DIR / "wardrobe_items"
WARDROBE_ITEMS_URL_PREFIX = "/static/wardrobe_items"
MAX_IMAGE_BYTES = 15 * 1024 * 1024
CHUNK_SIZE = 1024 * 1024
VISION_TIMEOUT_SECONDS = 90.0

env_path = BASE_DIR / ".env"
load_dotenv(dotenv_path=env_path)

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_BASE_URL = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1")
OPENAI_VISION_MODEL = os.getenv("OPENAI_VISION_MODEL", "gpt-4.1-mini")

_CONTENT_TYPE_EXTENSIONS = {
    "image/jpeg": ".jpg",
    "image/jpg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}
_SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
_NORMALIZED_TYPES = {"top", "bottom", "shoe", "outwear", "accessory"}
_NORMALIZED_CATEGORIES = {"casual", "sport", "chic"}
_NORMALIZED_COLORS = {
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
}
_NORMALIZED_SEASONS = {"summer", "winter", "spring", "autumn"}


def ensure_wardrobe_item_storage() -> None:
    WARDROBE_ITEMS_DIR.mkdir(parents=True, exist_ok=True)
    logger.debug("Wardrobe item storage ensured at %s", WARDROBE_ITEMS_DIR)


def build_wardrobe_item_image_url(file_name: str) -> str:
    return f"{WARDROBE_ITEMS_URL_PREFIX}/{file_name}"


async def save_uploaded_wardrobe_item_image(
    image: UploadFile,
    *,
    existing_image_url: Optional[str] = None,
) -> str:
    ensure_wardrobe_item_storage()
    logger.info(
        "Wardrobe image upload started filename=%s content_type=%s existing_image_url=%s",
        image.filename,
        image.content_type,
        existing_image_url,
    )

    extension = _resolve_upload_extension(image)
    file_name = f"item_{uuid4().hex}{extension}"
    destination = WARDROBE_ITEMS_DIR / file_name
    total_bytes = 0
    logger.info(
        "Wardrobe image upload resolved destination file_name=%s destination=%s",
        file_name,
        destination,
    )

    try:
        with destination.open("wb") as output:
            while True:
                chunk = await image.read(CHUNK_SIZE)
                if not chunk:
                    break
                total_bytes += len(chunk)
                if total_bytes > MAX_IMAGE_BYTES:
                    output.close()
                    destination.unlink(missing_ok=True)
                    logger.warning(
                        "Wardrobe image upload exceeded max size filename=%s total_bytes=%s max_bytes=%s",
                        image.filename,
                        total_bytes,
                        MAX_IMAGE_BYTES,
                    )
                    raise HTTPException(
                        status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                        detail="Wardrobe item image is too large.",
                    )
                output.write(chunk)

        if total_bytes == 0:
            destination.unlink(missing_ok=True)
            logger.warning(
                "Wardrobe image upload was empty filename=%s destination=%s",
                image.filename,
                destination,
            )
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Wardrobe item image upload was empty.",
            )

        if existing_image_url:
            logger.info(
                "Wardrobe image upload replacing previous managed image existing_image_url=%s",
                existing_image_url,
            )
            delete_wardrobe_item_image_if_managed(existing_image_url)

        saved_url = build_wardrobe_item_image_url(file_name)
        logger.info(
            "Wardrobe image upload succeeded filename=%s saved_url=%s bytes=%s file_exists=%s",
            image.filename,
            saved_url,
            total_bytes,
            destination.exists(),
        )
        return saved_url
    except HTTPException:
        logger.exception(
            "Wardrobe image upload failed with HTTPException filename=%s destination=%s",
            image.filename,
            destination,
        )
        raise
    except OSError:
        logger.exception("Unable to store wardrobe item image")
        destination.unlink(missing_ok=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to store wardrobe item image.",
        )
    finally:
        await image.close()


def delete_wardrobe_item_image_if_managed(image_url: Optional[str]) -> None:
    managed_path = resolve_managed_wardrobe_item_image_path(image_url)
    if managed_path is None:
        logger.info(
            "Wardrobe image delete skipped because path is not a managed local image image_url=%s",
            image_url,
        )
        return
    logger.info("Deleting managed wardrobe image image_url=%s path=%s", image_url, managed_path)
    managed_path.unlink(missing_ok=True)


def resolve_managed_wardrobe_item_image_path(image_url: Optional[str]) -> Optional[Path]:
    if not image_url:
        logger.info("Wardrobe image path resolution skipped because image_url is empty")
        return None

    parsed = urlparse(image_url)
    image_path = parsed.path or image_url
    logger.info(
        "Resolving wardrobe image path image_url=%s parsed_path=%s is_local_backend_path=%s",
        image_url,
        image_path,
        image_path.startswith(f"{WARDROBE_ITEMS_URL_PREFIX}/"),
    )

    if not image_path.startswith(f"{WARDROBE_ITEMS_URL_PREFIX}/"):
        logger.warning(
            "Wardrobe image path is not a managed backend static path image_url=%s parsed_path=%s",
            image_url,
            image_path,
        )
        return None

    file_name = Path(image_path).name
    if not file_name:
        return None

    ensure_wardrobe_item_storage()
    destination = (WARDROBE_ITEMS_DIR / file_name).resolve()
    managed_root = WARDROBE_ITEMS_DIR.resolve()

    if managed_root not in destination.parents:
        logger.warning(
            "Refusing to access wardrobe image outside managed directory: %s",
            image_url,
        )
        return None

    if not destination.exists():
        logger.warning(
            "Managed wardrobe image file is missing image_url=%s resolved_path=%s",
            image_url,
            destination,
        )
        return None

    logger.info(
        "Managed wardrobe image path resolved successfully image_url=%s resolved_path=%s exists=%s",
        image_url,
        destination,
        destination.exists(),
    )
    return destination


async def analyze_wardrobe_item_if_needed(item, db, *, force: bool = False) -> bool:
    item_label = _describe_item(item)
    image_url = getattr(item, "image_url", None)
    logger.info(
        "Wardrobe vision analysis check started item=%s force=%s image_url=%s has_visual_description=%s",
        item_label,
        force,
        image_url,
        bool(getattr(item, "visual_description", None)),
    )
    image_path = resolve_managed_wardrobe_item_image_path(image_url)
    if image_path is None:
        logger.warning(
            "Wardrobe vision analysis skipped because managed image path could not be resolved item=%s image_url=%s",
            item_label,
            image_url,
        )
        return False

    if not force and getattr(item, "visual_description", None):
        logger.info(
            "Wardrobe vision analysis skipped because item already has visual_description item=%s",
            item_label,
        )
        return True

    analysis = await analyze_wardrobe_item_image(image_path, item_label=item_label)
    if analysis is None:
        logger.warning(
            "Wardrobe vision analysis returned no result item=%s image_path=%s",
            item_label,
            image_path,
        )
        return False

    item.visual_description = analysis["visual_description"]
    item.ai_detected_metadata = analysis["ai_detected_metadata"]
    logger.info(
        "Wardrobe vision analysis produced visual description item=%s description_length=%s metadata_keys=%s",
        item_label,
        len(item.visual_description or ""),
        sorted((item.ai_detected_metadata or {}).keys()),
    )
    db.add(item)
    try:
        db.commit()
        db.refresh(item)
        logger.info(
            "Wardrobe vision analysis saved to database item=%s item_id=%s",
            item_label,
            getattr(item, "id", None),
        )
        return True
    except Exception:
        logger.exception(
            "Wardrobe vision analysis failed to save to database item=%s item_id=%s",
            item_label,
            getattr(item, "id", None),
        )
        db.rollback()
        return False


async def analyze_wardrobe_item_image(
    image_path: Path,
    *,
    item_label: str = "unknown-item",
) -> Optional[dict[str, Any]]:
    logger.info(
        "Wardrobe vision image analysis starting item=%s image_path=%s exists=%s",
        item_label,
        image_path,
        image_path.exists(),
    )
    if not OPENAI_API_KEY:
        logger.warning(
            "OPENAI_API_KEY is not set; skipping wardrobe item vision analysis item=%s",
            item_label,
        )
        return None

    logger.info(
        "OPENAI vision configuration item=%s api_key_present=%s api_key_prefix=%s model=%s base_url=%s",
        item_label,
        bool(OPENAI_API_KEY),
        OPENAI_API_KEY[:7] if OPENAI_API_KEY else "",
        OPENAI_VISION_MODEL,
        OPENAI_BASE_URL,
    )

    if not image_path.exists():
        logger.warning(
            "Wardrobe image file missing before vision request item=%s image_path=%s",
            item_label,
            image_path,
        )
        return None

    try:
        data_url = _build_data_url(image_path)
        logger.info(
            "Wardrobe image converted to data URL for vision request item=%s mime=%s bytes=%s",
            item_label,
            mimetypes.guess_type(str(image_path))[0] or "image/jpeg",
            image_path.stat().st_size if image_path.exists() else -1,
        )
    except OSError:
        logger.exception(
            "Unable to read wardrobe item image for analysis item=%s image_path=%s",
            item_label,
            image_path,
        )
        return None

    prompt = (
        "Analyze this single wardrobe item photo and return structured JSON only. "
        "Describe the exact visible garment or shoe from the photo, not a generic category. "
        "Focus on shape, cut, silhouette, visible color or pattern, material or texture, and "
        "distinctive details like hoodie, blazer, collar, zipper, buttons, straps, sole, heel, or logo. "
        "Infer type, style category, season, and rain readiness only when reasonably supported by the image."
    )

    schema = {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "visual_description": {"type": "string"},
            "item_shape_cut": {"type": "string"},
            "visible_color_pattern": {"type": "string"},
            "material_texture": {"type": "string"},
            "distinctive_details": {
                "type": "array",
                "items": {"type": "string"},
            },
            "detected_type": {
                "type": ["string", "null"],
                "enum": ["top", "bottom", "shoe", "outwear", "accessory", None],
            },
            "detected_category": {
                "type": ["string", "null"],
                "enum": ["casual", "sport", "chic", None],
            },
            "detected_color": {
                "type": ["string", "null"],
                "enum": [
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
                    None,
                ],
            },
            "detected_season": {
                "type": ["string", "null"],
                "enum": ["summer", "winter", "spring", "autumn", None],
            },
            "rain_ready": {"type": ["boolean", "null"]},
        },
        "required": [
            "visual_description",
            "item_shape_cut",
            "visible_color_pattern",
            "material_texture",
            "distinctive_details",
            "detected_type",
            "detected_category",
            "detected_color",
            "detected_season",
            "rain_ready",
        ],
    }

    body = {
        "model": OPENAI_VISION_MODEL,
        "input": [
            {
                "role": "user",
                "content": [
                    {"type": "input_text", "text": prompt},
                    {
                        "type": "input_image",
                        "image_url": data_url,
                        "detail": "high",
                    },
                ],
            }
        ],
        "text": {
            "format": {
                "type": "json_schema",
                "name": "wardrobe_item_analysis",
                "schema": schema,
                "strict": True,
            }
        },
    }

    headers = {
        "Authorization": f"Bearer {OPENAI_API_KEY}",
        "Content-Type": "application/json",
    }

    try:
        logger.info(
            "Sending OpenAI vision request item=%s model=%s endpoint=%s",
            item_label,
            OPENAI_VISION_MODEL,
            f"{OPENAI_BASE_URL.rstrip('/')}/responses",
        )
        async with httpx.AsyncClient(timeout=VISION_TIMEOUT_SECONDS) as client:
            response = await client.post(
                f"{OPENAI_BASE_URL.rstrip('/')}/responses",
                json=body,
                headers=headers,
            )

        if response.status_code >= 400:
            logger.warning(
                "Wardrobe item vision request failed item=%s status=%s body=%s",
                item_label,
                response.status_code,
                response.text[:500],
            )
            return None

        result = response.json()
        logger.info(
            "Wardrobe item vision response received item=%s status=%s output_text_present=%s result_keys=%s",
            item_label,
            response.status_code,
            bool(result.get("output_text")),
            sorted(result.keys()),
        )
        output_text = result.get("output_text")
        if not output_text:
            logger.warning(
                "Wardrobe item vision response missing output_text item=%s response=%s",
                item_label,
                str(result)[:700],
            )
            return None

        parsed = json.loads(output_text)
        normalized_metadata = _normalize_detected_metadata(parsed)
        visual_description = str(parsed.get("visual_description") or "").strip()

        if not visual_description:
            logger.warning(
                "Wardrobe item vision returned empty visual_description item=%s parsed=%s",
                item_label,
                str(parsed)[:700],
            )
            return None

        logger.info(
            "Wardrobe item vision produced visual_description item=%s description_preview=%s metadata=%s",
            item_label,
            visual_description[:220],
            normalized_metadata,
        )
        return {
            "visual_description": visual_description,
            "ai_detected_metadata": normalized_metadata,
        }
    except json.JSONDecodeError:
        logger.exception(
            "Unable to parse wardrobe item vision response item=%s",
            item_label,
        )
        return None
    except httpx.TimeoutException:
        logger.exception(
            "Wardrobe item vision analysis timed out item=%s",
            item_label,
        )
        return None
    except httpx.RequestError:
        logger.exception(
            "Unable to reach vision analysis API item=%s",
            item_label,
        )
        return None


def _normalize_detected_metadata(payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "item_shape_cut": _clean_text(payload.get("item_shape_cut")),
        "visible_color_pattern": _clean_text(payload.get("visible_color_pattern")),
        "material_texture": _clean_text(payload.get("material_texture")),
        "distinctive_details": _clean_string_list(payload.get("distinctive_details")),
        "detected_type": _normalize_choice(payload.get("detected_type"), _NORMALIZED_TYPES),
        "detected_category": _normalize_choice(
            payload.get("detected_category"),
            _NORMALIZED_CATEGORIES,
        ),
        "detected_color": _normalize_choice(payload.get("detected_color"), _NORMALIZED_COLORS),
        "detected_season": _normalize_choice(payload.get("detected_season"), _NORMALIZED_SEASONS),
        "rain_ready": _optional_bool(payload.get("rain_ready")),
    }


def _build_data_url(image_path: Path) -> str:
    raw = image_path.read_bytes()
    if not raw:
        raise OSError("Image file is empty")

    mime_type = mimetypes.guess_type(str(image_path))[0] or "image/jpeg"
    encoded = base64.b64encode(raw).decode("ascii")
    return f"data:{mime_type};base64,{encoded}"


def _resolve_upload_extension(image: UploadFile) -> str:
    content_type = (image.content_type or "").split(";", 1)[0].strip().lower()
    if content_type in _CONTENT_TYPE_EXTENSIONS:
        return _CONTENT_TYPE_EXTENSIONS[content_type]

    filename = image.filename or ""
    suffix = Path(filename).suffix.lower()
    if suffix in _SUPPORTED_EXTENSIONS:
        return ".jpg" if suffix == ".jpeg" else suffix

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Unsupported wardrobe item image format. Use JPG, PNG, or WEBP.",
    )


def _clean_text(value: Any) -> str:
    return str(value or "").strip()


def _clean_string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    cleaned: list[str] = []
    for item in value:
        normalized = _clean_text(item)
        if normalized:
            cleaned.append(normalized)
    return cleaned


def _normalize_choice(value: Any, allowed: set[str]) -> Optional[str]:
    normalized = _clean_text(value).lower()
    if not normalized:
        return None
    return normalized if normalized in allowed else None


def _optional_bool(value: Any) -> Optional[bool]:
    if value is None:
        return None
    if isinstance(value, bool):
        return value
    normalized = _clean_text(value).lower()
    if normalized in {"true", "1", "yes"}:
        return True
    if normalized in {"false", "0", "no"}:
        return False
    return None


def _describe_item(item) -> str:
    item_id = getattr(item, "id", None)
    name = getattr(item, "name", None)
    item_type = getattr(getattr(item, "type", None), "value", getattr(item, "type", None))
    return f"id={item_id} name={name!r} type={item_type!r}"
