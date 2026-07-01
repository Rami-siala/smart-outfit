from sqlalchemy import Column, BigInteger, String, Integer, DateTime, Date, Float, ForeignKey, Boolean, JSON, Enum, Text
from sqlalchemy.sql import func, text
from sqlalchemy.orm import relationship
from db import Base
import enum
from security import is_social_login_hash
from sqlalchemy import Text


class User(Base):
    __tablename__ = "users"

    id = Column(BigInteger, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    full_name = Column(String(120), nullable=True)

    created_at = Column(DateTime, nullable=False, server_default=func.now())
    updated_at = Column(DateTime, nullable=False, server_default=func.now(), onupdate=func.now())

    profile = relationship("UserProfile", back_populates="user", uselist=False, cascade="all, delete-orphan")
    preference = relationship("UserPreference", back_populates="user", uselist=False, cascade="all, delete-orphan")
    reset_codes = relationship("PasswordResetCode", back_populates="user", cascade="all, delete-orphan")
    weather_data = relationship("WeatherData", back_populates="user", uselist=False, cascade="all, delete-orphan")
    ai_outfit_history = relationship("AIOutfitHistory", back_populates="user", cascade="all, delete-orphan")

    @property
    def is_social_login(self) -> bool:
        return is_social_login_hash(self.password_hash)


class UserProfile(Base):
    __tablename__ = "user_profiles"

    id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)

    birth_date = Column(Date, nullable=True)
    height = Column(Float, nullable=True)
    weight = Column(Float, nullable=True)
    skin_tone = Column(String, nullable=True)
    body_shape = Column(String, nullable=True)
    profile_image_url = Column(String, nullable=True)
    gender = Column(String, nullable=True)

    user = relationship("User", back_populates="profile")
    wardrobes = relationship("Wardrobe", back_populates="user_profile", cascade="all, delete-orphan")
    outfits = relationship("Outfit", back_populates="user_profile", cascade="all, delete-orphan")


class Wardrobe(Base):
    __tablename__ = "wardrobes"

    id = Column(BigInteger, primary_key=True, index=True)
    user_profile_id = Column(
        BigInteger,
        ForeignKey("user_profiles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    name = Column(String(120), nullable=False)
    description = Column(Text, nullable=True)
    address = Column(String, nullable=True)
    created_at = Column(DateTime, nullable=False, server_default=func.now())

    user_profile = relationship("UserProfile", back_populates="wardrobes")
    items = relationship("WardrobeItem", back_populates="wardrobe", cascade="all, delete-orphan")


class Outfit(Base):
    __tablename__ = "outfits"

    id = Column(BigInteger, primary_key=True, index=True)
    user_profile_id = Column(
        BigInteger,
        ForeignKey("user_profiles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    title = Column(String(120), nullable=False)
    image_generated_url = Column(String, nullable=True)
    is_favorite = Column(Boolean, nullable=False, default=False, server_default=text("false"))
    created_at = Column(DateTime, nullable=False, server_default=func.now())

    user_profile = relationship("UserProfile", back_populates="outfits")
    items = relationship("WardrobeItem", back_populates="outfit", cascade="all, delete-orphan")


class ItemTypeEnum(str, enum.Enum):
    top = "top"
    bottom = "bottom"
    shoe = "shoe"
    outwear = "outwear"
    accessory = "accessory"


class ItemSubtypeEnum(str, enum.Enum):
    t_shirt = "t_shirt"
    polo = "polo"
    shirt = "shirt"
    dress_shirt = "dress_shirt"
    hoodie = "hoodie"
    sweater = "sweater"
    tank_top = "tank_top"
    shorts = "shorts"
    jeans = "jeans"
    joggers = "joggers"
    trousers = "trousers"
    sneakers = "sneakers"
    running_shoes = "running_shoes"
    boots = "boots"
    loafers = "loafers"
    sandals = "sandals"
    blazer = "blazer"
    coat = "coat"
    raincoat = "raincoat"
    puffer_jacket = "puffer_jacket"
    denim_jacket = "denim_jacket"
    bag = "bag"
    watch = "watch"
    scarf = "scarf"
    hat = "hat"
    belt = "belt"


class ItemCategoryEnum(str, enum.Enum):
    casual = "casual"
    chic = "chic"
    sport = "sport"


class ItemSeasonEnum(str, enum.Enum):
    summer = "summer"
    winter = "winter"
    autumn = "autumn"
    spring = "spring"


class ItemColorEnum(str, enum.Enum):
    black = "black"
    white = "white"
    beige = "beige"
    blue = "blue"
    red = "red"
    green = "green"
    pink = "pink"
    brown = "brown"
    gray = "gray"
    purple = "purple"


class WardrobeItem(Base):
    __tablename__ = "wardrobe_items"

    id = Column(BigInteger, primary_key=True, index=True)

    wardrobe_id = Column(
        BigInteger,
        ForeignKey("wardrobes.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    outfit_id = Column(
        BigInteger,
        ForeignKey("outfits.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    name = Column(String(120), nullable=False)
    type = Column(Enum(ItemTypeEnum, name="item_type_enum"), nullable=False)
    item_subtype = Column(Enum(ItemSubtypeEnum, name="item_subtype_enum"), nullable=True)
    category = Column(Enum(ItemCategoryEnum, name="item_category_enum"), nullable=False)
    color = Column(Enum(ItemColorEnum, name="item_color_enum"), nullable=True)
    material = Column(String(120), nullable=True)
    season = Column(Enum(ItemSeasonEnum, name="item_season_enum"), nullable=True)
    image_url = Column(String, nullable=True)
    visual_description = Column(Text, nullable=True)
    ai_detected_metadata = Column(JSON, nullable=True)

    precipitation_resistant = Column(Boolean, nullable=False, default=False, server_default=text("false"))
    usage_count = Column(Integer, nullable=False, default=0, server_default=text("0"))
    date_added = Column(DateTime, nullable=False, server_default=func.now())

    wardrobe = relationship("Wardrobe", back_populates="items")
    outfit = relationship("Outfit", back_populates="items")


class UserPreference(Base):
    __tablename__ = "user_preferences"

    id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)

    favorite_colors = Column(JSON, nullable=False, default=list)
    favorite_styles = Column(JSON, nullable=False, default=list)

    user = relationship("User", back_populates="preference")


class PasswordResetCode(Base):
    __tablename__ = "password_reset_codes"

    id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    code = Column(String(4), nullable=False)
    is_used = Column(Boolean, nullable=False, default=False, server_default=text("false"))
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, nullable=False, server_default=func.now())

    user = relationship("User", back_populates="reset_codes")


class PrecipTypeEnum(str, enum.Enum):
    none = "none"
    rain = "rain"
    snow = "snow"
    hail = "hail"


class WeatherData(Base):
    __tablename__ = "weather_data"

    id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)

    city = Column(String(120), nullable=False)
    country = Column(String(120), nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)

    temperature = Column(Float, nullable=True)
    feels_like = Column(Float, nullable=True)
    condition = Column(String(120), nullable=True)
    humidity = Column(Integer, nullable=True)
    wind_kph = Column(Float, nullable=True)

    precipitation = Column(Boolean, nullable=False, default=False, server_default=text("false"))
    precip_type = Column(Enum(PrecipTypeEnum, name="precip_type_enum"), nullable=True)
    weather_category = Column(String(20), nullable=True)

    user = relationship("User", back_populates="weather_data")


class AIOutfitHistory(Base):
    __tablename__ = "ai_outfit_history"

    id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # temporary: okay for demo, but later replace with image_url/image_key
    # and store generated images in S3, Cloudinary, or local file storage.
    image_url = Column(Text, nullable=False)

    city = Column(String(120), nullable=False)
    country = Column(String(120), nullable=True)
    temperature = Column(String(50), nullable=True)
    weather = Column(String(120), nullable=True)
    style = Column(String(120), nullable=True)
    color = Column(String(120), nullable=True)
    gender = Column(String(50), nullable=True)

    body_shape = Column(String(80), nullable=True)
    skin_tone = Column(String(80), nullable=True)
    used_selected_wardrobe_items = Column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("false"),
    )
    wardrobe_items_used_details = Column(JSON, nullable=True)

    created_at = Column(DateTime, nullable=False, server_default=func.now())

    user = relationship("User", back_populates="ai_outfit_history")
