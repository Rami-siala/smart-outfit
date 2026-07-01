import logging
import mimetypes
import shutil
from pathlib import Path
from urllib.parse import urlparse
from uuid import uuid4

import httpx
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)

BASE_DIR = Path(__file__).resolve().parents[1]
STATIC_DIR = BASE_DIR / "static"
AI_HISTORY_DIR = STATIC_DIR / "ai_outfit_history"
AI_HISTORY_URL_PREFIX = "/static/ai_outfit_history"
DOWNLOAD_TIMEOUT_SECONDS = 60.0
MAX_IMAGE_BYTES = 15 * 1024 * 1024
CHUNK_SIZE = 1024 * 1024

_CONTENT_TYPE_EXTENSIONS = {
    "image/jpeg": ".jpg",
    "image/jpg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}


def ensure_ai_history_storage() -> None:
    AI_HISTORY_DIR.mkdir(parents=True, exist_ok=True)


def build_saved_history_image_url(image_name: str, base_url: str) -> str:
    normalized_base_url = base_url.rstrip("/")
    return f"{normalized_base_url}{AI_HISTORY_URL_PREFIX}/{image_name}"


# ✅ NEW — Resolve any /static/... URL to a local file path
def _resolve_local_static_path(source_url: str) -> Path | None:
    """
    If the URL points to a local /static/... file, return the local Path.
    Returns None if not a local static file.
    """
    parsed = urlparse(source_url)
    image_path = parsed.path or source_url

    if not image_path.startswith("/static/"):
        return None

    relative_path = image_path.removeprefix("/static/").strip("/")
    if not relative_path:
        return None

    candidate = (STATIC_DIR / relative_path).resolve()

    # Security: make sure it's inside STATIC_DIR
    try:
        candidate.relative_to(STATIC_DIR.resolve())
    except ValueError:
        return None

    if not candidate.exists() or not candidate.is_file():
        return None

    return candidate


# ✅ NEW — Copy a local file to the history folder
def _copy_local_to_history(local_path: Path, base_url: str) -> str:
    ensure_ai_history_storage()

    extension = local_path.suffix.lower() or ".jpg"
    if extension == ".jpeg":
        extension = ".jpg"
    if extension not in {".jpg", ".png", ".webp"}:
        extension = ".jpg"

    file_name = f"{uuid4().hex}{extension}"
    destination = AI_HISTORY_DIR / file_name

    try:
        shutil.copy2(local_path, destination)
        logger.info("✅ Copied local image to history: %s", destination.name)
    except OSError as exc:
        logger.exception("Unable to copy local image to history: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to store generated outfit image.",
        )

    return build_saved_history_image_url(file_name, base_url)


def download_history_image(source_url: str, base_url: str) -> str:
    # ✅ NEW — Check if it's a local file first
    local_path = _resolve_local_static_path(source_url)
    if local_path is not None:
        logger.info("📁 Source is local file, copying directly: %s", local_path.name)
        return _copy_local_to_history(local_path, base_url)

    # Otherwise, download via HTTP as before
    parsed = urlparse(source_url)
    if parsed.scheme not in {"http", "https"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid generated image URL.",
        )

    ensure_ai_history_storage()

    try:
        with httpx.Client(
            follow_redirects=True,
            timeout=DOWNLOAD_TIMEOUT_SECONDS,
        ) as client:
            with client.stream("GET", source_url) as response:
                if response.status_code >= 400:
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail="Unable to download generated outfit image.",
                    )

                extension = _resolve_extension(
                    source_url=source_url,
                    content_type=response.headers.get("content-type"),
                )
                file_name = f"{uuid4().hex}{extension}"
                destination = AI_HISTORY_DIR / file_name

                total_bytes = 0
                with destination.open("wb") as output:
                    for chunk in response.iter_bytes(CHUNK_SIZE):
                        if not chunk:
                            continue
                        total_bytes += len(chunk)
                        if total_bytes > MAX_IMAGE_BYTES:
                            output.close()
                            destination.unlink(missing_ok=True)
                            raise HTTPException(
                                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                                detail="Generated outfit image is too large to save.",
                            )
                        output.write(chunk)

                if total_bytes == 0:
                    destination.unlink(missing_ok=True)
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail="Generated outfit image download was empty.",
                    )

        return build_saved_history_image_url(file_name, base_url)
    except HTTPException:
        raise
    except httpx.TimeoutException:
        logger.exception("Timed out while downloading generated outfit image")
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="Timed out while saving generated outfit image.",
        )
    except httpx.RequestError:
        logger.exception("Unable to download generated outfit image")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to download generated outfit image.",
        )
    except OSError:
        logger.exception("Unable to write generated outfit image to local storage")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to store generated outfit image.",
        )


def delete_history_image_if_managed(image_url: str) -> None:
    if not image_url:
        return

    parsed = urlparse(image_url)
    image_path = parsed.path or ""

    if not image_path.startswith(f"{AI_HISTORY_URL_PREFIX}/"):
        return

    file_name = Path(image_path).name
    if not file_name:
        return

    ensure_ai_history_storage()
    destination = (AI_HISTORY_DIR / file_name).resolve()
    history_dir = AI_HISTORY_DIR.resolve()

    if history_dir not in destination.parents:
        logger.warning("Refusing to delete image outside managed history directory: %s", image_url)
        return

    destination.unlink(missing_ok=True)


def _resolve_extension(source_url: str, content_type: str | None) -> str:
    if content_type:
        normalized_content_type = content_type.split(";", 1)[0].strip().lower()
        if normalized_content_type in _CONTENT_TYPE_EXTENSIONS:
            return _CONTENT_TYPE_EXTENSIONS[normalized_content_type]

    guessed_from_path = Path(urlparse(source_url).path).suffix.lower()
    if guessed_from_path in {".jpg", ".jpeg", ".png", ".webp"}:
        return ".jpg" if guessed_from_path == ".jpeg" else guessed_from_path

    guessed_type, _ = mimetypes.guess_type(source_url)
    if guessed_type in _CONTENT_TYPE_EXTENSIONS:
        return _CONTENT_TYPE_EXTENSIONS[guessed_type]

    return ".jpg"