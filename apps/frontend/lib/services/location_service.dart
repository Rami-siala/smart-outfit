import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationAccessState {
  final bool serviceEnabled;
  final LocationPermission permission;

  const LocationAccessState({
    required this.serviceEnabled,
    required this.permission,
  });

  bool get isGranted =>
      permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;

  bool get isDeniedForever => permission == LocationPermission.deniedForever;
}

class LocationService {
  static const String _useDeviceLocationKey = 'use_device_location';
  static const String locationServicesDisabledMessage =
      'Turn on your phone location/GPS to use your current location.';
  static const String locationPermissionDeniedMessage =
      'Location permission was denied. You can allow it now or choose a city manually.';
  static const String locationPermissionDeniedForeverMessage =
      'Location permission is blocked for this app. Please enable it in app settings.';

  static Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  static Future<LocationAccessState> ensureLocationAccess({
    bool requestPermission = true,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationAccessState(
        serviceEnabled: false,
        permission: LocationPermission.unableToDetermine,
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (requestPermission && permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return LocationAccessState(
      serviceEnabled: true,
      permission: permission,
    );
  }

  static Future<Position> getCurrentPosition() async {
    final accessState = await ensureLocationAccess();

    if (!accessState.serviceEnabled) {
      throw Exception(locationServicesDisabledMessage);
    }

    if (accessState.isDeniedForever) {
      throw Exception(locationPermissionDeniedForeverMessage);
    }

    if (!accessState.isGranted) {
      throw Exception(locationPermissionDeniedMessage);
    }

    return Geolocator.getCurrentPosition();
  }

  static Future<void> saveUseDeviceLocation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useDeviceLocationKey, value);
  }

  static Future<void> resetLocationPreferenceForLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_useDeviceLocationKey);
    await prefs.setBool(_useDeviceLocationKey, true);
  }

  static Future<bool> getUseDeviceLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useDeviceLocationKey) ?? false;
  }

  static Future<bool> hasGrantedLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
