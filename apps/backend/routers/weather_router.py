from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session
import logging

from db import get_db
from models import User, WeatherData
from schemas import CitySearchOut, WeatherDataBase, WeatherDataOut
from security import decode_access_token
from services.weather_service import WeatherService

router = APIRouter(prefix="/weather", tags=["weather"])

bearer_scheme = HTTPBearer(auto_error=False)
logger = logging.getLogger(__name__)


def get_current_user_optional(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User | None:
    if credentials is None:
        return None

    token = credentials.credentials

    try:
        payload = decode_access_token(token)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

    if not isinstance(payload, dict):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

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


def get_current_user(
    current_user: User | None = Depends(get_current_user_optional),
) -> User:
    if current_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
        )

    return current_user


@router.get("/search", response_model=list[CitySearchOut])
async def search_cities(
    q: str = Query(..., min_length=2),
):
    try:
        return await WeatherService.search_cities(q)

    except ValueError as e:
        logger.warning("Weather city search rejected for query '%s': %s", q, e)
        raise HTTPException(status_code=400, detail=str(e))

    except RuntimeError as e:
        logger.error("Weather city search failed for query '%s': %s", q, e, exc_info=True)
        raise HTTPException(status_code=502, detail=str(e))

    except Exception as e:
        logger.error("Unexpected city search error for query '%s': %s", q, e, exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to search cities")


@router.get("/current", response_model=WeatherDataBase)
async def current_weather(
    q: str = Query(..., min_length=2),
    db: Session = Depends(get_db),
    current_user: User | None = Depends(get_current_user_optional),
):
    user_label = current_user.id if current_user is not None else "guest"

    try:
        weather = await WeatherService.get_current_weather(q)

        if current_user is None:
            return weather

        weather_data = (
            db.query(WeatherData)
            .filter(WeatherData.user_id == current_user.id)
            .first()
        )

        if weather_data is None:
            weather_data = WeatherData(user_id=current_user.id)
            db.add(weather_data)

        weather_data.city = weather["city"]
        weather_data.country = weather["country"]
        weather_data.latitude = weather["latitude"]
        weather_data.longitude = weather["longitude"]
        weather_data.temperature = weather["temperature"]
        weather_data.feels_like = weather["feels_like"]
        weather_data.condition = weather["condition"]
        weather_data.humidity = weather["humidity"]
        weather_data.wind_kph = weather["wind_kph"]
        weather_data.precipitation = weather["precipitation"]
        weather_data.precip_type = weather["precip_type"]
        weather_data.weather_category = weather["weather_category"]

        db.commit()
        db.refresh(weather_data)

        return weather_data

    except HTTPException:
        db.rollback()
        raise

    except ValueError as e:
        db.rollback()
        logger.warning(
            "Weather request rejected for user %s and query '%s': %s",
            user_label,
            q,
            e,
        )
        raise HTTPException(status_code=400, detail=str(e))

    except RuntimeError as e:
        db.rollback()
        logger.error(
            "Weather update failed for user %s and query '%s': %s",
            user_label,
            q,
            e,
            exc_info=True,
        )
        raise HTTPException(status_code=502, detail=str(e))

    except Exception as e:
        db.rollback()
        logger.error(
            "Unexpected weather update error for user %s and query '%s': %s",
            user_label,
            q,
            e,
            exc_info=True,
        )
        raise HTTPException(status_code=500, detail="Failed to update weather data")


@router.get("/last", response_model=WeatherDataOut)
async def get_last_weather(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    weather_data = (
        db.query(WeatherData)
        .filter(WeatherData.user_id == current_user.id)
        .first()
    )

    if weather_data is None:
        raise HTTPException(status_code=404, detail="No saved weather data found")

    return weather_data


@router.get("/forecast")
async def forecast_weather(
    q: str = Query(..., min_length=2),
    days: int = Query(7, ge=1, le=7),
):
    try:
        return await WeatherService.get_forecast_weather(q, days=days)

    except ValueError as e:
        logger.warning(
            "Weather forecast request rejected for query '%s': %s",
            q,
            e,
        )
        raise HTTPException(status_code=400, detail=str(e))

    except RuntimeError as e:
        logger.error(
            "Weather forecast failed for query '%s': %s",
            q,
            e,
            exc_info=True,
        )
        raise HTTPException(status_code=502, detail=str(e))

    except Exception as e:
        logger.error(
            "Unexpected weather forecast error for query '%s': %s",
            q,
            e,
            exc_info=True,
        )
        raise HTTPException(status_code=500, detail="Failed to fetch weather forecast")
