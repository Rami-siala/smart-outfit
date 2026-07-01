import 'package:frontend/services/api_service.dart';

class OutfitRecommendationData {
  static const String defaultGender = 'Male';
  static const String defaultStyle = 'Casual';
  static const String defaultColor = 'Black';

  final String imagePath;
  final String city;
  final String country;
  final double? latitude;
  final double? longitude;
  final String temperature;
  final String precipitation;
  final String humidity;
  final String wind;
  final String? style;
  final String? color;
  final String? gender;
  final String? weather;

  const OutfitRecommendationData({
    required this.imagePath,
    required this.city,
    required this.country,
    this.latitude,
    this.longitude,
    required this.temperature,
    required this.precipitation,
    required this.humidity,
    required this.wind,
    this.style,
    this.color,
    this.gender,
    this.weather,
  });

  factory OutfitRecommendationData.fromRecommendationMap(
    Map<String, String> recommendation, {
    String? style,
    String? color,
    String? gender,
    String? weather,
  }) {
    return OutfitRecommendationData(
      imagePath: recommendation['imagePath'] ?? '',
      city: recommendation['city'] ?? '',
      country: recommendation['country'] ?? '',
      latitude: _toDouble(recommendation['latitude']),
      longitude: _toDouble(recommendation['longitude']),
      temperature: recommendation['temperature'] ?? '',
      precipitation: recommendation['precipitation'] ?? 'No',
      humidity: recommendation['humidity'] ?? '-',
      wind: recommendation['wind'] ?? '-',
      style: style,
      color: color,
      gender: gender,
      weather: weather,
    );
  }

  OutfitRecommendationData copyWith({
    String? imagePath,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    String? temperature,
    String? precipitation,
    String? humidity,
    String? wind,
    String? style,
    String? color,
    String? gender,
    String? weather,
  }) {
    return OutfitRecommendationData(
      imagePath: imagePath ?? this.imagePath,
      city: city ?? this.city,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      temperature: temperature ?? this.temperature,
      precipitation: precipitation ?? this.precipitation,
      humidity: humidity ?? this.humidity,
      wind: wind ?? this.wind,
      style: style ?? this.style,
      color: color ?? this.color,
      gender: gender ?? this.gender,
      weather: weather ?? this.weather,
    );
  }

  bool get hasCompleteBadges =>
      _hasText(style) && _hasText(color) && _hasText(gender);

  Future<OutfitRecommendationData> resolveBadges() async {
    if (hasCompleteBadges) {
      return this;
    }

    final profile = await ApiService.getMyProfile();
    final preferences = await ApiService.getMyPreferences();

    final resolvedGender = _normalize(
      gender,
      fallback: _normalize(profile?['gender']) ?? defaultGender,
    );
    final resolvedStyle = _normalize(
      style,
      fallback:
          _firstPreference(preferences?['favorite_styles']) ?? defaultStyle,
    );
    final resolvedColor = _normalize(
      color,
      fallback:
          _firstPreference(preferences?['favorite_colors']) ?? defaultColor,
    );

    return copyWith(
      gender: resolvedGender,
      style: resolvedStyle,
      color: resolvedColor,
    );
  }

  static String? _firstPreference(dynamic value) {
    if (value is List) {
      for (final item in value) {
        final normalized = _normalize(item);
        if (normalized != null) {
          return normalized;
        }
      }
    }

    return null;
  }

  static String? _normalize(dynamic value, {String? fallback}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return fallback;
    }
    return text;
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }
}
