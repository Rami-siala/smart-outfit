import logging
from urllib.parse import urlparse

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from db import get_db
from models import AIOutfitHistory, User, UserPreference, UserProfile, WardrobeItem
from schemas import GenerateOutfitImageRequest, SaveAIOutfitHistoryRequest
from security import decode_access_token
from services.ai_history_image_service import (
    delete_history_image_if_managed,
    download_history_image,
)
from services.ai_generation_service import generate_outfit_image_payload
from utils.ai_normalizers import clean_text

router = APIRouter(prefix="/ai", tags=["AI"])
bearer_scheme = HTTPBearer()
logger = logging.getLogger(__name__)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    payload = decode_access_token(credentials.credentials)
    user_id = payload.get("sub") if payload else None

    try:
        parsed_user_id = int(user_id)
    except (TypeError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    user = db.query(User).filter(User.id == parsed_user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    return user


def _serialize_outfit_history_item(item: AIOutfitHistory) -> dict:
    wardrobe_items_used_details = getattr(
        item,
        "wardrobe_items_used_details",
        None,
    )
    if not isinstance(wardrobe_items_used_details, list):
        wardrobe_items_used_details = []

    return {
        "id": str(item.id),
        "user_id": str(item.user_id),
        "imageUrl": item.image_url,
        "city": item.city or "",
        "country": item.country or "",
        "temperature": item.temperature or "",
        "weather": item.weather or "",
        "style": item.style or "",
        "color": item.color or "",
        "gender": item.gender or "",
        "bodyShape": getattr(item, "body_shape", "") or "",
        "skinTone": getattr(item, "skin_tone", "") or "",
        "usedSelectedWardrobeItems": getattr(
            item,
            "used_selected_wardrobe_items",
            False,
        )
        is True,
        "wardrobeItemsUsedDetails": wardrobe_items_used_details,
        "savedAt": item.created_at.isoformat() if item.created_at else "",
    }


@router.post("/generate-outfit-image")
async def generate_outfit_image(
    payload: GenerateOutfitImageRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = (
        db.query(UserProfile)
        .filter(UserProfile.user_id == current_user.id)
        .first()
    )

    preference = (
        db.query(UserPreference)
        .filter(UserPreference.user_id == current_user.id)
        .first()
    )

    wardrobe_items = []

    if payload.wardrobe_id is not None:
        wardrobe_items = (
            db.query(WardrobeItem)
            .join(WardrobeItem.wardrobe)
            .join(WardrobeItem.wardrobe.property.mapper.class_.user_profile)
            .filter(
                WardrobeItem.wardrobe_id == payload.wardrobe_id,
                UserProfile.user_id == current_user.id,
            )
            .all()
        )

    return await generate_outfit_image_payload(
        current_user=current_user,
        payload=payload,
        profile=profile,
        preference=preference,
        db=db,
        wardrobe_items=wardrobe_items,
    )


@router.get("/outfit-history")
def get_outfit_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    outfits = (
        db.query(AIOutfitHistory)
        .filter(AIOutfitHistory.user_id == current_user.id)
        .order_by(AIOutfitHistory.created_at.desc(), AIOutfitHistory.id.desc())
        .all()
    )

    return [_serialize_outfit_history_item(item) for item in outfits]


@router.post("/outfit-history", status_code=status.HTTP_201_CREATED)
def save_outfit_history(
    payload: SaveAIOutfitHistoryRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    saved_image_url = payload.image_url

    try:
        saved_image_url = download_history_image(
            source_url=payload.image_url,
            base_url=str(request.base_url),
        )
    except HTTPException as exc:
        parsed = urlparse(payload.image_url)
        if parsed.scheme not in {"http", "https"}:
            raise

        logger.warning(
            "Falling back to original generated image URL for history save after download failed: %s",
            exc.detail,
        )

    outfit = AIOutfitHistory(
        user_id=current_user.id,
        image_url=saved_image_url,
        city=clean_text(payload.city, ""),
        country=clean_text(payload.country, ""),
        temperature=clean_text(payload.temperature, ""),
        weather=clean_text(payload.weather, ""),
        style=clean_text(payload.style, ""),
        color=clean_text(payload.color, ""),
        gender=clean_text(payload.gender, ""),
        used_selected_wardrobe_items=payload.used_selected_wardrobe_items is True,
        wardrobe_items_used_details=[
            detail
            for detail in payload.wardrobe_items_used_details
            if isinstance(detail, dict)
        ],
    )

    if hasattr(outfit, "body_shape"):
        outfit.body_shape = clean_text(payload.body_shape, "")

    if hasattr(outfit, "skin_tone"):
        outfit.skin_tone = clean_text(payload.skin_tone, "")

    db.add(outfit)
    db.commit()
    db.refresh(outfit)

    return _serialize_outfit_history_item(outfit)


@router.delete("/outfit-history/{outfit_id}")
def delete_outfit_history_item(
    outfit_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    outfit = (
        db.query(AIOutfitHistory)
        .filter(
            AIOutfitHistory.id == outfit_id,
            AIOutfitHistory.user_id == current_user.id,
        )
        .first()
    )

    if not outfit:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Outfit not found",
        )

    managed_image_url = outfit.image_url
    db.delete(outfit)
    db.commit()

    try:
        delete_history_image_if_managed(managed_image_url)
    except OSError:
        logger.exception("Unable to delete saved AI outfit history image")

    return {"success": True}
