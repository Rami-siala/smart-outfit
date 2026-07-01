import unittest

from apps.backend.services.weather_service import WeatherService


class WeatherServiceCategoryTests(unittest.TestCase):
    def test_temperatures_at_or_below_15_are_cold(self) -> None:
        self.assertEqual(WeatherService.get_weather_category(10), "cold")
        self.assertEqual(WeatherService.get_weather_category(15), "cold")

    def test_temperatures_above_15_and_up_to_25_are_normal(self) -> None:
        self.assertEqual(WeatherService.get_weather_category(15.1), "normal")
        self.assertEqual(WeatherService.get_weather_category(25), "normal")

    def test_temperatures_above_25_are_hot(self) -> None:
        self.assertEqual(WeatherService.get_weather_category(25.1), "hot")


if __name__ == "__main__":
    unittest.main()
