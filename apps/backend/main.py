from datetime import datetime, timedelta
from pathlib import Path
import shutil
import uuid




from fastapi import FastAPI, Depends, HTTPException, status, UploadFile, File
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.staticfiles import StaticFiles
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

try:
    import firebase_admin
    from firebase_admin import auth as firebase_auth, credentials
except ModuleNotFoundError:
    firebase_admin = None
    firebase_auth = None
    credentials = None

from db import ping_db, get_db, Base, engine
from email_utils import send_email
from models import User, UserProfile, PasswordResetCode,UserPreference
from schemas import (
    UserCreate,
    UserOut,
    LoginRequest,
    TokenOut,
    UserMeUpdate,
    UserProfileCreateUpdate,
    UserProfileOut,
    FirebaseLoginRequest,
    ForgotPasswordRequest,
    VerifyResetCodeRequest,
    ResetPasswordRequest,
    ChangePasswordRequest,
    MessageOut,
    UserPreferenceCreateUpdate,
    UserPreferenceOut,      
)
from security import (
    hash_password,
    verify_password,
    create_access_token,
    decode_access_token,
    generate_reset_code,
)
from routers.weather_router import router as weather_router

from routers.ai_router import router as ai_router

from routers.wardrobe_router import router as wardrobe_router
from services.ai_history_image_service import STATIC_DIR, ensure_ai_history_storage
from services.wardrobe_item_image_service import ensure_wardrobe_item_storage


app = FastAPI(title="Smart Outfit API")

FIREBASE_ENABLED = False
firebase_path = Path(__file__).resolve().parent / "firebase-service-account.json"

if firebase_admin is not None and credentials is not None and firebase_path.exists():
    if not firebase_admin._apps:
        cred = credentials.Certificate(str(firebase_path))
        firebase_admin.initialize_app(cred)
    FIREBASE_ENABLED = True
else:
    print("[WARNING] firebase-service-account.json not found. Firebase auth disabled.")

Base.metadata.create_all(bind=engine)
ensure_ai_history_storage()
ensure_wardrobe_item_storage()

bearer_scheme = HTTPBearer()

app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

app.include_router(weather_router)


def _get_or_create_user_preference(db: Session, user_id: int) -> UserPreference:
    preference = (
        db.query(UserPreference).filter(UserPreference.user_id == user_id).first()
    )
    if preference:
        return preference

    preference = UserPreference(
        user_id=user_id,
        favorite_colors=[],
        favorite_styles=[],
    )
    db.add(preference)

    try:
        db.flush()
        return preference
    except IntegrityError:
        db.rollback()
        existing_preference = (
            db.query(UserPreference).filter(UserPreference.user_id == user_id).first()
        )
        if existing_preference is None:
            raise
        return existing_preference


def _is_local_profile_image_path(value: str) -> bool:
    normalized = value.strip().replace("\\", "/").lower()
    if not normalized:
        return False

    return (
        normalized.startswith("file://")
        or normalized.startswith("/data/user/")
        or normalized.startswith("data/user/")
        or normalized.startswith("/data/")
        or "/android/data/" in normalized
        or (len(normalized) > 2 and normalized[1:3] == ":/")
    )

app.include_router(ai_router)

app.include_router(wardrobe_router)

@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/db-health")
def db_health():
    return {"db": "ok" if ping_db() else "down"}


@app.post("/auth/register", response_model=TokenOut, status_code=201)
def register(payload: UserCreate, db: Session = Depends(get_db)):
    email = str(payload.email).strip().lower()

    existing = db.query(User).filter(User.email == email).first()
    if existing:
        raise HTTPException(status_code=409, detail="Email already registered")

    pw_hash = hash_password(payload.password)

    user = User(
        email=email,
        password_hash=pw_hash,
        full_name=payload.full_name,
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(user.id)
    return {"access_token": token, "token_type": "bearer"}


@app.post("/auth/login", response_model=TokenOut)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    email = str(payload.email).strip().lower()

    user = db.query(User).filter(User.email == email).first()
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    token = create_access_token(user.id)
    return {"access_token": token, "token_type": "bearer"}


@app.post("/auth/forgot-password", response_model=MessageOut)
def forgot_password(payload: ForgotPasswordRequest, db: Session = Depends(get_db)):
    email = str(payload.email).strip().lower()

    user = db.query(User).filter(User.email == email).first()

    if not user:
        return {"message": "If this email exists, a reset code has been sent."}

    old_codes = db.query(PasswordResetCode).filter(
        PasswordResetCode.user_id == user.id,
        PasswordResetCode.is_used == False,
    ).all()

    for item in old_codes:
        item.is_used = True

    code = generate_reset_code()
    expires_at = datetime.utcnow() + timedelta(minutes=10)

    reset_code = PasswordResetCode(
        user_id=user.id,
        code=code,
        expires_at=expires_at,
        is_used=False,
    )

    db.add(reset_code)
    db.commit()

    try:
        send_email(
            to_email=user.email,
            subject="Reset your password",
            body=(
                f"Hello,\n\n"
                f"Your password reset code is: {code}\n\n"
                f"This code expires in 10 minutes.\n\n"
                f"If you did not request this, please ignore this email."
            ),
        )
    except Exception as e:
        print(f"[EMAIL ERROR] Could not send reset email to {user.email}: {e}")
        raise HTTPException(
            status_code=500,
            detail="Unable to send reset email. Please try again.",
        )

    return {"message": "If this email exists, a reset code has been sent."}


@app.post("/auth/verify-reset-code", response_model=MessageOut)
def verify_reset_code(payload: VerifyResetCodeRequest, db: Session = Depends(get_db)):
    email = str(payload.email).strip().lower()
    code = payload.code.strip()

    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=400, detail="Invalid email or code")

    reset_code = (
        db.query(PasswordResetCode)
        .filter(
            PasswordResetCode.user_id == user.id,
            PasswordResetCode.code == code,
            PasswordResetCode.is_used == False,
        )
        .order_by(PasswordResetCode.created_at.desc())
        .first()
    )

    if not reset_code:
        raise HTTPException(status_code=400, detail="Invalid email or code")

    if reset_code.expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Code expired")

    return {"message": "Code verified successfully"}


@app.post("/auth/reset-password", response_model=MessageOut)
def reset_password(payload: ResetPasswordRequest, db: Session = Depends(get_db)):
    email = str(payload.email).strip().lower()
    code = payload.code.strip()

    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=400, detail="Invalid email or code")

    reset_code = (
        db.query(PasswordResetCode)
        .filter(
            PasswordResetCode.user_id == user.id,
            PasswordResetCode.code == code,
            PasswordResetCode.is_used == False,
        )
        .order_by(PasswordResetCode.created_at.desc())
        .first()
    )

    if not reset_code:
        raise HTTPException(status_code=400, detail="Invalid email or code")

    if reset_code.expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Code expired")

    user.password_hash = hash_password(payload.new_password)
    reset_code.is_used = True

    db.add(user)
    db.add(reset_code)
    db.commit()

    return {"message": "Password reset successfully"}


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


@app.get("/auth/me", response_model=UserOut)
def me(current_user: User = Depends(get_current_user)):
    return current_user


@app.put("/auth/me", response_model=UserOut)
def update_me(
    payload: UserMeUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if payload.full_name is not None:
        cleaned_name = payload.full_name.strip()
        current_user.full_name = cleaned_name if cleaned_name else None

    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    return current_user


@app.post("/auth/change-password", response_model=MessageOut)
def change_password(
    payload: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.password_hash == "SOCIAL_LOGIN":
        raise HTTPException(
            status_code=400,
            detail="Password change is not available for social login accounts",
        )

    if not verify_password(payload.current_password, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect")

    current_user.password_hash = hash_password(payload.new_password)
    db.add(current_user)
    db.commit()

    return {"message": "Password updated successfully"}





@app.get("/profile/me", response_model=UserProfileOut)
def get_my_profile(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()

    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    return profile

@app.post("/profile/upload-image")
def upload_profile_image(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    upload_dir = Path(__file__).resolve().parent / "static" / "profile_images"
    upload_dir.mkdir(parents=True, exist_ok=True)

    extension = Path(file.filename or "").suffix or ".jpg"
    filename = f"profile_{current_user.id}_{uuid.uuid4().hex}{extension}"
    file_path = upload_dir / filename

    with file_path.open("wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    image_url = f"/static/profile_images/{filename}"

    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    if not profile:
        profile = UserProfile(user_id=current_user.id)
        db.add(profile)

    profile.profile_image_url = image_url
    db.add(profile)
    db.commit()
    db.refresh(profile)

    return {"profile_image_url": image_url}





@app.put("/profile/me", response_model=UserProfileOut)
def upsert_my_profile(
    payload: UserProfileCreateUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()

    if not profile:
        profile = UserProfile(user_id=current_user.id)
        db.add(profile)

    if payload.birth_date is not None:
        profile.birth_date = payload.birth_date

    if payload.height is not None:
        profile.height = payload.height

    if payload.weight is not None:
        profile.weight = payload.weight

    if payload.skin_tone is not None:
        profile.skin_tone = payload.skin_tone

    if payload.body_shape is not None:
        profile.body_shape = payload.body_shape

    if payload.profile_image_url is not None and not _is_local_profile_image_path(
        payload.profile_image_url
    ):
        profile.profile_image_url = payload.profile_image_url

    if payload.gender is not None:
        profile.gender = payload.gender

    db.commit()
    db.refresh(profile)
    return profile

@app.post("/auth/firebase", response_model=TokenOut)
def firebase_login(payload: FirebaseLoginRequest, db: Session = Depends(get_db)):
    if not FIREBASE_ENABLED:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase auth is not configured on the backend",
        )

    try:
        decoded = firebase_auth.verify_id_token(payload.firebase_id_token)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase token",
        )

    email = str(decoded.get("email") or "").strip().lower()
    full_name = decoded.get("name")

    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email not available from provider",
        )

    user = db.query(User).filter(User.email == email).first()

    if not user:
        user = User(
            email=email,
            password_hash="SOCIAL_LOGIN",
            full_name=full_name,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    token = create_access_token(user.id)
    return {"access_token": token, "token_type": "bearer"}




@app.get("/preferences/me", response_model=UserPreferenceOut)
def get_my_preferences(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    preference = _get_or_create_user_preference(db, current_user.id)
    db.commit()
    db.refresh(preference)

    return preference


@app.put("/preferences/me", response_model=UserPreferenceOut)
def upsert_my_preferences(
    payload: UserPreferenceCreateUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    preference = _get_or_create_user_preference(db, current_user.id)

    preference.favorite_colors = payload.favorite_colors
    preference.favorite_styles = payload.favorite_styles

    db.commit()
    db.refresh(preference)
    return preference
