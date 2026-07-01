from typing import Optional

from utils.ai_normalizers import clean_text


def is_rainy(weather: str, precipitation: str) -> bool:
    weather_lower = clean_text(weather, "").lower()
    precipitation_lower = clean_text(precipitation, "").lower()

    return (
        precipitation_lower in {"yes", "true", "1"}
        or "rain" in weather_lower
        or "drizzle" in weather_lower
        or "storm" in weather_lower
        or "shower" in weather_lower
        or "thunder" in weather_lower
    )


def normalize_weather_label(weather: str, precipitation: str) -> str:
    weather_lower = clean_text(weather, "").lower()

    if is_rainy(weather, precipitation):
        return "Rainy"

    if "snow" in weather_lower:
        return "Snowy"

    if "cloud" in weather_lower or "overcast" in weather_lower or "fog" in weather_lower or "mist" in weather_lower:
        return "Cloudy"

    if "wind" in weather_lower:
        return "Windy"

    if "sun" in weather_lower or "clear" in weather_lower:
        return "Sunny"

    return "Cloudy"


def build_weather_scene_rules(weather_label: str, temperature_value: Optional[float], time_of_day: str) -> str:
    tod = clean_text(time_of_day, "daytime")

    if weather_label == "Rainy":
        return (
            f"Overcast rainy outdoor street atmosphere, wet pavement, soft natural light, "
            f"weather clearly rainy, time of day {tod}."
        )

    if weather_label == "Cloudy":
        return (
            f"Overcast cloudy outdoor street atmosphere, gray or cloudy sky, soft light, "
            f"no bright sunshine, time of day {tod}."
        )

    if weather_label == "Sunny":
        return (
            f"Bright outdoor street atmosphere with sunlight and a clear or lightly clouded sky, "
            f"time of day {tod}."
        )

    if weather_label == "Snowy":
        return (
            f"Cold snowy outdoor street atmosphere, winter mood, visible snow or snow traces, "
            f"time of day {tod}."
        )

    if weather_label == "Windy":
        return (
            f"Outdoor street atmosphere with subtle wind effect in clothing or hair, "
            f"time of day {tod}."
        )

    return f"Natural outdoor street atmosphere matching {weather_label.lower()} weather, time of day {tod}."
