import logging

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import ValidationError
from sqlalchemy.orm import Session

from db import get_db
from models import UserProfile, Wardrobe, WardrobeItem, Outfit
from schemas import (
    WardrobeCreate,
    WardrobeUpdate,
    WardrobeOut,
    WardrobeWithItemsOut,
    WardrobeItemCreate,
    WardrobeItemUpdate,
    WardrobeItemOut,
    OutfitCreate,
    OutfitUpdate,
    OutfitOut,
    OutfitWithItemsOut,
    MessageOut,
    validate_item_subtype_for_type,
)
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from security import decode_access_token
from models import User
from fastapi import status
from services.wardrobe_item_image_service import (
    delete_wardrobe_item_image_if_managed,
    resolve_managed_wardrobe_item_image_path,
    save_uploaded_wardrobe_item_image,
)


bearer_scheme = HTTPBearer()
logger = logging.getLogger(__name__)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    token = credentials.credentials
    payload = decode_access_token(token)

    user_id = payload.get("sub")

    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    user = db.query(User).filter(User.id == int(user_id)).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    return user


router = APIRouter(prefix="/wardrobe", tags=["Wardrobe"])


def _normalize_form_enum_value(value: str | None) -> str | None:
    if value is None:
        return None
    normalized = value.strip().lower().replace(" ", "_").replace("-", "_")
    return normalized or None


def get_my_profile(db: Session, current_user):
    profile = db.query(UserProfile).filter(
        UserProfile.user_id == current_user.id
    ).first()

    if not profile:
        raise HTTPException(status_code=404, detail="User profile not found")

    return profile


# -------------------------
# Wardrobes
# -------------------------

@router.post("/", response_model=WardrobeOut)
def create_wardrobe(
    data: WardrobeCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    profile = get_my_profile(db, current_user)

    wardrobe = Wardrobe(
        user_profile_id=profile.id,
        name=data.name,
        description=data.description,
        address=data.address,
    )

    db.add(wardrobe)
    db.commit()
    db.refresh(wardrobe)

    return wardrobe


@router.get("/", response_model=list[WardrobeOut])
def get_my_wardrobes(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    profile = get_my_profile(db, current_user)

    return db.query(Wardrobe).filter(
        Wardrobe.user_profile_id == profile.id
    ).all()


@router.get("/{wardrobe_id}", response_model=WardrobeWithItemsOut)
def get_wardrobe(
    wardrobe_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    profile = get_my_profile(db, current_user)

    wardrobe = db.query(Wardrobe).filter(
        Wardrobe.id == wardrobe_id,
        Wardrobe.user_profile_id == profile.id,
    ).first()

    if not wardrobe:
        raise HTTPException(status_code=404, detail="Wardrobe not found")

    return wardrobe


@router.put("/{wardrobe_id}", response_model=WardrobeOut)
def update_wardrobe(
    wardrobe_id: int,
    data: WardrobeUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    profile = get_my_profile(db, current_user)

    wardrobe = db.query(Wardrobe).filter(
        Wardrobe.id == wardrobe_id,
        Wardrobe.user_profile_id == profile.id,
    ).first()

    if not wardrobe:
        raise HTTPException(status_code=404, detail="Wardrobe not found")

    update_data = data.model_dump(exclude_unset=True)

    for key, value in update_data.items():
        setattr(wardrobe, key, value)

    db.commit()
    db.refresh(wardrobe)

    return wardrobe


@router.delete("/{wardrobe_id}", response_model=MessageOut)
def delete_wardrobe(
    wardrobe_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    profile = get_my_profile(db, current_user)

    wardrobe = db.query(Wardrobe).filter(
        Wardrobe.id == wardrobe_id,
        Wardrobe.user_profile_id == profile.id,
    ).first()

    if not wardrobe:
        raise HTTPException(status_code=404, detail="Wardrobe not found")

    db.delete(wardrobe)
    db.commit()

    return {"message": "Wardrobe deleted successfully"}


# -------------------------
# Outfits
# -------------------------

@router.post("/outfits", response_model=OutfitOut)
def create_outfit(
    data: OutfitCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    profile = get_my_profile(db, current_user)

    outfit = Outfit(
        user_profile_id=profile.id,
        title=data.title,
        image_generated_url=data.image_generated_url,
        is_favorite=data.is_favorite,
    )

    db.add(outfit)
    db.commit()
    db.refresh(outfit)

    return outfit


@router.get("/outfits/all", response_model=list[OutfitOut])
def get_my_outfits(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    profile = get_my_profile(db, current_user)

    return db.query(Outfit).filter(
        Outfit.user_profile_id == profile.id
    ).all()


@router.get("/outfits/{outfit_id}", response_model=OutfitWithItemsOut)
def get_outfit(
    outfit_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    profile = get_my_profile(db, current_user)

    outfit = db.query(Outfit).filter(
        Outfit.id == outfit_id,
        Outfit.user_profile_id == profile.id,
    ).first()

    if not outfit:
        raise HTTPException(status_code=404, detail="Outfit not found")

    return outfit


@router.put("/outfits/{outfit_id}", response_model=OutfitOut)
def update_outfit(
    outfit_id: int,
    data: OutfitUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    profile = get_my_profile(db, current_user)

    outfit = db.query(Outfit).filter(
        Outfit.id == outfit_id,
        Outfit.user_profile_id == profile.id,
    ).first()

    if not outfit:
        raise HTTPException(status_code=404, detail="Outfit not found")

    update_data = data.model_dump(exclude_unset=True)

    for key, value in update_data.items():
        setattr(outfit, key, value)

    db.commit()
    db.refresh(outfit)

    return outfit


@router.delete("/outfits/{outfit_id}", response_model=MessageOut)
def delete_outfit(
    outfit_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    profile = get_my_profile(db, current_user)

    outfit = db.query(Outfit).filter(
        Outfit.id == outfit_id,
        Outfit.user_profile_id == profile.id,
    ).first()

    if not outfit:
        raise HTTPException(status_code=404, detail="Outfit not found")

    db.delete(outfit)
    db.commit()

    return {"message": "Outfit deleted successfully"}


# -------------------------
# Wardrobe items
# -------------------------

@router.post("/{wardrobe_id}/items", response_model=WardrobeItemOut)
async def create_wardrobe_item(
    wardrobe_id: int,
    name: str = Form(...),
    type: str = Form(...),
    item_subtype: str | None = Form(None),
    category: str = Form(...),
    color: str | None = Form(None),
    material: str | None = Form(None),
    season: str | None = Form(None),
    image_url: str | None = Form(None),
    precipitation_resistant: bool = Form(False),
    outfit_id: int | None = Form(None),
    image: UploadFile | None = File(None),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    profile = get_my_profile(db, current_user)
    logger.info(
        "Create wardrobe item request wardrobe_id=%s user_id=%s name=%s type=%s category=%s image_url=%s has_upload=%s",
        wardrobe_id,
        current_user.id,
        name,
        type,
        category,
        image_url,
        image is not None,
    )

    wardrobe = db.query(Wardrobe).filter(
        Wardrobe.id == wardrobe_id,
        Wardrobe.user_profile_id == profile.id,
    ).first()

    if not wardrobe:
        raise HTTPException(status_code=404, detail="Wardrobe not found")

    outfit = None

    try:
        data = WardrobeItemCreate(
            name=name,
            type=_normalize_form_enum_value(type),
            item_subtype=_normalize_form_enum_value(item_subtype),
            category=_normalize_form_enum_value(category),
            color=_normalize_form_enum_value(color),
            material=material,
            season=_normalize_form_enum_value(season),
            image_url=image_url,
            precipitation_resistant=precipitation_resistant,
            outfit_id=outfit_id,
        )
    except ValidationError as exc:
        raise HTTPException(status_code=422, detail=exc.errors()) from exc

    if data.outfit_id is not None:
        outfit = db.query(Outfit).filter(
            Outfit.id == data.outfit_id,
            Outfit.user_profile_id == profile.id,
        ).first()

        if not outfit:
            raise HTTPException(status_code=404, detail="Outfit not found")

    saved_image_url = data.image_url
    if image is not None:
        saved_image_url = await save_uploaded_wardrobe_item_image(image)
    logger.info(
        "Create wardrobe item image processed wardrobe_id=%s name=%s saved_image_url=%s",
        wardrobe_id,
        name,
        saved_image_url,
    )

    item = WardrobeItem(
        wardrobe_id=wardrobe.id,
        outfit_id=outfit.id if outfit is not None else None,
        name=data.name,
        type=data.type,
        item_subtype=data.item_subtype,
        category=data.category,
        color=data.color,
        material=data.material,
        season=data.season,
        image_url=saved_image_url,
        precipitation_resistant=data.precipitation_resistant,
        usage_count=1 if outfit is not None else 0,
    )

    db.add(item)
    db.commit()
    db.refresh(item)
    logger.info(
        "Wardrobe item updated item_id=%s image_url=%s visual_description_present=%s",
        item.id,
        item.image_url,
        bool(item.visual_description),
    )
    logger.info(
        "Wardrobe item created item_id=%s wardrobe_id=%s image_url=%s",
        item.id,
        wardrobe_id,
        item.image_url,
    )

    if resolve_managed_wardrobe_item_image_path(item.image_url) is None:
        logger.warning(
            "Wardrobe item created without managed preview image item_id=%s image_url=%s",
            item.id,
            item.image_url,
        )

    return item


@router.get("/{wardrobe_id}/items", response_model=list[WardrobeItemOut])
def get_wardrobe_items(
    wardrobe_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    profile = get_my_profile(db, current_user)

    wardrobe = db.query(Wardrobe).filter(
        Wardrobe.id == wardrobe_id,
        Wardrobe.user_profile_id == profile.id,
    ).first()

    if not wardrobe:
        raise HTTPException(status_code=404, detail="Wardrobe not found")

    return db.query(WardrobeItem).filter(
        WardrobeItem.wardrobe_id == wardrobe.id
    ).all()


@router.put("/items/{item_id}", response_model=WardrobeItemOut)
async def update_wardrobe_item(
    item_id: int,
    name: str | None = Form(None),
    type: str | None = Form(None),
    item_subtype: str | None = Form(None),
    category: str | None = Form(None),
    color: str | None = Form(None),
    material: str | None = Form(None),
    season: str | None = Form(None),
    image_url: str | None = Form(None),
    precipitation_resistant: bool | None = Form(None),
    outfit_id: int | None = Form(None),
    remove_image: bool = Form(False),
    image: UploadFile | None = File(None),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    profile = get_my_profile(db, current_user)

    item = db.query(WardrobeItem).join(Wardrobe).filter(
        WardrobeItem.id == item_id,
        Wardrobe.user_profile_id == profile.id,
    ).first()

    if not item:
        raise HTTPException(status_code=404, detail="Wardrobe item not found")

    try:
        data = WardrobeItemUpdate(
            name=name,
            type=_normalize_form_enum_value(type),
            item_subtype=_normalize_form_enum_value(item_subtype),
            category=_normalize_form_enum_value(category),
            color=_normalize_form_enum_value(color),
            material=material,
            season=_normalize_form_enum_value(season),
            image_url=image_url,
            precipitation_resistant=precipitation_resistant,
            outfit_id=outfit_id,
        )
    except ValidationError as exc:
        raise HTTPException(status_code=422, detail=exc.errors()) from exc
    update_data = data.model_dump(exclude_unset=True)
    previous_outfit_id = item.outfit_id

    effective_type = update_data.get("type") or getattr(item, "type", None)
    effective_subtype = update_data.get("item_subtype")
    if "item_subtype" in update_data or "type" in update_data:
        try:
            validate_item_subtype_for_type(
                getattr(effective_type, "value", effective_type),
                effective_subtype,
            )
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc

    if "outfit_id" in update_data:
        if update_data["outfit_id"] is not None:
            outfit = db.query(Outfit).filter(
                Outfit.id == update_data["outfit_id"],
                Outfit.user_profile_id == profile.id,
            ).first()

            if not outfit:
                raise HTTPException(status_code=404, detail="Outfit not found")

    for key, value in update_data.items():
        setattr(item, key, value)

    if remove_image:
        delete_wardrobe_item_image_if_managed(item.image_url)
        item.image_url = None
        item.visual_description = None
        item.ai_detected_metadata = None
    elif image is not None:
        item.image_url = await save_uploaded_wardrobe_item_image(
            image,
            existing_image_url=item.image_url,
        )
        item.visual_description = None
        item.ai_detected_metadata = None

    if previous_outfit_id is None and item.outfit_id is not None:
        item.usage_count = (item.usage_count or 0) + 1

    db.commit()
    db.refresh(item)

    if not remove_image and resolve_managed_wardrobe_item_image_path(item.image_url) is None:
        logger.warning(
            "Wardrobe item update ended without managed preview image item_id=%s image_url=%s",
            item.id,
            item.image_url,
        )

    return item


@router.delete("/items/{item_id}", response_model=MessageOut)
def delete_wardrobe_item(
    item_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    profile = get_my_profile(db, current_user)

    item = db.query(WardrobeItem).join(Wardrobe).filter(
        WardrobeItem.id == item_id,
        Wardrobe.user_profile_id == profile.id,
    ).first()

    if not item:
        raise HTTPException(status_code=404, detail="Wardrobe item not found")
    logger.info(
        "Delete wardrobe item request item_id=%s user_id=%s image_url=%s",
        item.id,
        current_user.id,
        item.image_url,
    )

    managed_image_url = item.image_url
    try:
        db.delete(item)
        db.commit()
        logger.info(
            "Wardrobe item deleted from database item_id=%s managed_image_url=%s",
            item_id,
            managed_image_url,
        )
    except Exception:
        db.rollback()
        logger.exception(
            "Failed to delete wardrobe item from database item_id=%s image_url=%s",
            item_id,
            managed_image_url,
        )
        raise HTTPException(
            status_code=500,
            detail="Failed to delete wardrobe item",
        )

    try:
        delete_wardrobe_item_image_if_managed(managed_image_url)
    except OSError:
        logger.exception(
            "Wardrobe item deleted but managed image cleanup failed item_id=%s image_url=%s",
            item_id,
            managed_image_url,
        )

    return {"message": "Wardrobe item deleted successfully"}
