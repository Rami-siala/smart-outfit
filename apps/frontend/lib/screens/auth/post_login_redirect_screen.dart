import 'package:flutter/material.dart';
import 'package:frontend/models/outfit_recommendation_data.dart';
import 'package:frontend/screens/onboarding/name_screen.dart';
import 'package:frontend/screens/outfit_recommendation_screen.dart';
import 'package:frontend/screens/weather/location_choice_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/location_service.dart';
import 'package:frontend/services/outfit_recommendation_service.dart';

class PostLoginRedirectScreen extends StatefulWidget {
  const PostLoginRedirectScreen({super.key});

  @override
  State<PostLoginRedirectScreen> createState() => _PostLoginRedirectScreenState();
}

class _PostLoginRedirectScreenState extends State<PostLoginRedirectScreen> {
  bool _hasCompletedOnboarding = false;
  String _savedGender = '';
  String _savedColor = '';
  String _savedStyle = '';

  void _log(String message) {
    debugPrint('[PostLoginRedirectScreen] $message');
  }

  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    try {
      final me = await ApiService.getMe();
      final profile = await ApiService.getMyProfile();
      final preferences = await ApiService.getMyPreferences();

      final fullName = (me['full_name'] ?? '').toString().trim();
      final gender = (profile?['gender'] ?? '').toString().trim();

      final colors = preferences?['favorite_colors'];
      final styles = preferences?['favorite_styles'];

      final selectedColor = colors is List && colors.isNotEmpty
          ? colors.first.toString().trim().toLowerCase()
          : '';
      final selectedStyle = styles is List && styles.isNotEmpty
          ? styles.first.toString().trim().toLowerCase()
          : '';

      final hasCompletedOnboarding = fullName.isNotEmpty &&
          gender.isNotEmpty &&
          selectedColor.isNotEmpty &&
          selectedStyle.isNotEmpty;

      _hasCompletedOnboarding = hasCompletedOnboarding;
      _savedGender = gender;
      _savedColor = selectedColor;
      _savedStyle = selectedStyle;

      if (!mounted) return;

      if (hasCompletedOnboarding) {
        await _openBestRecommendationFlow(
          selectedGender: gender,
          selectedColor: selectedColor,
          selectedStyle: selectedStyle,
        );
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const NameScreen(),
        ),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;

      if (_hasCompletedOnboarding) {
        await _openBestRecommendationFlow(
          selectedGender: _savedGender,
          selectedColor: _savedColor,
          selectedStyle: _savedStyle,
        );
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const NameScreen(),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _openBestRecommendationFlow({
    required String selectedGender,
    required String selectedColor,
    required String selectedStyle,
  }) async {
    await LocationService.resetLocationPreferenceForLogin();

    Map<String, dynamic>? weather;

    try {
      final position = await LocationService.getCurrentPosition();
      weather = await ApiService.getCurrentWeatherByCoordinates(
        lat: position.latitude,
        lon: position.longitude,
      );
    } catch (_) {
      weather = null;
    }

    if (weather != null) {
      final resolvedWeather = weather;
      _log(
        '_openBestRecommendationFlow weather='
        'city=${resolvedWeather['city']} condition=${resolvedWeather['condition']} '
        'temperature=${resolvedWeather['temperature']} '
        'precipitation=${resolvedWeather['precipitation']} '
        'style=$selectedStyle color=$selectedColor gender=$selectedGender',
      );
      final recommendation =
          await OutfitRecommendationService.buildRecommendation(
        selectedGender: selectedGender,
        selectedColor: selectedColor,
        selectedStyle: selectedStyle,
        weather: resolvedWeather,
      );

      _log(
        '_openBestRecommendationFlow recommendationImagePath='
        '${recommendation['imagePath']}',
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => OutfitRecommendationScreen(
            data: OutfitRecommendationData.fromRecommendationMap(
              recommendation,
              gender: selectedGender,
              color: selectedColor,
              style: selectedStyle,
              weather:
                  (resolvedWeather['condition'] ?? resolvedWeather['weather_category'])
                      ?.toString(),
            ),
            confirmLogoutOnExit: true,
          ),
        ),
        (route) => false,
      );
      return;
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LocationChoiceScreen(
          selectedGender: selectedGender,
          selectedColor: selectedColor,
          selectedStyle: selectedStyle,
          confirmLogoutOnExit: true,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
