import base64
import re
from datetime import datetime, date
from typing import Optional, Literal

from pydantic import BaseModel, EmailStr, Field, ConfigDict, field_validator, model_validator


StyleName = Literal["sport", "casual", "chic"]
ItemType = Literal["top", "bottom", "shoe", "outwear", "accessory"]
ItemSubtype = Literal[
    "t_shirt",
    "polo",
    "shirt",
    "dress_shirt",
    "hoodie",
    "sweater",
    "tank_top",
    "shorts",
    "jeans",
    "joggers",
    "trousers",
    "sneakers",
    "running_shoes",
    "boots",
    "loafers",
    "sandals",
    "blazer",
    "coat",
    "raincoat",
    "puffer_jacket",
    "denim_jacket",
    "bag",
    "watch",
    "scarf",
    "hat",
    "belt",
]
ItemCategory = Literal["casual", "chic", "sport"]
ItemSeason = Literal["summer", "winter", "autumn", "spring"]
ItemColor = Literal[
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
]


class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=72)
    full_name: str | None = None

    @field_validator("password")
    @classmethod
    def password_max_72_bytes(cls, v: str) -> str:
        if len(v.encode("utf-8")) > 72:
            raise ValueError("Password too long (max 72 bytes for bcrypt).")
        return v


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=72)


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: EmailStr
    full_name: str | None = None
    created_at: datetime


class UserMeUpdate(BaseModel):
    full_name: str | None = None


class UserProfileBase(BaseModel):
    birth_date: Optional[date] = None
    height: Optional[float] = None
    weight: Optional[float] = None
    skin_tone: Optional[str] = None
    body_shape: Optional[str] = None
    gender: Optional[str] = None
    profile_image_url: Optional[str] = None


class UserProfileCreateUpdate(UserProfileBase):
    pass


class UserProfileOut(UserProfileBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int


class UserPreferenceBase(BaseModel):
    favorite_colors: list[str] = Field(default_factory=list)
    favorite_styles: list[StyleName] = Field(default_factory=list)

    @field_validator("favorite_colors")
    @classmethod
    def clean_colors(cls, values: list[str]) -> list[str]:
        cleaned = []
        for value in values:
            color = value.strip()
            if color:
                cleaned.append(color)
        return list(dict.fromkeys(cleaned))


class UserPreferenceCreateUpdate(UserPreferenceBase):
    pass


class UserPreferenceOut(UserPreferenceBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int


class FirebaseLoginRequest(BaseModel):
    firebase_id_token: str


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class VerifyResetCodeRequest(BaseModel):
    email: EmailStr
    code: str = Field(min_length=4, max_length=4)


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    code: str = Field(min_length=4, max_length=4)
    new_password: str = Field(min_length=6, max_length=72)

    @field_validator("new_password")
    @classmethod
    def new_password_max_72_bytes(cls, v: str) -> str:
        if len(v.encode("utf-8")) > 72:
            raise ValueError("Password too long (max 72 bytes for bcrypt).")
        return v


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=6, max_length=72)
    new_password: str = Field(min_length=6, max_length=72)

    @field_validator("new_password")
    @classmethod
    def change_password_max_72_bytes(cls, v: str) -> str:
        if len(v.encode("utf-8")) > 72:
            raise ValueError("Password too long (max 72 bytes for bcrypt).")
        return v


class MessageOut(BaseModel):
    message: str


class CitySearchOut(BaseModel):
    id: int | None = None
    name: str
    region: str | None = None
    country: str | None = None
    lat: float | None = None
    lon: float | None = None


class WeatherDataBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    city: str
    country: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    temperature: Optional[float] = None
    feels_like: Optional[float] = None
    condition: Optional[str] = None
    humidity: Optional[int] = None
    wind_kph: Optional[float] = None
    precipitation: bool = False
    precip_type: Optional[str] = None
    weather_category: Optional[str] = None


class WeatherDataCreate(WeatherDataBase):
    pass


class WeatherDataOut(WeatherDataBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int


class WardrobeItemBase(BaseModel):
    name: str
    type: ItemType
    item_subtype: Optional[ItemSubtype] = None
    category: ItemCategory
    color: Optional[ItemColor] = None
    material: Optional[str] = None
    season: Optional[ItemSeason] = None
    image_url: Optional[str] = None
    visual_description: Optional[str] = None
    ai_detected_metadata: Optional[dict] = None
    precipitation_resistant: bool = False

class WardrobeItemCreate(WardrobeItemBase):
    outfit_id: Optional[int] = None

    @model_validator(mode="after")
    def validate_subtype_matches_type(self):
        validate_item_subtype_for_type(self.type, self.item_subtype)
        return self


class WardrobeItemUpdate(BaseModel):
    name: Optional[str] = None
    type: Optional[ItemType] = None
    item_subtype: Optional[ItemSubtype] = None
    category: Optional[ItemCategory] = None
    color: Optional[ItemColor] = None
    material: Optional[str] = None
    season: Optional[ItemSeason] = None
    image_url: Optional[str] = None
    visual_description: Optional[str] = None
    ai_detected_metadata: Optional[dict] = None
    precipitation_resistant: Optional[bool] = None
    outfit_id: Optional[int] = None

    @model_validator(mode="after")
    def validate_subtype_matches_type(self):
        if self.type is not None and self.item_subtype is not None:
            validate_item_subtype_for_type(self.type, self.item_subtype)
        return self

class WardrobeItemOut(WardrobeItemBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    wardrobe_id: int
    outfit_id: Optional[int] = None
    usage_count: int
    date_added: datetime


ITEM_SUBTYPE_OPTIONS: dict[str, tuple[str, ...]] = {
    "top": ("t_shirt", "polo", "shirt", "dress_shirt", "hoodie", "sweater", "tank_top"),
    "bottom": ("shorts", "jeans", "joggers", "trousers"),
    "shoe": ("sneakers", "running_shoes", "boots", "loafers", "sandals"),
    "outwear": ("blazer", "coat", "raincoat", "puffer_jacket", "denim_jacket"),
    "accessory": ("bag", "watch", "scarf", "hat", "belt"),
}


def validate_item_subtype_for_type(
    item_type: Optional[str],
    item_subtype: Optional[str],
) -> Optional[str]:
    if item_subtype is None:
        return None

    normalized_type = item_type.strip().lower() if item_type else ""
    allowed_subtypes = ITEM_SUBTYPE_OPTIONS.get(normalized_type)
    if not allowed_subtypes:
        raise ValueError("item_subtype requires a valid item type")

    if item_subtype not in allowed_subtypes:
        allowed_text = ", ".join(allowed_subtypes)
        raise ValueError(
            f"item_subtype '{item_subtype}' is not valid for type '{normalized_type}'. "
            f"Allowed values: {allowed_text}"
        )

    return item_subtype


class WardrobeBase(BaseModel):
    name: str
    description: Optional[str] = None
    address: Optional[str] = None


class WardrobeCreate(WardrobeBase):
    pass


class WardrobeUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    address: Optional[str] = None


class WardrobeOut(WardrobeBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_profile_id: int
    created_at: datetime


class WardrobeWithItemsOut(WardrobeOut):
    items: list[WardrobeItemOut] = Field(default_factory=list)


class OutfitBase(BaseModel):
    title: str
    image_generated_url: Optional[str] = None
    is_favorite: bool = False


class OutfitCreate(OutfitBase):
    pass


class OutfitUpdate(BaseModel):
    title: Optional[str] = None
    image_generated_url: Optional[str] = None
    is_favorite: Optional[bool] = None


class OutfitOut(OutfitBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_profile_id: int
    created_at: datetime


class OutfitWithItemsOut(OutfitOut):
    items: list[WardrobeItemOut] = Field(default_factory=list)



class GenerateOutfitImageRequest(BaseModel):
    city: Optional[str] = Field(default=None, max_length=120)
    country: Optional[str] = Field(default=None, max_length=120)
    temperature: Optional[str] = Field(default=None, max_length=50)
    weather: Optional[str] = Field(default=None, max_length=120)
    precipitation: Optional[str] = Field(default=None, max_length=30)
    humidity: Optional[str] = Field(default=None, max_length=50)
    wind: Optional[str] = Field(default=None, max_length=50)
    time_of_day: Optional[str] = Field(default=None, max_length=50)
    

    style: Optional[str] = Field(default=None, max_length=80)
    color: Optional[str] = Field(default=None, max_length=80)
    gender: Optional[str] = Field(default=None, max_length=50)

    birth_date: Optional[str] = Field(default=None, max_length=40)
    height: Optional[float] = Field(default=None, ge=50, le=260)
    weight: Optional[float] = Field(default=None, ge=20, le=350)
    body_shape: Optional[str] = Field(default=None, max_length=80)
    skin_tone: Optional[str] = Field(default=None, max_length=80)

    extra_instructions: Optional[str] = Field(default=None, max_length=200)
    avatar_reference_image_url: Optional[str] = None
    model: Optional[str] = "flux"
    wardrobe_id: Optional[int] = None

    @field_validator(
        "city", "country", "temperature", "weather", "precipitation",
        "humidity", "wind", "time_of_day", "style", "color", "gender",
        "birth_date", "body_shape", "skin_tone", "extra_instructions",
        "avatar_reference_image_url", "model",
    )
    @classmethod
    def strip_strings(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        value = value.strip()
        return value or None

    @field_validator("extra_instructions")
    @classmethod
    def sanitize_extra_instructions(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        value = re.sub(r"[^a-zA-Z0-9\s,.;:!?'()\-]", "", value)
        value = re.sub(r"\s+", " ", value).strip()
        return value or None


class SaveAIOutfitHistoryRequest(BaseModel):
    image_url: str = Field(min_length=1)
    city: str = Field(min_length=1, max_length=120)
    country: Optional[str] = Field(default=None, max_length=120)
    temperature: Optional[str] = Field(default=None, max_length=50)
    weather: Optional[str] = Field(default=None, max_length=120)
    style: Optional[str] = Field(default=None, max_length=80)
    color: Optional[str] = Field(default=None, max_length=80)
    gender: Optional[str] = Field(default=None, max_length=50)
    body_shape: Optional[str] = Field(default=None, max_length=80)
    skin_tone: Optional[str] = Field(default=None, max_length=80)
    used_selected_wardrobe_items: bool = False
    wardrobe_items_used_details: list[dict] = Field(default_factory=list)

