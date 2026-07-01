import 'package:flutter/material.dart';
import 'package:frontend/models/outfit_recommendation_data.dart';
import 'package:frontend/screens/onboarding/gender_screen.dart';
import 'package:frontend/screens/auth/sign_in_screen.dart';
import 'package:frontend/screens/outfit_recommendation_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/location_service.dart';
import 'package:frontend/services/outfit_recommendation_service.dart';
import 'package:geolocator/geolocator.dart';

const Color _navy = Color(0xFF173B6D);
const Color _navySoft = Color(0xFF2B568D);
const Color _mist = Color(0xFFF3F7FB);
const Color _pink = Color(0xFFD970C4);
const Color _coral = Color(0xFFE85B5B);
const Color _ink = Color(0xFF18324E);

class WeatherScreen extends StatefulWidget {
  final Map<String, dynamic>? initialWeather;
  final bool showSearchSection;
  final String selectedGender;
  final String selectedColor;
  final String selectedStyle;
  final bool confirmLogoutOnExit;
  final bool isGuest;

  const WeatherScreen({
    super.key,
    this.initialWeather,
    this.showSearchSection = true,
    required this.selectedGender,
    required this.selectedColor,
    required this.selectedStyle,
    this.confirmLogoutOnExit = false,
    this.isGuest = false,
  });

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final TextEditingController _cityController = TextEditingController();

  bool _isSearching = false;
  bool _isLocating = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _cities = [];
  Map<String, dynamic>? _weather;

  void _log(String message) {
    debugPrint('[WeatherScreen] $message');
  }

  @override
  void initState() {
    super.initState();
    _weather = widget.initialWeather;
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
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

  Future<void> _goBack() async {
    if (!widget.confirmLogoutOnExit) {
      Navigator.of(context).pop();
      return;
    }

    final shouldLogout = await _showLogoutDialog();
    if (!shouldLogout || !mounted) return;

    await ApiService.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  Future<void> _searchCities() async {
    final query = _cityController.text.trim();

    if (query.length < 2) {
      setState(() {
        _errorMessage = 'Please enter at least 2 characters';
        _cities = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final results = await ApiService.searchCities(query);

      if (!mounted) return;

      setState(() {
        if (results.isEmpty) {
          _errorMessage = 'City not found';
          _cities = [];
        } else {
          _errorMessage = null;
          _cities = results;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'City not found';
        _cities = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _getCurrentWeather({String? query}) async {
    final cityQuery = (query ?? _cityController.text).trim();

    if (cityQuery.length < 2) {
      setState(() {
        _errorMessage = 'Please enter a valid city';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    try {
      final weather = await ApiService.getCurrentWeather(cityQuery);

      if (!mounted) return;

      setState(() {
        _weather = weather;
        _cities = [];
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _handleAllowLocation() async {
    if (_isLocating) return;

    setState(() {
      _isLocating = true;
      _errorMessage = null;
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
        setState(() {
          _errorMessage = LocationService.locationPermissionDeniedMessage;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await LocationService.saveUseDeviceLocation(true);

      final weather = await ApiService.getCurrentWeatherByCoordinates(
        lat: position.latitude,
        lon: position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _weather = weather;
        _cities = [];
        _cityController.text = _value(weather['city'], fallback: '');
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
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

  String _value(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty) return fallback;
    return text;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _formatTemp(dynamic value) {
    final number = _toDouble(value);
    if (number == null) return '--';
    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }
    return number.toStringAsFixed(1);
  }

  String _conditionText() {
    return _value(_weather?['condition'], fallback: '');
  }

  String _weatherCategory() {
    return _value(_weather?['weather_category'], fallback: '');
  }

  Future<void> _goToRecommendationScreen() async {
    if (widget.isGuest) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GenderScreen(
            fullName: 'Guest',
            birthDate: DateTime(2000, 1, 1),
            isGuest: true,
            guestWeather: _weather,
            confirmLogoutOnExit: widget.confirmLogoutOnExit,
          ),
        ),
      );
      return;
    }

    try {
      _log(
        '_goToRecommendationScreen weather='
        'city=${_weather?['city']} condition=${_weather?['condition']} '
        'temperature=${_weather?['temperature']} '
        'precipitation=${_weather?['precipitation']} '
        'style=${widget.selectedStyle} color=${widget.selectedColor} '
        'gender=${widget.selectedGender}',
      );
      final recommendation =
          await OutfitRecommendationService.buildRecommendation(
            selectedGender: widget.selectedGender,
            selectedColor: widget.selectedColor,
            selectedStyle: widget.selectedStyle,
            weather: _weather ?? <String, dynamic>{},
          );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OutfitRecommendationScreen(
            isGuest: widget.isGuest,
            data: OutfitRecommendationData.fromRecommendationMap(
              recommendation,
              gender: widget.selectedGender,
              color: widget.selectedColor,
              style: widget.selectedStyle,
              weather: (_weather?['condition'] ?? _weather?['weather_category'])
                  ?.toString(),
            ),
            confirmLogoutOnExit: widget.confirmLogoutOnExit,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  IconData _conditionIcon() {
    final condition = _conditionText().toLowerCase();
    final hasPrecipitation = _weather?['precipitation'] == true;

    if (condition.contains('thunder') || condition.contains('storm')) {
      return Icons.flash_on_rounded;
    }
    if (condition.contains('snow') ||
        condition.contains('ice') ||
        condition.contains('blizzard')) {
      return Icons.ac_unit_rounded;
    }
    if (hasPrecipitation ||
        condition.contains('rain') ||
        condition.contains('drizzle') ||
        condition.contains('shower') ||
        condition.contains('sleet') ||
        condition.contains('hail')) {
      return Icons.water_drop_rounded;
    }
    if (condition.contains('cloud') ||
        condition.contains('overcast') ||
        condition.contains('mist') ||
        condition.contains('fog')) {
      return Icons.cloud_rounded;
    }
    if (condition.contains('sun') ||
        condition.contains('clear') ||
        condition.contains('fair')) {
      return Icons.wb_sunny_rounded;
    }

    return Icons.wb_cloudy_rounded;
  }

  Color _conditionAccent() {
    final icon = _conditionIcon();

    if (icon == Icons.wb_sunny_rounded) return const Color(0xFFFFC247);
    if (icon == Icons.water_drop_rounded) return const Color(0xFF5DA9FF);
    if (icon == Icons.cloud_rounded || icon == Icons.wb_cloudy_rounded) {
      return const Color(0xFF8DA8C8);
    }
    if (icon == Icons.ac_unit_rounded) return const Color(0xFF7ED6F7);
    if (icon == Icons.flash_on_rounded) return const Color(0xFFFFB545);
    return _pink;
  }

  List<Color> _heroGradient() {
    final icon = _conditionIcon();

    if (icon == Icons.wb_sunny_rounded) {
      return const [_navy, _navySoft, Color(0xFF4F7CB0)];
    }
    if (icon == Icons.water_drop_rounded) {
      return const [_navy, Color(0xFF245486), Color(0xFF4E8FCA)];
    }
    if (icon == Icons.flash_on_rounded) {
      return const [_navy, Color(0xFF384E92), Color(0xFF6A74C7)];
    }
    if (icon == Icons.ac_unit_rounded) {
      return const [_navy, Color(0xFF315E8A), Color(0xFF73A8CF)];
    }
    return const [_navy, _navySoft];
  }

  String _smartSummary() {
    final category = _weatherCategory().toLowerCase();
    final condition = _conditionText().toLowerCase();
    final temperature = _toDouble(_weather?['temperature']);

    if (condition.contains('storm') || condition.contains('thunder')) {
      return 'Stormy conditions call for extra coverage and sturdier pieces.';
    }
    if (condition.contains('rain') || condition.contains('drizzle')) {
      return 'Rain is in play, so lighter layers and practical choices will help.';
    }
    if (condition.contains('cloud') || condition.contains('fog')) {
      return 'Soft weather today. This is a nice setup for balanced outfit styling.';
    }
    if (category == 'hot' || (temperature != null && temperature >= 28)) {
      return 'Warm weather ahead. Breathable fabrics and lighter shapes will work best.';
    }
    if (category == 'cold' || (temperature != null && temperature <= 16)) {
      return 'Cooler air today. A smart layered outfit will feel more comfortable.';
    }
    return 'Conditions look steady. This is a good day for a clean, versatile outfit.';
  }

  String _temperatureNarrative() {
    final temperature = _toDouble(_weather?['temperature']);
    if (temperature == null) return 'Weather overview';
    if (temperature >= 30) return 'Very warm';
    if (temperature >= 24) return 'Comfortably warm';
    if (temperature >= 18) return 'Mild and easy';
    if (temperature >= 12) return 'A bit cool';
    return 'Quite chilly';
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        Container(color: _mist),
        Positioned(
          top: -70,
          right: -40,
          child: _GlowOrb(size: 220, color: _pink.withValues(alpha: 0.14)),
        ),
        Positioned(
          top: 120,
          left: -80,
          child: _GlowOrb(size: 180, color: _navySoft.withValues(alpha: 0.10)),
        ),
        Positioned(
          bottom: -110,
          right: -50,
          child: _GlowOrb(size: 260, color: _coral.withValues(alpha: 0.14)),
        ),
      ],
    );
  }

  Widget _buildPageShell({required Widget child, bool scrollable = true}) {
    return Scaffold(
      backgroundColor: _mist,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: scrollable
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                    child: child,
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                    child: child,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: IconButton(
        onPressed: _goBack,
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _navy,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildTopTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: _pink, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: _navy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(String tag) {
    return Row(
      children: [_buildBackButton(), const Spacer(), _buildTopTag(tag)],
    );
  }

  Widget _buildSurfaceCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(24)),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionLabel(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _mist,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: _pink),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: const TextStyle(color: _navy, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    if (!widget.showSearchSection) return const SizedBox.shrink();

    return _buildSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('City search', icon: Icons.travel_explore_rounded),
          const SizedBox(height: 12),
          const Text(
            'Find your city',
            style: TextStyle(
              color: _navy,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Search once and we will turn the forecast into outfit-ready insight.',
            style: TextStyle(
              color: _navy.withValues(alpha: 0.62),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _cityController,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Enter city name',
              hintStyle: const TextStyle(color: Color(0xFF8D8D8D)),
              prefixIcon: const Icon(Icons.search_rounded, color: _navySoft),
              fillColor: _mist,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: _navy.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _pink, width: 1.2),
              ),
            ),
            onSubmitted: (_) => _searchCities(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSearching ? null : _searchCities,
              icon: _isSearching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.travel_explore_rounded),
              label: Text(_isSearching ? 'Searching...' : 'Search Cities'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _isLocating ? null : _handleAllowLocation,
              style: OutlinedButton.styleFrom(
                foregroundColor: _navy,
                backgroundColor: _mist,
                side: BorderSide(color: _navy.withValues(alpha: 0.10)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: _isLocating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _navy,
                      ),
                    )
                  : const Icon(Icons.my_location_rounded),
              label: Text(
                _isLocating ? 'Checking location...' : 'Allow location',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCitiesList() {
    if (_cities.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: _buildSurfaceCard(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _cities.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: _navy.withValues(alpha: 0.08)),
          itemBuilder: (context, index) {
            final city = _cities[index];
            final cityName = _value(city['name']);
            final region = _value(city['region'], fallback: '');
            final country = _value(city['country'], fallback: '');
            final lat = city['lat'];
            final lon = city['lon'];

            final subtitle = [
              region,
              country,
            ].where((value) => value.trim().isNotEmpty).join(', ');

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _mist,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_city_rounded,
                  color: _navySoft,
                ),
              ),
              title: Text(
                cityName,
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: subtitle.isEmpty
                  ? null
                  : Text(
                      subtitle,
                      style: TextStyle(
                        color: _navy.withValues(alpha: 0.62),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
              trailing: const Icon(Icons.north_east_rounded, color: _navySoft),
              onTap: () {
                _cityController.text = cityName;

                if (lat != null && lon != null) {
                  _getCurrentWeather(query: '$lat,$lon');
                } else {
                  _getCurrentWeather(query: cityName);
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _buildSurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.wb_sunny_rounded,
                  color: Color(0xFFFFC247),
                  size: 24,
                ),
                SizedBox(width: 8),
                Icon(Icons.cloud_rounded, color: _navySoft, size: 28),
                SizedBox(width: 8),
                Icon(
                  Icons.water_drop_rounded,
                  color: Color(0xFF6BAFEF),
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _navy.withValues(alpha: 0.12),
                    _pink.withValues(alpha: 0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(Icons.radar_rounded, size: 46, color: _navy),
            ),
            const SizedBox(height: 14),
            const Text(
              'Search a city and unlock the weather story',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _navy,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We will surface the important signals fast so the next outfit recommendation feels much smarter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _navy.withValues(alpha: 0.62),
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _mist,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _navySoft, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _navy,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherHero() {
    final city = _value(_weather?['city']);
    final country = _value(_weather?['country']);
    final condition = _conditionText();
    final temperature = _formatTemp(_weather?['temperature']);
    final precipitation = _weather?['precipitation'] == true
        ? 'Rain likely'
        : 'Dry air';
    final category = _weatherCategory().isEmpty
        ? 'Weather'
        : _weatherCategory();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _heroGradient(),
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.20),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Live conditions', icon: Icons.cloud_outlined),
          const SizedBox(height: 12),
          Text(
            '$city, $country',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
              height: 1.04,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _smartSummary(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _temperatureNarrative(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.76),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: temperature,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                            TextSpan(
                              text: '\u00B0C',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.90),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        condition,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildHeroBadge(category.toUpperCase()),
                          _buildHeroBadge(precipitation.toUpperCase()),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: _conditionAccent(),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(_conditionIcon(), color: Colors.white, size: 38),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: 305,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_coral, _pink],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _coral.withValues(alpha: 0.26),
                      blurRadius: 18,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _goToRecommendationScreen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Get Smart Outfit Recommendation',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useVerticalLayout =
                    constraints.maxWidth < 320 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.05;

                if (useVerticalLayout) {
                  return Column(
                    children: [
                      _buildHeroInsight(
                        title: 'Style mood',
                        value: category,
                        icon: Icons.auto_awesome_rounded,
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      _buildHeroInsight(
                        title: 'Best move',
                        value: precipitation == 'Rain likely'
                            ? 'Layer smart'
                            : 'Keep it light',
                        icon: Icons.checkroom_outlined,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: _buildHeroInsight(
                        title: 'Style mood',
                        value: category,
                        icon: Icons.auto_awesome_rounded,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 44,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    Expanded(
                      child: _buildHeroInsight(
                        title: 'Best move',
                        value: precipitation == 'Rain likely'
                            ? 'Layer smart'
                            : 'Keep it light',
                        icon: Icons.checkroom_outlined,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroInsight({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildSearchScreen() {
    final needsScroll = _cities.isNotEmpty || _errorMessage != null;

    return _buildPageShell(
      scrollable: needsScroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar('Smart forecast'),
          const SizedBox(height: 18),
          const Text(
            'Weather',
            style: TextStyle(
              color: _navy,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.04,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search a city, review live conditions, and move into outfit suggestions with the same style language as the rest of the app.',
            style: TextStyle(
              color: _navy.withValues(alpha: 0.64),
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          _buildSearchSection(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _coral.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _coral.withValues(alpha: 0.16)),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: _coral,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          _buildCitiesList(),
          if (_weather == null) _buildEmptySearchState(),
        ],
      ),
    );
  }

  Widget _buildWeatherScreen() {
    final humidity = _value(_weather?['humidity']);
    final wind = _value(_weather?['wind_kph']);
    final precipitation = _weather?['precipitation'] == true ? 'Yes' : 'No';

    return _buildPageShell(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar('Live conditions'),
          const SizedBox(height: 16),
          _buildWeatherHero(),
          const SizedBox(height: 12),
          Column(
            children: [
              _buildMetricCard(
                icon: Icons.grain_rounded,
                title: 'Precipitation',
                value: precipitation,
              ),
              const SizedBox(height: 10),
              _buildMetricCard(
                icon: Icons.water_drop_outlined,
                title: 'Humidity',
                value: '$humidity%',
              ),
              const SizedBox(height: 10),
              _buildMetricCard(
                icon: Icons.air_rounded,
                title: 'Wind',
                value: '$wind km/h',
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = _weather != null
        ? _buildWeatherScreen()
        : _buildSearchScreen();

    return PopScope(
      canPop: !widget.confirmLogoutOnExit,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _goBack();
      },
      child: child,
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
