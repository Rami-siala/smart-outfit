import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const Color _navy = Color(0xFF173B6D);
const Color _mist = Color(0xFFF4F7FC);
const Color _panel = Color(0xFFF7F9FD);
const Color _pink = Color(0xFFD970C4);
const Color _blue = Color(0xFF4B84FF);
const Color _gold = Color(0xFFF6B73C);

class LocationWeatherDetailsScreen extends StatelessWidget {
  final String city;
  final String country;
  final String temperature;
  final String weather;
  final String precipitation;
  final String humidity;
  final String wind;
  final String dateLabel;
  final Map<String, dynamic>? forecastData;

  const LocationWeatherDetailsScreen({
    super.key,
    required this.city,
    required this.country,
    required this.temperature,
    required this.weather,
    required this.precipitation,
    required this.humidity,
    required this.wind,
    required this.dateLabel,
    this.forecastData,
  });

  String _value(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _weatherEmoji(String condition) {
    final text = condition.toLowerCase();
    if (text.contains('storm') || text.contains('thunder')) return '\u26C8';
    if (text.contains('snow') || text.contains('ice')) return '\u2744';
    if (text.contains('rain') ||
        text.contains('drizzle') ||
        text.contains('shower')) {
      return '\uD83C\uDF27';
    }
    if (text.contains('cloud') ||
        text.contains('overcast') ||
        text.contains('fog')) {
      return '\u2601';
    }
    if (text.contains('sun') ||
        text.contains('clear') ||
        text.contains('fair')) {
      return '\u2600';
    }
    return '\uD83C\uDF24';
  }

  String _weatherMood(String condition) {
    final text = condition.toLowerCase();
    if (text.contains('storm') || text.contains('thunder')) {
      return 'Keep plans flexible';
    }
    if (text.contains('snow') || text.contains('ice')) {
      return 'Cold weather mood';
    }
    if (text.contains('rain') ||
        text.contains('drizzle') ||
        text.contains('shower')) {
      return 'Looks wet outside';
    }
    if (text.contains('cloud') ||
        text.contains('overcast') ||
        text.contains('fog')) {
      return 'Soft light day';
    }
    if (text.contains('sun') ||
        text.contains('clear') ||
        text.contains('fair')) {
      return 'Bright outdoor mood';
    }
    return 'Steady conditions';
  }

  String _comfortSummary() {
    final temp =
        double.tryParse(
          temperature.replaceAll('Ã‚Â°', '').replaceAll('C', '').trim(),
        ) ??
        double.tryParse(temperature.replaceAll('C', '').trim()) ??
        0;
    final humidityValue =
        int.tryParse(humidity.replaceAll('%', '').trim()) ?? 0;
    final windValue = double.tryParse(wind.replaceAll(' km/h', '').trim()) ?? 0;

    if (temp >= 30) {
      return humidityValue >= 70 ? 'Hot & muggy' : 'Hot';
    }
    if (temp >= 24) {
      if (humidityValue >= 70) return 'Warm & humid';
      if (windValue >= 18) return 'Warm breeze';
      return 'Warm';
    }
    if (temp >= 18) {
      if (windValue >= 20) return 'Fresh breeze';
      return 'Comfortable';
    }
    if (temp >= 12) {
      return windValue >= 18 ? 'Cool breeze' : 'Cool';
    }
    return 'Cold';
  }

  String _avgTempLabel() {
    final daily = forecastData?['daily'];
    if (daily is List &&
        daily.isNotEmpty &&
        daily.first is Map<String, dynamic>) {
      final temp = _toDouble(
        (daily.first as Map<String, dynamic>)['temperature'],
      );
      if (temp != null) return '${temp.round()}\u00B0';
    }
    final parsed = double.tryParse(temperature.replaceAll('C', '').trim());
    if (parsed != null) return '${parsed.round()}\u00B0';
    return '-';
  }

  String _uvLabel() {
    final uv = _toDouble(forecastData?['current_uv']);
    if (uv == null) return '-';
    if (uv >= 8) return 'Very High';
    if (uv >= 6) return 'High';
    if (uv >= 3) return 'Moderate';
    return 'Low';
  }

  String _visibilityLabel() {
    final visibility = _toDouble(forecastData?['current_visibility_km']);
    if (visibility == null) return '-';
    return '${visibility.round()}km';
  }

  @override
  Widget build(BuildContext context) {
    final latitude = _toDouble(forecastData?['latitude']);
    final longitude = _toDouble(forecastData?['longitude']);
    final weatherLabel = _value(weather);
    final weatherEmoji = _weatherEmoji(weatherLabel);
    final weatherMood = _weatherMood(weatherLabel);

    return Scaffold(
      backgroundColor: _mist,
      appBar: AppBar(
        backgroundColor: _mist,
        surfaceTintColor: _mist,
        foregroundColor: _navy,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          'Location Details',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useScrollFallback = constraints.maxHeight < 660;
            final content = _buildContent(
              latitude: latitude,
              longitude: longitude,
              weatherLabel: weatherLabel,
              weatherEmoji: weatherEmoji,
              weatherMood: weatherMood,
              fillHeight: !useScrollFallback,
            );

            if (useScrollFallback) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: content,
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: content,
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent({
    required double? latitude,
    required double? longitude,
    required String weatherLabel,
    required String weatherEmoji,
    required String weatherMood,
    required bool fillHeight,
  }) {
    final topCards = <Widget>[
      _buildHero(weatherLabel, weatherEmoji, weatherMood),
      const SizedBox(height: 10),
      _sectionCard(
        title: 'Weather Snapshot',
        icon: Icons.info_outline_rounded,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _snapshotMetric(
                    label: 'Condition',
                    value: '$weatherEmoji Sunny'.replaceFirst(
                      'Sunny',
                      weatherLabel,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _snapshotMetric(
                    label: 'Precipitation',
                    value: precipitation,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _snapshotMetric(label: 'Humidity', value: humidity),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _snapshotMetric(label: 'Wind', value: wind),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      _sectionCard(
        title: 'Weather Trends',
        icon: Icons.bar_chart_rounded,
        child: Row(
          children: [
            Expanded(
              child: _trendMetric(
                label: 'Avg Temp',
                value: _avgTempLabel(),
                accent: _blue,
                symbol: '\u2193',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _trendMetric(
                label: 'UV Index',
                value: _uvLabel(),
                accent: _pink,
                symbol: '\u275A\u275A',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _trendMetric(
                label: 'Visibility',
                value: _visibilityLabel(),
                accent: _gold,
                symbol: '\u2191',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
    ];

    if (!fillHeight) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...topCards,
          _sectionCard(
            title: 'Where Is It?',
            icon: Icons.public_rounded,
            child: _locationCard(
              latitude: latitude,
              longitude: longitude,
              fillHeight: false,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...topCards,
        Expanded(
          child: _sectionCard(
            title: 'Where Is It?',
            icon: Icons.public_rounded,
            expandChild: true,
            child: _locationCard(
              latitude: latitude,
              longitude: longitude,
              fillHeight: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero(
    String weatherLabel,
    String weatherEmoji,
    String weatherMood,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF244B8B), Color(0xFF1D3E74)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -18,
            child: Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 16,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _heroChip(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: Colors.white,
                      size: 13,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Current place',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$city, $country',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  height: 1.02,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$dateLabel - $weatherLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.80),
                  fontSize: 10.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 9),
              _heroChip(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(weatherEmoji, style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        weatherMood,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _heroMetric(title: 'TEMP', value: '$temperature C'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _heroMetric(
                      title: 'FEELS LIKE',
                      value: _comfortSummary(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: child,
    );
  }

  Widget _heroMetric({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    bool expandChild = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: icon == Icons.bar_chart_rounded ? _blue : _pink,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }

  Widget _snapshotMetric({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _navy.withValues(alpha: 0.58),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _navy,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendMetric({
    required String label,
    required String value,
    required Color accent,
    required String symbol,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _navy.withValues(alpha: 0.58),
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      height: 3,
                      width: 24,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 14,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  symbol,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _locationCard({
    required double? latitude,
    required double? longitude,
    required bool fillHeight,
  }) {
    if (!fillHeight) {
      return SizedBox(
        height: 148,
        child: _miniMapCard(latitude: latitude, longitude: longitude),
      );
    }

    return SizedBox.expand(
      child: _miniMapCard(latitude: latitude, longitude: longitude),
    );
  }

  Widget _miniMapCard({required double? latitude, required double? longitude}) {
    if (latitude == null || longitude == null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7E7E7E), Color(0xFF535353)],
          ),
        ),
        child: const Center(
          child: Text(
            'Map unavailable for this location',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    final point = LatLng(latitude, longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 7.2,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.smartoutfit.frontend',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 36,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _navy.withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(
                            color: _blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 12, color: _navy),
                  SizedBox(width: 6),
                  Text(
                    'Real map',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
