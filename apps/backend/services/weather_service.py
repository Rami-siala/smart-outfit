import logging
import os
from pathlib import Path

import httpx
from dotenv import load_dotenv


BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

WEATHER_API_KEY = os.getenv("WEATHER_API_KEY")
BASE_URL = os.getenv("WEATHER_BASE_URL", "http://api.weatherapi.com/v1")

logger = logging.getLogger(__name__)


class WeatherService:
    @staticmethod
    def get_weather_category(temperature: float) -> str:
        """Classify temperature using inclusive thresholds at 15C and 25C."""
        if temperature <= 15:
            return "cold"
        if temperature <= 25:
            return "normal"
        return "hot"

    @staticmethod
    def _detect_precip_type(condition_text: str | None) -> str | None:
        if not condition_text:
            return None

        text = condition_text.lower()

        if "hail" in text:
            return "hail"
        if "snow" in text or "blizzard" in text or "ice pellets" in text:
            return "snow"
        if "rain" in text or "drizzle" in text or "shower" in text or "sleet" in text:
            return "rain"

        return None

    @staticmethod
    def _extract_weather_api_error(response: httpx.Response) -> str:
        try:
            error_json = response.json()
        except ValueError:
            return "Weather API returned non-OK status"

        if isinstance(error_json, dict):
            error = error_json.get("error")
            if isinstance(error, dict):
                message = error.get("message")
                if message:
                    return str(message)

        return "Weather API error"

    @staticmethod
    async def search_cities(query: str):
        if not WEATHER_API_KEY:
            raise RuntimeError("WEATHER_API_KEY is missing")

        url = f"{BASE_URL}/search.json"
        params = {
            "key": WEATHER_API_KEY,
            "q": query,
        }

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(url, params=params)
                response.raise_for_status()
                data = response.json()

            if not isinstance(data, list):
                logger.error("Unexpected WeatherAPI search response format: %r", data)
                raise RuntimeError("Invalid city search data received from API")

            return [
                {
                    "id": item.get("id"),
                    "name": item.get("name"),
                    "region": item.get("region"),
                    "country": item.get("country"),
                    "lat": item.get("lat"),
                    "lon": item.get("lon"),
                }
                for item in data
                if isinstance(item, dict) and item.get("name")
            ]

        except httpx.RequestError as e:
            logger.error("Network error while calling WeatherAPI search: %s", e, exc_info=True)
            raise RuntimeError("Network error while calling WeatherAPI") from e

        except httpx.HTTPStatusError as e:
            message = WeatherService._extract_weather_api_error(e.response)
            if e.response.status_code == 400:
                raise ValueError(message) from e

            logger.error(
                "WeatherAPI search returned status %s: %s",
                e.response.status_code,
                message,
                exc_info=True,
            )
            raise RuntimeError(message) from e

        except ValueError:
            raise

        except RuntimeError:
            raise

        except Exception as e:
            logger.error("Unexpected WeatherAPI search error: %s", e, exc_info=True)
            raise RuntimeError("Failed to search cities") from e

    @staticmethod
    async def get_current_weather(q: str):
        if not WEATHER_API_KEY:
            raise RuntimeError("WEATHER_API_KEY is missing")

        url = f"{BASE_URL}/current.json"
        params = {
            "key": WEATHER_API_KEY,
            "q": q,
        }

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(url, params=params)
                response.raise_for_status()
                data = response.json()

            if not isinstance(data, dict):
                logger.error("Unexpected WeatherAPI current response type: %r", data)
                raise RuntimeError("Invalid weather data received from API")

            current = data.get("current")
            location = data.get("location")

            if not isinstance(current, dict) or not isinstance(location, dict):
                logger.error("Missing 'current' or 'location' in WeatherAPI response: %r", data)
                raise RuntimeError("Invalid weather data received from API")

            condition = current.get("condition")
            condition_text = condition.get("text") if isinstance(condition, dict) else None

            city = location.get("name")
            country = location.get("country")
            latitude = location.get("lat")
            longitude = location.get("lon")
            temperature = current.get("temp_c")
            feels_like = current.get("feelslike_c")
            humidity = current.get("humidity")
            wind_kph = current.get("wind_kph")
            precip_mm = current.get("precip_mm", 0) or 0

            required_values = {
                "city": city,
                "temperature": temperature,
                "feels_like": feels_like,
                "condition": condition_text,
                "humidity": humidity,
                "wind_kph": wind_kph,
            }

            missing = [key for key, value in required_values.items() if value is None]
            if missing:
                logger.error(
                    "Missing expected keys in WeatherAPI current response: %s | data=%r",
                    missing,
                    data,
                )
                raise RuntimeError("Invalid weather data received from API")

            precipitation = float(precip_mm) > 0
            precip_type = WeatherService._detect_precip_type(condition_text)
            weather_category = WeatherService.get_weather_category(float(temperature))

            return {
                "city": city,
                "country": country,
                "latitude": latitude,
                "longitude": longitude,
                "temperature": float(temperature),
                "feels_like": float(feels_like),
                "condition": condition_text,
                "humidity": int(humidity),
                "wind_kph": float(wind_kph),
                "precipitation": precipitation,
                "precip_type": precip_type,
                "weather_category": weather_category,
            }

        except httpx.RequestError as e:
            logger.error("Network error while calling WeatherAPI current: %s", e, exc_info=True)
            raise RuntimeError("Network error while calling WeatherAPI") from e

        except httpx.HTTPStatusError as e:
            message = WeatherService._extract_weather_api_error(e.response)
            if e.response.status_code == 400:
                raise ValueError(message) from e

            logger.error(
                "WeatherAPI current returned status %s: %s",
                e.response.status_code,
                message,
                exc_info=True,
            )
            raise RuntimeError(message) from e

        except ValueError:
            raise

        except RuntimeError:
            raise

        except Exception as e:
            logger.error("Unexpected WeatherAPI current error: %s", e, exc_info=True)
            raise RuntimeError("Failed to fetch current weather") from e

    @staticmethod
    async def get_forecast_weather(q: str, days: int = 7):
        if not WEATHER_API_KEY:
            raise RuntimeError("WEATHER_API_KEY is missing")

        safe_days = max(1, min(days, 7))
        url = f"{BASE_URL}/forecast.json"
        params = {
            "key": WEATHER_API_KEY,
            "q": q,
            "days": safe_days,
            "aqi": "no",
            "alerts": "no",
        }

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(url, params=params)
                response.raise_for_status()
                data = response.json()

            if not isinstance(data, dict):
                logger.error("Unexpected WeatherAPI forecast response type: %r", data)
                raise RuntimeError("Invalid forecast data received from API")

            location = data.get("location")
            forecast = data.get("forecast")
            current = data.get("current")
            forecast_days = forecast.get("forecastday") if isinstance(forecast, dict) else None

            if not isinstance(location, dict) or not isinstance(forecast_days, list):
                logger.error("Missing forecast structure in WeatherAPI response: %r", data)
                raise RuntimeError("Invalid forecast data received from API")

            city = location.get("name")
            country = location.get("country")
            latitude = location.get("lat")
            longitude = location.get("lon")
            timezone_id = location.get("tz_id")
            localtime = location.get("localtime")
            localtime_epoch = location.get("localtime_epoch")
            current_uv = current.get("uv") if isinstance(current, dict) else None
            current_visibility_km = (
                current.get("vis_km") if isinstance(current, dict) else None
            )

            hourly = []
            daily = []
            sunrise = None
            sunset = None

            for forecast_day in forecast_days:
                if not isinstance(forecast_day, dict):
                    continue

                date = forecast_day.get("date")
                day_data = forecast_day.get("day")
                hour_data = forecast_day.get("hour")
                astro_data = forecast_day.get("astro")

                if sunrise is None and isinstance(astro_data, dict):
                    sunrise = astro_data.get("sunrise")
                    sunset = astro_data.get("sunset")

                if isinstance(day_data, dict):
                    condition = day_data.get("condition")
                    condition_text = (
                        condition.get("text") if isinstance(condition, dict) else None
                    )
                    avg_temp = day_data.get("avgtemp_c")
                    max_wind = day_data.get("maxwind_kph")
                    avg_humidity = day_data.get("avghumidity")
                    total_precip = day_data.get("totalprecip_mm", 0) or 0

                    if date and avg_temp is not None:
                        daily.append(
                            {
                                "date": date,
                                "temperature": float(avg_temp),
                                "condition": condition_text,
                                "humidity": int(avg_humidity) if avg_humidity is not None else None,
                                "wind_kph": float(max_wind) if max_wind is not None else 0.0,
                                "uv": float(day_data.get("uv"))
                                if day_data.get("uv") is not None
                                else None,
                                "precipitation": float(total_precip) > 0,
                                "precip_type": WeatherService._detect_precip_type(condition_text),
                                "weather_category": WeatherService.get_weather_category(float(avg_temp)),
                            }
                        )

                if not isinstance(hour_data, list):
                    continue

                for hour in hour_data:
                    if not isinstance(hour, dict):
                        continue

                    condition = hour.get("condition")
                    condition_text = (
                        condition.get("text") if isinstance(condition, dict) else None
                    )
                    temp = hour.get("temp_c")
                    humidity = hour.get("humidity")
                    wind_kph = hour.get("wind_kph")
                    precip_mm = hour.get("precip_mm", 0) or 0
                    time_value = hour.get("time")

                    if time_value is None or temp is None:
                        continue

                    hourly.append(
                        {
                            "time": time_value,
                            "temperature": float(temp),
                            "condition": condition_text,
                            "humidity": int(humidity) if humidity is not None else None,
                            "wind_kph": float(wind_kph) if wind_kph is not None else 0.0,
                            "uv": float(hour.get("uv")) if hour.get("uv") is not None else None,
                            "visibility_km": float(hour.get("vis_km"))
                            if hour.get("vis_km") is not None
                            else None,
                            "precipitation": float(precip_mm) > 0,
                            "precip_type": WeatherService._detect_precip_type(condition_text),
                            "weather_category": WeatherService.get_weather_category(float(temp)),
                        }
                    )

            return {
                "city": city,
                "country": country,
                "latitude": latitude,
                "longitude": longitude,
                "timezone_id": timezone_id,
                "localtime": localtime,
                "localtime_epoch": localtime_epoch,
                "current_uv": float(current_uv) if current_uv is not None else None,
                "current_visibility_km": float(current_visibility_km)
                if current_visibility_km is not None
                else None,
                "sunrise": sunrise,
                "sunset": sunset,
                "hourly": hourly,
                "daily": daily,
            }

        except httpx.RequestError as e:
            logger.error("Network error while calling WeatherAPI forecast: %s", e, exc_info=True)
            raise RuntimeError("Network error while calling WeatherAPI") from e

        except httpx.HTTPStatusError as e:
            message = WeatherService._extract_weather_api_error(e.response)
            if e.response.status_code == 400:
                raise ValueError(message) from e

            logger.error(
                "WeatherAPI forecast returned status %s: %s",
                e.response.status_code,
                message,
                exc_info=True,
            )
            raise RuntimeError(message) from e

        except ValueError:
            raise

        except RuntimeError:
            raise

        except Exception as e:
            logger.error("Unexpected WeatherAPI forecast error: %s", e, exc_info=True)
            raise RuntimeError("Failed to fetch forecast weather") from e
