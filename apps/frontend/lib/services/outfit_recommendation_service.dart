import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class OutfitRecommendationService {
  static String _value(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty) return fallback;
    return text;
  }

  static String _formatTemp(dynamic value) {
    if (value == null) return '--';

    final number =
        value is num ? value.toDouble() : double.tryParse(value.toString());

    if (number == null) return '--';

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number.toStringAsFixed(1);
  }

  static String _getWeatherFolder(Map<String, dynamic> weather) {
    final condition = (weather['condition'] ?? '').toString().toLowerCase();
    final category = (weather['weather_category'] ?? '').toString().toLowerCase();
    final temp = weather['temperature'] is num
        ? (weather['temperature'] as num).toDouble()
        : double.tryParse(weather['temperature']?.toString() ?? '');

    final isHot = category == 'hot' || (temp != null && temp > 25);
    final hasPrecipitation = weather['precipitation'] == true;
    final isRainLike =
        condition.contains('rain') ||
        condition.contains('drizzle') ||
        condition.contains('shower') ||
        condition.contains('storm') ||
        condition.contains('thunder') ||
        condition.contains('hail') ||
        condition.contains('sleet');

    // Wet weather should win over heat or bright conditions for outfit assets.
    if (hasPrecipitation || isRainLike) {
      return 'rainy';
    }

    if (isHot) {
      return 'sunny';
    }

    return 'normal';
  }

  static Future<String> _pickRandomOutfitImage({
    required String selectedGender,
    required String selectedColor,
    required String selectedStyle,
    required Map<String, dynamic> weather,
    String? selectionKey,
  }) async {
    final gender = selectedGender.trim().toLowerCase();
    final color = selectedColor.trim().toLowerCase();
    final style = selectedStyle.trim().toLowerCase();
    final weatherFolder = _getWeatherFolder(weather);
    final folderPrefix = 'assets/outfits/$style/$weatherFolder/';

    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);

    final matches = manifestMap.keys.where((path) {
      final normalizedPath = path.toLowerCase();

      return normalizedPath.startsWith(folderPrefix) &&
          (normalizedPath.endsWith('.png') ||
              normalizedPath.endsWith('.jpg') ||
              normalizedPath.endsWith('.jpeg') ||
              normalizedPath.endsWith('.webp')) &&
          normalizedPath.split('/').last.startsWith('${gender}_') &&
          normalizedPath.contains(color) &&
          normalizedPath.contains(weatherFolder) &&
          normalizedPath.contains(style);
    }).toList();

    if (matches.isEmpty) {
      throw Exception(
        'No matching image found for $gender / $color / $style / $weatherFolder',
      );
    }

    matches.sort();
    final key = selectionKey ?? '$gender|$color|$style|$weatherFolder';
    final index = _stableIndex(key, matches.length);
    return matches[index];
  }

  static Future<Map<String, String>> buildRecommendation({
    required String selectedGender,
    required String selectedColor,
    required String selectedStyle,
    required Map<String, dynamic> weather,
    String? selectionKey,
  }) async {
    final imagePath = await _pickRandomOutfitImage(
      selectedGender: selectedGender,
      selectedColor: selectedColor,
      selectedStyle: selectedStyle,
      weather: weather,
      selectionKey: selectionKey,
    );

    return {
      'imagePath': imagePath,
      'city': _value(weather['city']),
      'country': _value(weather['country']),
      'latitude': _value(weather['latitude'], fallback: ''),
      'longitude': _value(weather['longitude'], fallback: ''),
      'temperature': _formatTemp(weather['temperature']),
      'precipitation': weather['precipitation'] == true ? 'Yes' : 'No',
      'humidity': '${_value(weather['humidity'])}%',
      'wind': '${_value(weather['wind_kph'])} km/h',
    };
  }

  static int _stableIndex(String key, int length) {
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    return hash % length;
  }
}
