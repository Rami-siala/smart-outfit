import 'package:flutter/material.dart';
import 'package:frontend/models/outfit_recommendation_data.dart';
import 'package:frontend/screens/ai_generated_outfit_screen.dart';
import 'package:frontend/screens/ai_outfit_history_screen.dart';
import 'package:frontend/screens/auth/auth_choice_screen.dart';
import 'package:frontend/screens/auth/sign_in_screen.dart';
import 'package:frontend/screens/auth/sign_up_screen.dart';
import 'package:frontend/screens/change_outfit_preferences_screen.dart';
import 'package:frontend/screens/location_weather_details_screen.dart';
import 'package:frontend/screens/wardrobe_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/outfit_recommendation_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _navy = Color(0xFF173B6D);
const Color _navySoft = Color(0xFF2B568D);
const Color _mist = Color(0xFFF3F7FB);
const Color _skyAccent = Color(0xFF8FCBFF);
const Color _pink = Color(0xFFD970C4);
const Color _coral = Color(0xFFE85B5B);

enum _TimelineMode { hourly, daily }

class OutfitRecommendationScreen extends StatefulWidget {
  final OutfitRecommendationData? data;
  final String? selectedAiImageUrl;
  final String? imagePath;
  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? temperature;
  final String? precipitation;
  final String? humidity;
  final String? wind;
  final String? style;
  final String? color;
  final String? gender;
  final String? weather;
  final bool confirmLogoutOnExit;
  final bool isGuest;

  const OutfitRecommendationScreen({
    super.key,
    this.data,
    this.selectedAiImageUrl,
    this.imagePath,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    this.temperature,
    this.precipitation,
    this.humidity,
    this.wind,
    this.style,
    this.color,
    this.gender,
    this.weather,
    this.confirmLogoutOnExit = false,
    this.isGuest = false,
  });

  @override
  State<OutfitRecommendationScreen> createState() =>
      _OutfitRecommendationScreenState();
}

class _OutfitRecommendationScreenState
    extends State<OutfitRecommendationScreen> {
  final List<String> _hourlyLabels = const [
    '5:30 AM',
    '6:30 AM',
    '7:30 AM',
    '8:30 AM',
    '9:30 AM',
    '10:30 AM',
    '11:30 AM',
    '12:30 PM',
    '1:30 PM',
    '2:30 PM',
    '3:30 PM',
    '4:30 PM',
    '5:30 PM',
  ];

  String get todayDate =>
      DateFormat('EEEE, dd MMM yyyy').format(DateTime.now());
  List<String> get _dailyLabels {
    final now = DateTime.now();
    return List<String>.generate(7, (index) {
      final day = now.add(Duration(days: index));
      return DateFormat('EEEE').format(day);
    });
  }

  int get _availableDailyForecastCount {
    final daily = _forecastData?['daily'];
    if (daily is List) {
      return daily.length.clamp(0, 7);
    }
    return 0;
  }

  int _selectedHourlyIndex = 4;
  int _selectedDailyIndex = 0;
  _TimelineMode _timelineMode = _TimelineMode.hourly;
  bool _isAiButtonHovered = false;
  bool _isAiButtonPressed = false;
  bool _isGeneratingAI = false;
  bool _isTimelineRefreshing = false;
  String? _aiErrorMessage;
  String? _selectedAiImageUrl;
  String? _hoveredHeaderBadge;
  Map<String, dynamic>? _forecastData;
  late OutfitRecommendationData _data;

  void _log(String message) {
    debugPrint('[OutfitRecommendationScreen] $message');
  }

  List<String> get _activeTimelineLabels =>
      _timelineMode == _TimelineMode.hourly ? _hourlyLabels : _dailyLabels;

  int get _activeTimelineIndex =>
      (_timelineMode == _TimelineMode.hourly
              ? _selectedHourlyIndex
              : _selectedDailyIndex)
          .clamp(0, _activeTimelineLabels.length - 1);

  String get _activeTimelineValue =>
      _activeTimelineLabels[_activeTimelineIndex];

  void _setTimelineIndex(int index) {
    if (_timelineMode == _TimelineMode.daily && _isDailyIndexLocked(index)) {
      _showForecastUpgradeAlert();
      return;
    }

    setState(() {
      if (_timelineMode == _TimelineMode.hourly) {
        _selectedHourlyIndex = index;
      } else {
        _selectedDailyIndex = index;
      }
    });

    _refreshRecommendationForSelection();
  }

  bool _isDailyIndexLocked(int index) {
    return index >= _availableDailyForecastCount;
  }

  Future<void> _showForecastUpgradeAlert() async {
    final unlockedDays = _availableDailyForecastCount;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Move to Pro',
          style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
        ),
        content: Text(
          unlockedDays > 0
              ? 'Your current weather plan unlocks $unlockedDays real forecast day${unlockedDays == 1 ? '' : 's'}. Upgrade to Pro to preview the full 7-day outfit timeline.'
              : 'Upgrade to Pro to unlock the full 7-day outfit timeline.',
          style: const TextStyle(color: _navy, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Later',
              style: TextStyle(color: _navySoft, fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String get _weatherQuery {
    if (_data.latitude != null && _data.longitude != null) {
      return '${_data.latitude},${_data.longitude}';
    }

    final city = _data.city.trim();
    final country = _data.country.trim();
    if (city.isEmpty) return country;
    if (country.isEmpty) return city;
    return '$city, $country';
  }

  Future<void> _loadForecastData() async {
    final query = _weatherQuery;
    if (query.isEmpty) return;

    final forecast = await ApiService.getWeatherForecast(query: query, days: 7);
    _forecastData = forecast;
  }

  Future<void> _refreshRecommendationForSelection({
    bool forceForecastReload = false,
  }) async {
    try {
      if (forceForecastReload || _forecastData == null) {
        setState(() {
          _isTimelineRefreshing = true;
        });
        await _loadForecastData();
      }

      final weather = _selectedWeatherSnapshot();
      if (weather == null) {
        if (mounted) {
          setState(() {
            _isTimelineRefreshing = false;
          });
        }
        return;
      }

      final recommendation = await OutfitRecommendationService.buildRecommendation(
        selectedGender:
            (_data.gender ?? OutfitRecommendationData.defaultGender),
        selectedColor: (_data.color ?? OutfitRecommendationData.defaultColor),
        selectedStyle: (_data.style ?? OutfitRecommendationData.defaultStyle),
        weather: weather,
        selectionKey:
            '${_timelineMode.name}|$_activeTimelineValue|${weather['condition'] ?? weather['weather_category'] ?? ''}',
      );

      if (!mounted) return;

      setState(() {
        _data = _data.copyWith(
          imagePath: recommendation['imagePath'],
          city: recommendation['city'],
          country: recommendation['country'],
          latitude: _toDouble(recommendation['latitude']),
          longitude: _toDouble(recommendation['longitude']),
          temperature: recommendation['temperature'],
          precipitation: recommendation['precipitation'],
          humidity: recommendation['humidity'],
          wind: recommendation['wind'],
          weather: (weather['condition'] ?? weather['weather_category'] ?? '')
              .toString(),
        );
        _isTimelineRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _isTimelineRefreshing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Map<String, dynamic>? _selectedWeatherSnapshot() {
    return _timelineMode == _TimelineMode.hourly
        ? _selectedHourlyWeather()
        : _selectedDailyWeather();
  }

  Map<String, dynamic>? _selectedHourlyWeather() {
    final hourly = _forecastData?['hourly'];
    final city = _forecastData?['city'] ?? _data.city;
    final country = _forecastData?['country'] ?? _data.country;
    final latitude = _forecastData?['latitude'] ?? _data.latitude;
    final longitude = _forecastData?['longitude'] ?? _data.longitude;

    if (hourly is! List || hourly.isEmpty) {
      return _fallbackWeatherSnapshot(
        city: city,
        country: country,
        latitude: latitude,
        longitude: longitude,
      );
    }

    final selectedMinutes = _parseTimelineMinutes(_activeTimelineValue);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    Map<String, dynamic>? best;
    var bestDistance = 1 << 30;

    for (final item in hourly) {
      if (item is! Map) continue;
      final hourMap = Map<String, dynamic>.from(item);
      final timeText = hourMap['time']?.toString() ?? '';
      if (!timeText.startsWith(today)) continue;

      final parsedTime = DateTime.tryParse(timeText.replaceFirst(' ', 'T'));
      if (parsedTime == null) continue;

      final itemMinutes = parsedTime.hour * 60 + parsedTime.minute;
      final distance = (itemMinutes - selectedMinutes).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = hourMap;
      }
    }

    final resolved = best ?? Map<String, dynamic>.from(hourly.first as Map);
    return {
      ...resolved,
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Map<String, dynamic>? _selectedDailyWeather() {
    final daily = _forecastData?['daily'];
    final city = _forecastData?['city'] ?? _data.city;
    final country = _forecastData?['country'] ?? _data.country;
    final latitude = _forecastData?['latitude'] ?? _data.latitude;
    final longitude = _forecastData?['longitude'] ?? _data.longitude;

    if (daily is! List || daily.isEmpty) {
      return _fallbackWeatherSnapshot(
        city: city,
        country: country,
        latitude: latitude,
        longitude: longitude,
      );
    }

    final index = _activeTimelineIndex.clamp(0, daily.length - 1);
    final item = daily[index];
    if (item is! Map) {
      return _fallbackWeatherSnapshot(
        city: city,
        country: country,
        latitude: latitude,
        longitude: longitude,
      );
    }

    return {
      ...Map<String, dynamic>.from(item),
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Map<String, dynamic> _fallbackWeatherSnapshot({
    required dynamic city,
    required dynamic country,
    required dynamic latitude,
    required dynamic longitude,
  }) {
    final temperature =
        double.tryParse(
          _data.temperature.replaceAll('Â°', '').replaceAll('C', '').trim(),
        ) ??
        0;
    final humidity =
        int.tryParse(_data.humidity.replaceAll('%', '').trim()) ?? 0;
    final wind =
        double.tryParse(_data.wind.replaceAll(' km/h', '').trim()) ?? 0;
    final weatherLabel = _resolveWeatherLabel() ?? _data.weather ?? 'Clear';
    final precipitation = _data.precipitation.trim().toLowerCase() == 'yes';

    return {
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'temperature': temperature,
      'condition': weatherLabel,
      'humidity': humidity,
      'wind_kph': wind,
      'precipitation': precipitation,
      'weather_category': temperature > 25
          ? 'hot'
          : temperature <= 15
          ? 'cold'
          : 'normal',
    };
  }

  int _parseTimelineMinutes(String label) {
    final parsed = DateFormat('h:mm a').parse(label);
    return parsed.hour * 60 + parsed.minute;
  }

  @override
  void initState() {
    super.initState();
    _data = widget.data ?? _legacyDataFromWidget();
    final initialAiImageUrl = widget.selectedAiImageUrl?.trim();
    _selectedAiImageUrl =
        initialAiImageUrl != null && initialAiImageUrl.isNotEmpty
        ? initialAiImageUrl
        : null;
    _log(
      'initState imagePath=${_data.imagePath} '
      'city=${_data.city} weather=${_data.weather} '
      'temperature=${_data.temperature} precipitation=${_data.precipitation}',
    );
    _resolveBadgeData();
  }

  OutfitRecommendationData _legacyDataFromWidget() {
    return OutfitRecommendationData(
      imagePath: widget.imagePath ?? '',
      city: widget.city ?? '',
      country: widget.country ?? '',
      latitude: widget.latitude,
      longitude: widget.longitude,
      temperature: widget.temperature ?? '',
      precipitation: widget.precipitation ?? 'No',
      humidity: widget.humidity ?? '-',
      wind: widget.wind ?? '-',
      style: widget.style,
      color: widget.color,
      gender: widget.gender,
      weather: widget.weather,
    );
  }

  Future<void> _resolveBadgeData() async {
    try {
      final resolved = await _data.resolveBadges();
      if (!mounted) return;

      setState(() {
        _data = resolved;
      });
    } catch (_) {
      // Keep the screen usable with the existing payload if profile/preferences
      // cannot be loaded for badge fallbacks.
    }

    await _refreshRecommendationForSelection(forceForecastReload: true);
  }

  void _openChangeScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChangeOutfitPreferencesScreen(
          isGuest: widget.isGuest,
          initialWeather: {
            'city': _data.city,
            'country': _data.country,
            'latitude': _data.latitude,
            'longitude': _data.longitude,
            'temperature': _data.temperature,
            'precipitation': _data.precipitation == 'Yes',
            'humidity': _data.humidity.replaceAll('%', ''),
            'wind_kph': _data.wind.replaceAll(' km/h', ''),
          },
          confirmLogoutOnExit: widget.confirmLogoutOnExit,
          currentOutfit: {
            'imagePath': _data.imagePath,
            'selectedAiImageUrl': _selectedAiImageUrl ?? '',
            'city': _data.city,
            'country': _data.country,
            'latitude': _data.latitude?.toString() ?? '',
            'longitude': _data.longitude?.toString() ?? '',
            'temperature': _data.temperature,
            'precipitation': _data.precipitation,
            'humidity': _data.humidity,
            'wind': _data.wind,
            'style': _data.style ?? '',
            'color': _data.color ?? '',
            'gender': _data.gender ?? '',
            'weather': _data.weather ?? '',
          },
        ),
      ),
    );
  }

  void _openWardrobeScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WardrobeScreen(isGuest: widget.isGuest),
      ),
    );
  }

  void _openLocationDetails() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationWeatherDetailsScreen(
          city: _data.city,
          country: _data.country,
          temperature: _data.temperature,
          weather: _data.weather ?? _resolveWeatherLabel() ?? '',
          precipitation: _data.precipitation,
          humidity: _data.humidity,
          wind: _data.wind,
          dateLabel: todayDate,
          forecastData: _forecastData,
        ),
      ),
    );
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

  Future<void> _handleBack() async {
    if (widget.isGuest) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthChoiceScreen()),
        (route) => false,
      );
      return;
    }

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

  Future<void> _generateWithIA() async {
    if (_isGeneratingAI) return;
    if (widget.isGuest) {
      await _showGuestAiDialog();
      return;
    }

    setState(() {
      _isGeneratingAI = true;
      _aiErrorMessage = null;
    });

    try {
      final profile = await ApiService.getMyProfile();

      final String? birthDate = profile?['birth_date']?.toString();
      final String? skinTone = profile?['skin_tone']?.toString();
      final String? bodyShape = profile?['body_shape']?.toString();

      final double? height = _toDouble(profile?['height']);
      final double? weight = _toDouble(profile?['weight']);

      final weatherLabel = _resolveWeatherLabel() ?? _data.weather ?? 'Clear';
      final timeOfDayContext = _timelineMode == _TimelineMode.hourly
          ? _activeTimelineValue
          : 'daytime';
      final prefs = await SharedPreferences.getInstance();
      final wardrobeId = prefs.getInt('selected_ai_wardrobe_id');
      final result = await ApiService.generateOutfitImage(
        wardrobeId: wardrobeId,
        city: _data.city,
        country: _data.country,
        temperature: _data.temperature,
        weather: weatherLabel,
        precipitation: _data.precipitation,
        humidity: _data.humidity,
        wind: _data.wind,
        timeOfDay: timeOfDayContext,
        style: _data.style,
        color: _data.color,
        gender: _data.gender,
        birthDate: birthDate,
        height: height,
        weight: weight,
        bodyShape: bodyShape,
        skinTone: skinTone,
      );

      final warning = result['warning']?.toString();
      final imageUrl = result['imageUrl']?.toString();
      final usedSelectedWardrobeItems =
          result['usedSelectedWardrobeItems'] == true;
      final wardrobeItemsUsed =
          (result['wardrobeItemsUsed'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const <String>[];
      final wardrobeItemsUsedDetails =
          (result['wardrobeItemsUsedDetails'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          const <Map<String, dynamic>>[];

      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('AI image URL not found in server response');
      }

      if (!mounted) return;

      if (warning != null && warning.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(warning)));
      }

      final selectedImageUrl = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => AiGeneratedOutfitScreen(
            imageUrl: imageUrl,
            city: _data.city,
            country: _data.country,
            temperature: _data.temperature,
            weather: weatherLabel,
            style: _data.style ?? '',
            color: _data.color ?? '',
            gender: _data.gender ?? '',
            bodyShape: bodyShape ?? '',
            skinTone: skinTone ?? '',
            precipitation: _data.precipitation,
            humidity: _data.humidity,
            wind: _data.wind,
            timeOfDay: timeOfDayContext,
            birthDate: birthDate,
            height: height,
            weight: weight,
            usedSelectedWardrobeItems: usedSelectedWardrobeItems,
            wardrobeItemsUsed: wardrobeItemsUsed,
            wardrobeItemsUsedDetails: wardrobeItemsUsedDetails,
            wardrobeWarning: warning,
          ),
        ),
      );

      if (!mounted) return;

      if (selectedImageUrl != null && selectedImageUrl.isNotEmpty) {
        setState(() {
          _selectedAiImageUrl = selectedImageUrl;
        });
      }
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _aiErrorMessage = message;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_aiErrorMessage ?? 'Failed to generate AI image'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingAI = false;
        });
      }
    }
  }

  Future<void> _showGuestAiDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create an account'),
        content: const Text('You need an account to use AI outfit generation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SignUpScreen()));
            },
            child: const Text('Sign Up'),
          ),
        ],
      ),
    );
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  bool get _hasSelectedAiImage =>
      _selectedAiImageUrl != null && _selectedAiImageUrl!.trim().isNotEmpty;

  Widget _buildRecommendationImage({required bool compactLayout}) {
    if (_hasSelectedAiImage) {
      final imageUrl = _selectedAiImageUrl!.trim();
      return Image.network(
        imageUrl,
        key: ValueKey(imageUrl),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) {
          _log(
            'Image.network error imageUrl=$imageUrl error=$error. Falling back to asset.',
          );
          return _buildDefaultRecommendationImage(compactLayout: compactLayout);
        },
      );
    }

    return _buildDefaultRecommendationImage(compactLayout: compactLayout);
  }

  Widget _buildDefaultRecommendationImage({required bool compactLayout}) {
    return Image.asset(
      _data.imagePath,
      key: ValueKey(_data.imagePath),
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (context, error, stackTrace) {
        _log('Image.asset error imagePath=${_data.imagePath} error=$error');
        return const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_navySoft, _navy],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isGuest || !widget.confirmLogoutOnExit,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: _mist,
        appBar: AppBar(
          backgroundColor: _mist,
          surfaceTintColor: _mist,
          elevation: 0,
          foregroundColor: _navy,
          titleSpacing: 4,
          leading: IconButton(
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back),
          ),
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Recommended Outfit',
              maxLines: 1,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          actions: [
            if (!widget.isGuest)
              IconButton(
                tooltip: 'AI History',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AiOutfitHistoryScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.history_rounded),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                height: 40,
                child: OutlinedButton(
                  onPressed: _openWardrobeScreen,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _navy.withValues(alpha: 0.18)),
                    foregroundColor: _navy,
                    minimumSize: const Size(40, 40),
                    padding: const EdgeInsets.all(0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: const Icon(Icons.checkroom_outlined, size: 18),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openChangeScreen,
                  borderRadius: BorderRadius.circular(22),
                  child: Ink(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_navy, _navySoft],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: _navy.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.tune_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(right: 14, bottom: 88),
          child: _buildFloatingAiButton(),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFEAF1F8)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Column(
                children: [
                  _buildWeatherHeader(compactLayout: true),
                  const SizedBox(height: 8),
                  Expanded(child: _buildOutfitHero(compactLayout: true)),
                  const SizedBox(height: 8),
                  _buildWeatherDetails(compactLayout: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherHeader({bool compactLayout = false}) {
    final styleLabel = _data.style?.trim().isNotEmpty == true
        ? _toTitleCase(_data.style!)
        : null;
    final colorLabel = _data.color?.trim().isNotEmpty == true
        ? _toTitleCase(_data.color!)
        : null;
    final weatherLabel = _resolveWeatherLabel();
    final genderLabel = _data.gender?.trim().isNotEmpty == true
        ? _toTitleCase(_data.gender!)
        : null;
    final headerTags = <Map<String, dynamic>>[
      if (styleLabel != null)
        {'label': styleLabel, 'icon': Icons.checkroom_rounded},
      if (colorLabel != null)
        {'label': colorLabel, 'icon': Icons.palette_outlined},
      if (weatherLabel != null)
        {
          'label': _weatherBadgeLabel(weatherLabel),
          'icon': _weatherBadgeIcon(weatherLabel),
          'isWeather': true,
        },
      if (genderLabel != null)
        {'label': genderLabel, 'icon': Icons.person_outline_rounded},
    ];
    final locationLabel = [
      _data.city.trim(),
      _compactCountryName(_data.country.trim()),
    ].where((value) => value.isNotEmpty).join(', ');
    final headerLocation = locationLabel.isEmpty
        ? 'Current location'
        : locationLabel;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        if (compactLayout) {
          final resolvedWeatherLabel = _weatherBadgeLabel(
            weatherLabel ?? 'Weather',
          );
          final resolvedWeatherIcon = _weatherBadgeIcon(
            weatherLabel ?? 'Weather',
          );

          return Container(
            constraints: const BoxConstraints(minHeight: 100, maxHeight: 108),
            padding: EdgeInsets.fromLTRB(
              isCompact ? 12 : 14,
              10,
              isCompact ? 12 : 14,
              10,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D2450),
                  Color(0xFF173B6D),
                  Color(0xFF295A99),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: _navy.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 30,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: _data.temperature,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isCompact ? 24 : 26,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              TextSpan(
                                text: ' °C',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: isCompact ? 11 : 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            child: Icon(
                              resolvedWeatherIcon,
                              size: 17,
                              color: _skyAccent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              resolvedWeatherLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isCompact ? 13.2 : 14.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  flex: 35,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (styleLabel != null)
                        _compactDetailRow(
                          icon: Icons.checkroom_rounded,
                          label: styleLabel,
                        ),
                      if (styleLabel != null &&
                          (genderLabel != null || colorLabel != null))
                        const SizedBox(height: 8),
                      if (genderLabel != null)
                        _compactDetailRow(
                          icon: Icons.person_outline_rounded,
                          label: genderLabel,
                        ),
                      if (genderLabel != null && colorLabel != null)
                        const SizedBox(height: 8),
                      if (colorLabel != null)
                        _compactDetailRow(
                          icon: Icons.palette_outlined,
                          label: colorLabel,
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  flex: 35,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _compactMetaRow(
                        icon: Icons.location_on_outlined,
                        label: headerLocation,
                        allowWrap: true,
                        onTap: _openLocationDetails,
                      ),
                      const SizedBox(height: 10),
                      _compactMetaRow(
                        icon: Icons.event_outlined,
                        label: todayDate,
                        allowWrap: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        final rightColumnWidth = compactLayout
            ? (isCompact ? 108.0 : 120.0)
            : (isCompact ? 112.0 : 128.0);
        final horizontalPadding = compactLayout
            ? (isCompact ? 8.0 : 9.0)
            : (isCompact ? 9.0 : 10.0);
        final verticalPadding = compactLayout ? 7.0 : (isCompact ? 7.0 : 8.0);
        final titleSize = compactLayout
            ? (isCompact ? 11.8 : 12.6)
            : (isCompact ? 12.2 : 13.2);
        final tempSize = compactLayout
            ? (isCompact ? 18.0 : 21.0)
            : (isCompact ? 21.0 : 24.0);
        final unitSize = compactLayout ? 7.8 : (isCompact ? 8.0 : 8.8);
        final dateSize = compactLayout ? 7.8 : (isCompact ? 8.0 : 8.8);
        final pillFontSize = compactLayout
            ? (isCompact ? 8.3 : 8.8)
            : (isCompact ? 8.7 : 9.4);
        final badgeSpacing = isCompact ? 2.5 : 3.0;

        return Container(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            verticalPadding,
            horizontalPadding,
            verticalPadding,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_navy, _navySoft],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _navy.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -18,
                right: -8,
                child: Container(
                  width: isCompact ? 82 : 98,
                  height: isCompact ? 82 : 98,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: -28,
                left: 68,
                child: Container(
                  width: isCompact ? 64 : 76,
                  height: isCompact ? 64 : 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.035),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: _openLocationDetails,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                      horizontal: 2,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          width: isCompact ? 18 : 20,
                                          height: isCompact ? 18 : 20,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.14,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.location_on_rounded,
                                            color: Colors.white,
                                            size: isCompact ? 11 : 12,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            headerLocation,
                                            maxLines: 2,
                                            overflow: TextOverflow.fade,
                                            softWrap: true,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: titleSize,
                                              height: 1.05,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildTimePill(
                        isCompact: isCompact,
                        fontSize: pillFontSize,
                      ),
                    ],
                  ),
                  SizedBox(height: compactLayout ? 4 : (isCompact ? 5 : 6)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _data.temperature,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: tempSize,
                                    height: 0.95,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    'C',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.84,
                                      ),
                                      fontSize: unitSize,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              todayDate,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.76),
                                fontSize: dateSize,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (headerTags.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        SizedBox(
                          width: rightColumnWidth,
                          child: Transform.translate(
                            offset: const Offset(-2, 0),
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: badgeSpacing,
                              runSpacing: badgeSpacing,
                              children: headerTags
                                  .map(
                                    (tag) => _buildHeaderSideBadge(
                                      tag['label'] as String,
                                      icon: tag['icon'] as IconData,
                                      width:
                                          (rightColumnWidth - badgeSpacing) / 2,
                                      compact: isCompact,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimePill({required bool isCompact, required double fontSize}) {
    final isHourly = _timelineMode == _TimelineMode.hourly;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 4.5 : 5.5,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isCompact ? 17 : 19,
            height: isCompact ? 17 : 19,
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isHourly
                  ? Icons.access_time_rounded
                  : Icons.calendar_today_rounded,
              size: isCompact ? 9 : 10,
              color: _navy.withValues(alpha: 0.78),
            ),
          ),
          SizedBox(width: isCompact ? 5 : 6),
          Text(
            _activeTimelineValue,
            style: TextStyle(
              color: _navy,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSideBadge(
    String label, {
    required IconData icon,
    required double width,
    required bool compact,
  }) {
    final isHovered = _hoveredHeaderBadge == label;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hoveredHeaderBadge = label;
        });
      },
      onExit: (_) {
        setState(() {
          if (_hoveredHeaderBadge == label) {
            _hoveredHeaderBadge = null;
          }
        });
      },
      child: AnimatedScale(
        scale: isHovered ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          width: width,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 5.5 : 6.5,
            vertical: compact ? 4 : 4.5,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isHovered ? 0.28 : 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: isHovered ? 0.22 : 0.08),
            ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: compact ? 10 : 11,
                color: Colors.white.withValues(alpha: isHovered ? 1 : 0.92),
              ),
              SizedBox(width: compact ? 3 : 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 7.6 : 8.1,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _weatherBadgeLabel(String label) {
    final normalized = label.trim().toLowerCase();

    if (normalized.contains('rain')) return 'Rainy';
    if (normalized.contains('overcast')) return 'Overcast';
    if (normalized.contains('cloud')) return 'Cloudy';
    if (normalized.contains('sun') || normalized.contains('clear')) {
      return 'Sunny';
    }

    return label;
  }

  IconData _weatherBadgeIcon(String label) {
    final normalized = label.trim().toLowerCase();

    if (normalized.contains('rain')) return Icons.umbrella_outlined;
    if (normalized.contains('cloud')) return Icons.cloud_outlined;
    if (normalized.contains('sun') || normalized.contains('clear')) {
      return Icons.wb_sunny_outlined;
    }

    return Icons.wb_cloudy_outlined;
  }

  String _compactCountryName(String value) {
    final normalized = value.trim().toLowerCase();

    if (normalized == 'united states of america') return 'USA';
    if (normalized == 'united kingdom') return 'UK';
    if (normalized == 'united arab emirates') return 'UAE';

    return value;
  }

  String _toTitleCase(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    return words
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String? _resolveWeatherLabel() {
    final temp = double.tryParse(
      _data.temperature.replaceAll('°', '').replaceAll('C', '').trim(),
    );

    final weather = _data.weather?.trim().toLowerCase() ?? '';
    final precipitation = _data.precipitation.trim().toLowerCase();

    if (weather.contains('sun') ||
        weather.contains('clear') ||
        weather.contains('fair')) {
      return 'Sunny';
    }

    if (temp != null && temp > 25) {
      if (precipitation == 'yes' ||
          weather.contains('rain') ||
          weather.contains('drizzle') ||
          weather.contains('shower')) {
        return 'Warm Rain';
      }

      return 'Sunny';
    }

    if (precipitation == 'yes' ||
        weather.contains('rain') ||
        weather.contains('drizzle') ||
        weather.contains('shower')) {
      return 'Rainy';
    }

    if (weather.contains('cloud')) return 'Cloudy';
    if (weather.contains('overcast')) return 'Overcast';

    return 'Clear';
  }

  Widget _buildOutfitHero({bool compactLayout = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 360;
            final isDaily = _timelineMode == _TimelineMode.daily;
            final timelineWidth = isDaily
                ? (compactLayout
                      ? (isCompact ? 102.0 : 112.0)
                      : (isCompact ? 118.0 : 138.0))
                : (compactLayout
                      ? (isCompact ? 88.0 : 96.0)
                      : (isCompact ? 98.0 : 112.0));
            final cardHeight = constraints.maxHeight;

            return Container(
              height: cardHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildRecommendationImage(
                        compactLayout: compactLayout,
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: compactLayout
                              ? LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  stops: const [0.0, 0.16, 0.32, 1.0],
                                  colors: [
                                    Colors.black.withValues(alpha: 0.16),
                                    Colors.black.withValues(alpha: 0.08),
                                    Colors.transparent,
                                    Colors.transparent,
                                  ],
                                )
                              : LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  stops: const [0.0, 0.28, 0.56, 1.0],
                                  colors: [
                                    _navy.withValues(alpha: 0.78),
                                    _navy.withValues(alpha: 0.38),
                                    _navy.withValues(alpha: 0.08),
                                    Colors.transparent,
                                  ],
                                ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.04),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.08),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: compactLayout ? 18 : 22,
                      bottom: compactLayout ? 18 : 22,
                      width: timelineWidth,
                      child: TimeLineSelector(
                        labels: _activeTimelineLabels,
                        selectedIndex: _activeTimelineIndex,
                        onChanged: _setTimelineIndex,
                        lockedIndices: _timelineMode == _TimelineMode.daily
                            ? Set<int>.from(
                                List<int>.generate(
                                  _activeTimelineLabels.length,
                                  (index) => index,
                                ).where(_isDailyIndexLocked),
                              )
                            : const <int>{},
                        onLockedTap: _showForecastUpgradeAlert,
                      ),
                    ),
                    Positioned(
                      top: compactLayout ? 10 : 14,
                      right: compactLayout ? 10 : 14,
                      child: _buildInlineTimelineToggle(
                        compactLayout: compactLayout,
                      ),
                    ),
                    if (_isTimelineRefreshing)
                      Positioned(
                        top: compactLayout ? 52 : 58,
                        right: compactLayout ? 10 : 14,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _navy,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFloatingAiButton() {
    final scale = _isAiButtonPressed ? 0.94 : (_isAiButtonHovered ? 1.03 : 1.0);

    return SafeArea(
      child: MouseRegion(
        onEnter: (_) {
          setState(() {
            _isAiButtonHovered = true;
          });
        },
        onExit: (_) {
          setState(() {
            _isAiButtonHovered = false;
            _isAiButtonPressed = false;
          });
        },
        child: GestureDetector(
          onTapDown: (_) {
            setState(() {
              _isAiButtonPressed = true;
            });
          },
          onTapCancel: () {
            setState(() {
              _isAiButtonPressed = false;
            });
          },
          onTapUp: (_) {
            setState(() {
              _isAiButtonPressed = false;
            });
          },
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_coral, _pink],
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                boxShadow: [
                  BoxShadow(
                    color: _coral.withValues(
                      alpha: _isAiButtonHovered ? 0.34 : 0.24,
                    ),
                    blurRadius: _isAiButtonHovered ? 28 : 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: _isGeneratingAI ? null : _generateWithIA,
                elevation: 0,
                highlightElevation: 0,
                hoverElevation: 0,
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                child: _isGeneratingAI
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineTimelineToggle({bool compactLayout = false}) {
    final isDaily = _timelineMode == _TimelineMode.daily;

    return Material(
      color: Colors.white.withValues(alpha: 0.20),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          setState(() {
            _timelineMode = isDaily
                ? _TimelineMode.hourly
                : _TimelineMode.daily;
          });
          _refreshRecommendationForSelection();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compactLayout ? 9 : 11,
            vertical: compactLayout ? 6 : 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDaily
                    ? Icons.calendar_today_rounded
                    : Icons.access_time_rounded,
                size: compactLayout ? 13 : 14,
                color: _navy,
              ),
              const SizedBox(width: 5),
              Text(
                isDaily ? 'Daily' : 'Hourly',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compactLayout ? 10.5 : 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherDetails({bool compactLayout = false}) {
    if (compactLayout) {
      return SizedBox(
        height: 56,
        child: Row(
          children: [
            Expanded(
              child: _compactWeatherChip(
                icon: Icons.umbrella_outlined,
                label: 'Precipitation',
                value: _data.precipitation,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _compactWeatherChip(
                icon: Icons.water_drop_outlined,
                label: 'Humidity',
                value: _data.humidity,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _compactWeatherChip(
                icon: Icons.air_rounded,
                label: 'Wind',
                value: _data.wind,
              ),
            ),
          ],
        ),
      );
    }

    final detailsRowHeight = compactLayout ? 78.0 : 104.0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        compactLayout ? 10 : 14,
        compactLayout ? 7 : 12,
        compactLayout ? 10 : 14,
        compactLayout ? 7 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weather details',
            style: TextStyle(
              color: _navy,
              fontSize: compactLayout ? 13.5 : 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!compactLayout) ...[
            const SizedBox(height: 4),
            Text(
              'A quick snapshot to explain why this outfit fits the moment.',
              style: TextStyle(
                color: _navy.withValues(alpha: 0.64),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          SizedBox(height: compactLayout ? 5 : 12),
          SizedBox(
            height: detailsRowHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _weatherItem(
                        icon: Icons.umbrella_outlined,
                        title: 'Precipitation',
                        value: _data.precipitation,
                        compact: compact,
                        dense: compactLayout,
                      ),
                    ),
                    SizedBox(width: compactLayout ? 8 : 10),
                    Expanded(
                      child: _weatherItem(
                        icon: Icons.water_drop_outlined,
                        title: 'Humidity',
                        value: _data.humidity,
                        compact: compact,
                        dense: compactLayout,
                      ),
                    ),
                    SizedBox(width: compactLayout ? 8 : 10),
                    Expanded(
                      child: _weatherItem(
                        icon: Icons.air_rounded,
                        title: 'Wind',
                        value: _data.wind,
                        compact: compact,
                        dense: compactLayout,
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

  Widget _weatherItem({
    required IconData icon,
    required String title,
    required String value,
    required bool compact,
    bool dense = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : (compact ? 7 : 8),
        vertical: dense ? 6 : (compact ? 9 : 10),
      ),
      decoration: BoxDecoration(
        color: _mist,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: dense ? 28 : (compact ? 38 : 42),
            height: dense ? 28 : (compact ? 38 : 42),
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(dense ? 10 : 12),
            ),
            child: Icon(
              icon,
              color: _navySoft,
              size: dense ? 16 : (compact ? 20 : 22),
            ),
          ),
          SizedBox(height: dense ? 4 : (compact ? 7 : 8)),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _navy.withValues(alpha: 0.62),
              fontSize: dense ? 8.8 : (compact ? 10 : 11),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: dense ? 2 : (compact ? 4 : 5)),
          Flexible(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _navy,
                    fontSize: dense ? 10.5 : (compact ? 12 : 14),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactDetailRow({required IconData icon, required String label}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.96),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _compactMetaRow({
    required IconData icon,
    required String label,
    bool allowWrap = false,
    VoidCallback? onTap,
  }) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: allowWrap
              ? Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.94),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                )
              : SizedBox(
                  height: 20,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.94),
                        fontSize: 14.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: content,
        ),
      ),
    );
  }

  Widget _compactWeatherChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 14, color: _navySoft),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _navy.withValues(alpha: 0.58),
                    fontSize: 9.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 11.2,
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
}

class TimeLineSelector extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Set<int> lockedIndices;
  final VoidCallback? onLockedTap;

  const TimeLineSelector({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.lockedIndices = const <int>{},
    this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    const double selectorSize = 44;
    const double lineLeft = 20;
    const double tickMaxWidth = 16;
    const double tickMinWidth = 10;

    return SizedBox(
      width: MediaQuery.sizeOf(context).width < 360 ? 110 : 124,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double height = constraints.maxHeight;
          final double topSafe = selectorSize / 2;
          final double usableHeight = height - selectorSize;
          final double step = labels.length > 1
              ? usableHeight / (labels.length - 1)
              : 0;

          double dyToIndex(double dy) {
            if (step == 0) return 0;
            final clamped = dy.clamp(topSafe, height - topSafe);
            return ((clamped - topSafe) / step).roundToDouble();
          }

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) {
              final index = dyToIndex(
                details.localPosition.dy,
              ).toInt().clamp(0, labels.length - 1);
              if (lockedIndices.contains(index)) {
                onLockedTap?.call();
                return;
              }
              onChanged(index);
            },
            onVerticalDragUpdate: (details) {
              final box = context.findRenderObject() as RenderBox;
              final local = box.globalToLocal(details.globalPosition);
              final index = dyToIndex(
                local.dy,
              ).toInt().clamp(0, labels.length - 1);
              if (lockedIndices.contains(index)) {
                return;
              }
              onChanged(index);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: lineLeft,
                  top: topSafe,
                  bottom: topSafe,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                for (int i = 0; i < labels.length; i++)
                  Positioned(
                    top: topSafe + (i * step) - 10,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: 20,
                      child: Row(
                        children: [
                          SizedBox(
                            width: lineLeft + 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                width:
                                    i == selectedIndex &&
                                        !lockedIndices.contains(i)
                                    ? tickMaxWidth
                                    : tickMinWidth,
                                height:
                                    i == selectedIndex &&
                                        !lockedIndices.contains(i)
                                    ? 3
                                    : 2,
                                color: lockedIndices.contains(i)
                                    ? Colors.white.withValues(alpha: 0.38)
                                    : Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    labels[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize:
                                          i == selectedIndex &&
                                              !lockedIndices.contains(i)
                                          ? 15
                                          : 13,
                                      fontWeight:
                                          i == selectedIndex &&
                                              !lockedIndices.contains(i)
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: lockedIndices.contains(i)
                                          ? Colors.white.withValues(alpha: 0.42)
                                          : i == selectedIndex
                                          ? Colors.white
                                          : Colors.white.withValues(
                                              alpha: 0.84,
                                            ),
                                    ),
                                  ),
                                ),
                                if (lockedIndices.contains(i)) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.lock_rounded,
                                    color: Colors.white.withValues(alpha: 0.52),
                                    size: 12,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!lockedIndices.contains(selectedIndex))
                  Positioned(
                    left: 0,
                    top: topSafe + (selectedIndex * step) - (selectorSize / 2),
                    child: Container(
                      width: selectorSize,
                      height: selectorSize,
                      decoration: BoxDecoration(
                        color: _coral,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _coral.withValues(alpha: 0.32),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up,
                            color: Colors.white,
                            size: 16,
                          ),
                          Icon(Icons.circle, color: Colors.white, size: 8),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
