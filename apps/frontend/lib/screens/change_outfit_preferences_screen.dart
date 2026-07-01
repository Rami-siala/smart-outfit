import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:frontend/models/outfit_recommendation_data.dart';
import 'package:frontend/screens/outfit_recommendation_screen.dart';
import 'package:frontend/screens/settings/account_settings_screen.dart';
import 'package:frontend/services/api_service.dart';

class ChangeOutfitPreferencesScreen extends StatefulWidget {
  final Map<String, dynamic>? initialWeather;
  final bool confirmLogoutOnExit;
  final Map<String, String>? currentOutfit;
  final bool isGuest;

  const ChangeOutfitPreferencesScreen({
    super.key,
    this.initialWeather,
    this.confirmLogoutOnExit = false,
    this.currentOutfit,
    this.isGuest = false,
  });

  @override
  State<ChangeOutfitPreferencesScreen> createState() =>
      _ChangeOutfitPreferencesScreenState();
}

class _ChangeOutfitPreferencesScreenState
    extends State<ChangeOutfitPreferencesScreen> {
  static const Color _navy = Color(0xFF173B6D);
  static const Color _navySoft = Color(0xFF2B568D);
  static const Color _mist = Color(0xFFF3F7FB);
  static const Color _pink = Color(0xFFD970C4);
  static const Color _coral = Color(0xFFE85B5B);

  final TextEditingController _cityController = TextEditingController();
  final Random _random = Random();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSearching = false;

  String? _selectedColor;
  String? _selectedStyle;
  String? _gender;

  Map<String, dynamic>? _weather;
  List<Map<String, dynamic>> _cities = [];

  final List<String> _styles = ['sport', 'casual', 'chic'];

  final List<String> _colors = [
    'black',
    'white',
    'beige',
    'blue',
    'red',
    'green',
    'pink',
    'brown',
    'gray',
    'purple',
  ];

  void _log(String message) {
    debugPrint('[ChangeOutfitPreferencesScreen] $message');
  }

  @override
  void initState() {
    super.initState();

    if (widget.initialWeather != null) {
      _weather = widget.initialWeather;
      _cityController.text = widget.initialWeather?['city']?.toString() ?? '';
    }

    _loadSavedData();
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    if (widget.isGuest) {
      _selectedColor = OutfitRecommendationData.defaultColor.toLowerCase();
      _selectedStyle = OutfitRecommendationData.defaultStyle.toLowerCase();
      _gender = OutfitRecommendationData.defaultGender.toLowerCase();
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final prefs = await ApiService.getMyPreferences();
      final profile = await ApiService.getMyProfile();

      final colors = prefs?['favorite_colors'];
      final styles = prefs?['favorite_styles'];

      if (colors is List && colors.isNotEmpty) {
        _selectedColor = colors.first.toString().trim().toLowerCase();
      }

      if (styles is List && styles.isNotEmpty) {
        _selectedStyle = styles.first.toString().trim().toLowerCase();
      }

      _gender = profile?['gender']?.toString().trim().toLowerCase();
    } catch (_) {
      // keep screen usable
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchCities() async {
    final query = _cityController.text.trim();

    if (query.length < 2) {
      _showMessage('Please enter at least 2 characters');
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await ApiService.searchCities(query);

      if (!mounted) return;

      setState(() {
        _cities = results;
      });

      if (results.isEmpty) {
        _showMessage('City not found');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _selectCity(Map<String, dynamic> city) async {
    final lat = city['lat'];
    final lon = city['lon'];
    final name = city['name']?.toString() ?? '';

    setState(() => _isSearching = true);

    try {
      final weather = lat != null && lon != null
          ? await ApiService.getCurrentWeather('$lat,$lon')
          : await ApiService.getCurrentWeather(name);

      if (!mounted) return;

      setState(() {
        _weather = weather;
        _cities = [];
        _cityController.text = name;
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  String _weatherFolder() {
    final condition = (_weather?['condition'] ?? '').toString().toLowerCase();
    final category =
        (_weather?['weather_category'] ?? '').toString().toLowerCase();
    final temp = _weather?['temperature'] is num
        ? (_weather?['temperature'] as num).toDouble()
        : double.tryParse(_weather?['temperature']?.toString() ?? '');

    _log(
      '_weatherFolder weather='
      'city=${_weather?['city']} '
      'condition=${_weather?['condition']} '
      'temperature=${_weather?['temperature']} '
      'weather_category=${_weather?['weather_category']} '
      'precipitation=${_weather?['precipitation']}',
    );

    final hasPrecipitation = _weather?['precipitation'] == true;
    final isRainLike =
        condition.contains('rain') ||
        condition.contains('drizzle') ||
        condition.contains('shower') ||
        condition.contains('storm') ||
        condition.contains('thunder') ||
        condition.contains('hail') ||
        condition.contains('sleet');
    final isHot = category == 'hot' || (temp != null && temp > 25);

    if (hasPrecipitation || isRainLike) {
      _log('_weatherFolder result=rainy (wet weather wins)');
      return 'rainy';
    }

    if (isHot) {
      _log('_weatherFolder result=sunny (hot weather)');
      return 'sunny';
    }

    _log('_weatherFolder result=normal');
    return 'normal';
  }

  Future<String> _pickRandomOutfitImage() async {
    final gender = _gender?.trim().toLowerCase();
    final color = _selectedColor?.trim().toLowerCase();
    final style = _selectedStyle?.trim().toLowerCase();
    final weather = _weatherFolder();

    if (gender == null || gender.isEmpty) {
      throw Exception('Gender not found');
    }

    if (color == null || color.isEmpty) {
      throw Exception('Please choose a color');
    }

    if (style == null || style.isEmpty) {
      throw Exception('Please choose a style');
    }

    final folderPrefix = 'assets/outfits/$style/$weather/';
    _log(
      '_pickRandomOutfitImage inputs='
      'gender=$gender color=$color style=$style weatherFolder=$weather '
      'folderPrefix=$folderPrefix',
    );

    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);

    final matches = manifestMap.keys.where((path) {
      final p = path.toLowerCase();
      return p.startsWith(folderPrefix) &&
          (p.endsWith('.png') ||
              p.endsWith('.jpg') ||
              p.endsWith('.jpeg') ||
              p.endsWith('.webp')) &&
          p.split('/').last.startsWith('${gender}_') &&
          p.contains(color) &&
          p.contains(weather) &&
          p.contains(style);
    }).toList();

    _log(
      '_pickRandomOutfitImage matches=${matches.length} '
      'sample=${matches.take(5).join(', ')}',
    );

    if (matches.isEmpty) {
      throw Exception(
        'No matching image found for $gender / $color / $style / $weather',
      );
    }

    matches.sort();
    final selectedImagePath = matches[_random.nextInt(matches.length)];
    _log('_pickRandomOutfitImage selectedImagePath=$selectedImagePath');
    return selectedImagePath;
  }

  String _value(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty) return fallback;
    return text;
  }

  String _formatTemp(dynamic value) {
    if (value == null) return '--';

    final number =
        value is num ? value.toDouble() : double.tryParse(value.toString());

    if (number == null) return '--';

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number.toStringAsFixed(1);
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  Future<void> _generateOutfit() async {
    if (_selectedColor == null || _selectedColor!.isEmpty) {
      _showMessage('Please choose a color');
      return;
    }

    if (_selectedStyle == null || _selectedStyle!.isEmpty) {
      _showMessage('Please choose a style');
      return;
    }

    if (_weather == null) {
      _showMessage('Please search and choose a city');
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (!widget.isGuest) {
        await ApiService.updateMyPreferences(
          favoriteColors: [_selectedColor!],
          favoriteStyles: [_selectedStyle!],
        );
      }

      final imagePath = await _pickRandomOutfitImage();
      _log('_generateOutfit final imagePath=$imagePath');

      final city = _value(_weather?['city']);
      final country = _value(_weather?['country']);
      final latitude = _toDouble(_weather?['latitude']);
      final longitude = _toDouble(_weather?['longitude']);
      final temperature = _formatTemp(_weather?['temperature']);
      final humidity = '${_value(_weather?['humidity'])}%';
      final wind = '${_value(_weather?['wind_kph'])} km/h';
      final precipitation = _weather?['precipitation'] == true ? 'Yes' : 'No';
      final style = _selectedStyle == null ? '' : _capitalize(_selectedStyle!);
      final color = _selectedColor == null ? '' : _capitalize(_selectedColor!);
      final gender = _gender == null ? '' : _capitalize(_gender!);
      final weather = _value(
        _weather?['condition'],
        fallback: '',
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OutfitRecommendationScreen(
            isGuest: widget.isGuest,
            data: OutfitRecommendationData(
              imagePath: imagePath,
              city: city,
              country: country,
              latitude: latitude,
              longitude: longitude,
              temperature: temperature,
              precipitation: precipitation,
              humidity: humidity,
              wind: wind,
              style: style,
              color: color,
              gender: gender,
              weather: weather,
            ),
            confirmLogoutOnExit: widget.confirmLogoutOnExit,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _persistPreferences() async {
    if (widget.isGuest) {
      return;
    }

    final color = _selectedColor?.trim();
    final style = _selectedStyle?.trim();

    if (color == null || color.isEmpty || style == null || style.isEmpty) {
      return;
    }

    await ApiService.updateMyPreferences(
      favoriteColors: [color],
      favoriteStyles: [style],
    );
  }

  Future<void> _selectColor(String color) async {
    final previousColor = _selectedColor;

    setState(() => _selectedColor = color);

    try {
      await _persistPreferences();
    } catch (e) {
      if (!mounted) return;

      setState(() => _selectedColor = previousColor);
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _selectStyle(String style) async {
    final previousStyle = _selectedStyle;

    setState(() => _selectedStyle = style);

    try {
      await _persistPreferences();
    } catch (e) {
      if (!mounted) return;

      setState(() => _selectedStyle = previousStyle);
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _cancelChanges() {
    final currentOutfit = widget.currentOutfit;

    if (currentOutfit == null) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OutfitRecommendationScreen(
          isGuest: widget.isGuest,
          selectedAiImageUrl:
              (currentOutfit['selectedAiImageUrl'] ?? '').trim().isEmpty
                  ? null
                  : currentOutfit['selectedAiImageUrl'],
          data: OutfitRecommendationData(
            imagePath: currentOutfit['imagePath'] ?? '',
            city: currentOutfit['city'] ?? '',
            country: currentOutfit['country'] ?? '',
            latitude: _toDouble(currentOutfit['latitude']),
            longitude: _toDouble(currentOutfit['longitude']),
            temperature: currentOutfit['temperature'] ?? '',
            precipitation: currentOutfit['precipitation'] ?? 'No',
            humidity: currentOutfit['humidity'] ?? '-',
            wind: currentOutfit['wind'] ?? '-',
            style: currentOutfit['style'],
            color: currentOutfit['color'],
            gender: currentOutfit['gender'],
            weather: currentOutfit['weather'],
          ),
          confirmLogoutOnExit: widget.confirmLogoutOnExit,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AccountSettingsScreen(),
      ),
    );
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  Widget _buildSectionCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeading(
    String title,
    String subtitle, {
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _mist,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: _pink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: _navy.withValues(alpha: 0.62),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: _navy.withValues(alpha: 0.78),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _mist,
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          color: _navy,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: _navy.withValues(alpha: 0.42),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(icon, color: _pink),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_coral, _pink],
                )
              : null,
          color: selected ? null : _mist,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _coral.withValues(alpha: 0.20),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _navy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: _mist,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _pink),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _navy.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _navy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: _isSaving ? 0.98 : 1),
      duration: const Duration(milliseconds: 160),
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_coral, _pink],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _coral.withValues(alpha: 0.22),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _generateOutfit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'New Outfit',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isSaving) return;
        _cancelChanges();
      },
      child: Scaffold(
        backgroundColor: _mist,
        appBar: AppBar(
          backgroundColor: _mist,
          surfaceTintColor: _mist,
          foregroundColor: _navy,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            onPressed: _isSaving ? null : _cancelChanges,
            icon: const Icon(Icons.arrow_back),
          ),
          titleSpacing: 0,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change Outfit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Customize your weather and outfit preferences',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: widget.isGuest
              ? const []
              : [
                  IconButton(
                    onPressed: _isSaving ? null : _openSettings,
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Settings',
                  ),
                ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _navy),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_navy, _navySoft],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: _navy.withValues(alpha: 0.16),
                            blurRadius: 22,
                            offset: const Offset(0, 14),
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
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Style your next look',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Refresh your outfit suggestion',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Update the weather, location, and style details below to generate a better match for right now.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeading(
                            'Location',
                            'Search for a city to refresh the live weather details.',
                            icon: Icons.location_on_outlined,
                          ),
                          const SizedBox(height: 18),
                          _buildInputLabel('City'),
                          _buildTextInput(
                            controller: _cityController,
                            hint: 'Search city',
                            icon: Icons.search_rounded,
                            onSubmitted: (_) => _searchCities(),
                          ),
                          const SizedBox(height: 14),
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
                              label: Text(
                                _isSearching ? 'Searching...' : 'Search City',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _navy,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                          if (_cities.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              decoration: BoxDecoration(
                                color: _mist,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _cities.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: _navy.withValues(alpha: 0.08),
                                ),
                                itemBuilder: (context, index) {
                                  final city = _cities[index];
                                  final name = city['name']?.toString() ?? '';
                                  final region = city['region']?.toString() ?? '';
                                  final country =
                                      city['country']?.toString() ?? '';

                                  return ListTile(
                                    leading: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.location_city_rounded,
                                        color: _navySoft,
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        color: _navy,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: Text(
                                      [region, country]
                                          .where((e) => e.trim().isNotEmpty)
                                          .join(', '),
                                      style: TextStyle(
                                        color: _navy.withValues(alpha: 0.62),
                                      ),
                                    ),
                                    onTap: () => _selectCity(city),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeading(
                            'Weather details',
                            'Review the current conditions that will shape the outfit result.',
                            icon: Icons.cloud_outlined,
                          ),
                          const SizedBox(height: 18),
                          if (_weather == null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _mist,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Search and select a city to preview weather details here.',
                                style: TextStyle(
                                  color: _navy.withValues(alpha: 0.64),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_navy, _navySoft],
                                ),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_value(_weather?['city'])}, ${_value(_weather?['country'])}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_formatTemp(_weather?['temperature'])}°C',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _value(
                                      _weather?['condition'],
                                      fallback: 'Current conditions',
                                    ),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.78),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 360;

                                return Row(
                                  children: [
                                    Expanded(
                                      child: _buildWeatherStat(
                                        label: 'Humidity',
                                        value:
                                            '${_value(_weather?['humidity'])}%',
                                        icon: Icons.water_drop_outlined,
                                      ),
                                    ),
                                    SizedBox(width: compact ? 8 : 10),
                                    Expanded(
                                      child: _buildWeatherStat(
                                        label: 'Wind',
                                        value:
                                            '${_value(_weather?['wind_kph'])} km/h',
                                        icon: Icons.air_rounded,
                                      ),
                                    ),
                                    SizedBox(width: compact ? 8 : 10),
                                    Expanded(
                                      child: _buildWeatherStat(
                                        label: 'Rain',
                                        value: _weather?['precipitation'] == true
                                            ? 'Yes'
                                            : 'No',
                                        icon: Icons.umbrella_outlined,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeading(
                            'Outfit preferences',
                            'Choose the color and style direction for the next recommendation.',
                            icon: Icons.checkroom_outlined,
                          ),
                          const SizedBox(height: 18),
                          _buildInputLabel('Favorite color'),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _colors.map((color) {
                              return _buildChoiceChip(
                                label: _capitalize(color),
                                selected: _selectedColor == color,
                                onTap: () => _selectColor(color),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),
                          _buildInputLabel('Style'),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _styles.map((style) {
                              return _buildChoiceChip(
                                label: _capitalize(style),
                                selected: _selectedStyle == style,
                                onTap: () => _selectStyle(style),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _buildPrimaryButton(),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : _cancelChanges,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _navy,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: _navy.withValues(alpha: 0.18),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
      ),
    );
  }
}
