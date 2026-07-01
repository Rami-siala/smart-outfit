import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/models/outfit_recommendation_data.dart';
import 'package:frontend/screens/auth/sign_in_screen.dart';
import 'package:frontend/screens/outfit_recommendation_screen.dart';
import 'package:frontend/screens/weather/weather_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/location_service.dart';
import 'package:frontend/services/outfit_recommendation_service.dart';
import 'package:geolocator/geolocator.dart';

class LocationChoiceScreen extends StatefulWidget {
  final String selectedGender;
  final String selectedColor;
  final String selectedStyle;
  final bool confirmLogoutOnExit;

  const LocationChoiceScreen({
    super.key,
    required this.selectedGender,
    required this.selectedColor,
    required this.selectedStyle,
    this.confirmLogoutOnExit = false,
  });

  @override
  State<LocationChoiceScreen> createState() => _LocationChoiceScreenState();
}

class _LocationChoiceScreenState extends State<LocationChoiceScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tryAutoUseSavedLocation();
  }

  LocationSettings _getLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
    );
  }

  Future<void> _tryAutoUseSavedLocation() async {
    final shouldUseDeviceLocation =
        await LocationService.getUseDeviceLocation();

    if (!shouldUseDeviceLocation || !mounted) {
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final hasPermission =
        await LocationService.hasGrantedLocationPermission();

    if (!serviceEnabled || !hasPermission || !mounted) {
      return;
    }

    await _handleAllowLocation(skipPreferenceSave: true);
  }

  Future<bool> _showLogoutDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Do you want to log out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _handleExit() async {
    if (!widget.confirmLogoutOnExit) {
      Navigator.of(context).pop();
      return;
    }

    final shouldLogout = await _showLogoutDialog();
    if (!shouldLogout || !mounted) return;

    await ApiService.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const SignInScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _handleAllowLocation({
    bool skipPreferenceSave = false,
  }) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final accessState = await LocationService.ensureLocationAccess();

      if (!accessState.serviceEnabled) {
        if (!mounted) return;
        await _showLocationServicesDialog();
        return;
      }

      if (accessState.isDeniedForever) {
        if (!mounted) return;
        await _showAppSettingsDialog();
        return;
      }

      if (!accessState.isGranted) {
        if (!mounted) return;
        _showPermissionDeniedMessage();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: _getLocationSettings(),
      );

      if (!skipPreferenceSave) {
        await LocationService.saveUseDeviceLocation(true);
      }

      final weather = await ApiService.getCurrentWeather(
        '${position.latitude},${position.longitude}',
      );
      final recommendation =
          await OutfitRecommendationService.buildRecommendation(
        selectedGender: widget.selectedGender,
        selectedColor: widget.selectedColor,
        selectedStyle: widget.selectedStyle,
        weather: weather,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OutfitRecommendationScreen(
            data: OutfitRecommendationData.fromRecommendationMap(
              recommendation,
              gender: widget.selectedGender,
              color: widget.selectedColor,
              style: widget.selectedStyle,
              weather: (weather['condition'] ?? weather['weather_category'])
                  ?.toString(),
            ),
            confirmLogoutOnExit: widget.confirmLogoutOnExit,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showLocationServicesDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Turn on location'),
        content: const Text(
          'Your phone location/GPS is off. Turn it on to use your current location, or choose a city manually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Geolocator.openLocationSettings();
            },
            child: const Text('Open location settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAppSettingsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow location in settings'),
        content: const Text(
          'Location permission is blocked for this app. Open app settings and allow location access to continue with your current location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Choose city instead'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Geolocator.openAppSettings();
            },
            child: const Text('Open app settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Location permission was denied. Please allow it to use your current location, or choose a city manually.',
        ),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () {
            if (!_isLoading) {
              _handleAllowLocation();
            }
          },
        ),
      ),
    );
  }

  Future<void> _handleChooseCity() async {
    await LocationService.saveUseDeviceLocation(false);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WeatherScreen(
          showSearchSection: true,
          selectedGender: widget.selectedGender,
          selectedColor: widget.selectedColor,
          selectedStyle: widget.selectedStyle,
          confirmLogoutOnExit: widget.confirmLogoutOnExit,
        ),
      ),
    );
  }

  Future<void> _goBack() async {
    await _handleExit();
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2B4E7C),
            Color(0xFF7A367B),
            Color(0xFFC03B6F),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            left: -40,
            child: _GlowOrb(
              size: 220,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            top: 160,
            right: -30,
            child: _GlowOrb(
              size: 170,
              color: const Color(0xFFFFC2D9).withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            bottom: -40,
            left: 30,
            child: _GlowOrb(
              size: 180,
              color: const Color(0xFFFFE6F1).withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.confirmLogoutOnExit,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF2B4E7C),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: _buildBackground()),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                              ),
                              child: IconButton(
                                onPressed: _goBack,
                                tooltip: 'Back',
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Weather access',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.18),
                                Colors.white.withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 26,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.98),
                                      const Color(0xFFFFF2F7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    width: 1.2,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF2B568D),
                                            Color(0xFF173B6D),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: const Icon(
                                        Icons.cloud_outlined,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    Positioned(
                                      top: 11,
                                      right: 11,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFFE85B5B),
                                              Color(0xFFD970C4),
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Use your location for better weather',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  height: 1.04,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Allow location access to get more accurate local weather and faster outfit recommendations.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontSize: 14,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.bolt_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'This helps us skip manual city search when possible and show weather-aware outfit suggestions immediately.',
                                        style: TextStyle(
                                          color: Colors.white,
                                          height: 1.4,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF173B6D).withValues(alpha: 0.10),
                                blurRadius: 30,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F7FB),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.explore_outlined,
                                      size: 16,
                                      color: Color(0xFFD970C4),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Choose how to continue',
                                      style: TextStyle(
                                        color: Color(0xFF173B6D),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Location permission is recommended',
                                style: TextStyle(
                                  color: Color(0xFF173B6D),
                                  fontSize: 24,
                                  height: 1.08,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You can allow location now for the smoothest experience, or choose a city manually instead.',
                                style: TextStyle(
                                  color: const Color(0xFF173B6D).withValues(alpha: 0.62),
                                  fontSize: 14,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFE85B5B),
                                        Color(0xFFD970C4),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFE85B5B).withValues(alpha: 0.26),
                                        blurRadius: 20,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _handleAllowLocation,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      disabledBackgroundColor: Colors.transparent,
                                      disabledForegroundColor: Colors.white70,
                                    ),
                                    icon: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.my_location_rounded, size: 20),
                                    label: Text(
                                      _isLoading ? 'Checking location...' : 'Allow location',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _handleChooseCity,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF173B6D),
                                    backgroundColor: const Color(0xFFF3F7FB),
                                    side: BorderSide(
                                      color: const Color(0xFF173B6D).withValues(alpha: 0.10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.location_city_outlined, size: 20),
                                  label: const Text(
                                    'Choose city manually',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
