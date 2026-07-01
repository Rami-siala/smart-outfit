import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  static const String baseUrl = ApiConfig.baseUrl;
  static const String _tokenKey = 'access_token';
  static const String _aiHistoryCacheKey = 'liked_ai_outfit_history';
  static const String _guestWardrobesKey = 'guest_wardrobes';
  static const String _selectedAiWardrobeIdKey = 'selected_ai_wardrobe_id';
  static const String _selectedAiWardrobeNameKey = 'selected_ai_wardrobe_name';

  // =========================
  // TOKEN
  // =========================

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.remove(_aiHistoryCacheKey);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_aiHistoryCacheKey);
  }

  static Future<void> clearGuestSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestWardrobesKey);
    await prefs.remove(_selectedAiWardrobeIdKey);
    await prefs.remove(_selectedAiWardrobeNameKey);
  }

  static Future<void> logout() async {
    await clearToken();
    await clearGuestSessionData();
  }

  // =========================
  // AUTH
  // =========================

  static Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/register');

    final response = await http.post(
      url,
      headers: _jsonHeaders(),
      body: jsonEncode({
        'full_name': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(_extractMessage(response, 'Registration failed'));
    }
  }

  static Future<String> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');

    final response = await http.post(
      url,
      headers: _jsonHeaders(),
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Login failed'));
    }

    final data = _decodeMap(response.body);
    final token = data['access_token']?.toString();

    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }

    await saveToken(token);
    return token;
  }

  static Future<Map<String, dynamic>> getMe() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token found');
    }

    final url = Uri.parse('$baseUrl/auth/me');

    final response = await http.get(url, headers: _authHeaders(token));

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to load user data'));
    }

    return _decodeMap(response.body);
  }

  static Future<Map<String, dynamic>> updateMe({
    required String fullName,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token found');
    }

    final url = Uri.parse('$baseUrl/auth/me');

    final response = await http.put(
      url,
      headers: _authHeaders(token),
      body: jsonEncode({'full_name': fullName.trim()}),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to update user'));
    }

    return _decodeMap(response.body);
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token found');
    }

    final url = Uri.parse('$baseUrl/auth/change-password');

    final response = await http.post(
      url,
      headers: _authHeaders(token),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to change password'));
    }
  }

  // =========================
  // PROFILE
  // =========================

  static Future<Map<String, dynamic>?> getMyProfile() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token found');
    }

    final url = Uri.parse('$baseUrl/profile/me');

    final response = await http.get(url, headers: _authHeaders(token));

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to load profile'));
    }

    return _decodeMap(response.body);
  }

  static Future<Map<String, dynamic>> updateMyProfile({
    DateTime? birthDate,
    String? gender,
    double? height,
    double? weight,
    String? skinTone,
    String? bodyShape,
    String? profileImageUrl,
    bool clearProfileImage = false,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token found');
    }

    final url = Uri.parse('$baseUrl/profile/me');
    final normalizedProfileImageUrl = clearProfileImage
        ? null
        : _normalizeProfileImageUrlForRequest(profileImageUrl);

    final Map<String, dynamic> body = {
      'birth_date': birthDate != null ? _formatDateOnly(birthDate) : null,
      'gender': gender,
      'height': height,
      'weight': weight,
      'skin_tone': skinTone,
      'body_shape': bodyShape,
      'profile_image_url': normalizedProfileImageUrl,
    };

    body.removeWhere(
      (key, value) =>
          value == null && !(key == 'profile_image_url' && clearProfileImage),
    );

    final response = await http.put(
      url,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to update profile'));
    }

    return _decodeMap(response.body);
  }

  static Future<String> uploadProfileImage(String imagePath) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token found');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/profile/upload-image'),
    );

    request.headers.addAll(_multipartAuthHeaders(token));

    request.files.add(await http.MultipartFile.fromPath('file', imagePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        _extractMessage(response, 'Failed to upload profile image'),
      );
    }

    final data = _decodeMap(response.body);

    return data['profile_image_url'].toString();
  }

  // =========================
  // FORGOT PASSWORD
  // =========================

  static Future<void> forgotPassword({required String email}) async {
    final url = Uri.parse('$baseUrl/auth/forgot-password');

    final response = await http.post(
      url,
      headers: _jsonHeaders(),
      body: jsonEncode({'email': email.trim().toLowerCase()}),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to send reset code'));
    }
  }

  static Future<void> verifyResetCode({
    required String email,
    required String code,
  }) async {
    final url = Uri.parse('$baseUrl/auth/verify-reset-code');

    final response = await http.post(
      url,
      headers: _jsonHeaders(),
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Invalid verification code'));
    }
  }

  static Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final url = Uri.parse('$baseUrl/auth/reset-password');

    final response = await http.post(
      url,
      headers: _jsonHeaders(),
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
        'new_password': newPassword.trim(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to reset password'));
    }
  }

  // =========================
  // WEATHER
  // =========================

  static Future<List<Map<String, dynamic>>> searchCities(String query) async {
    final token = await getToken();

    final url = Uri.parse(
      '$baseUrl/weather/search?q=${Uri.encodeQueryComponent(query)}',
    );

    final response = await http.get(url, headers: _weatherHeaders(token));

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to search cities'));
    }

    return _decodeListOfMaps(response.body);
  }

  static Future<Map<String, dynamic>> getCurrentWeather(
    String cityQuery,
  ) async {
    final token = await getToken();

    final url = Uri.parse(
      '$baseUrl/weather/current?q=${Uri.encodeQueryComponent(cityQuery)}',
    );

    final response = await http.get(url, headers: _weatherHeaders(token));

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to get weather'));
    }

    return _decodeMap(response.body);
  }

  static Future<Map<String, dynamic>> getCurrentWeatherByCoordinates({
    required double lat,
    required double lon,
  }) async {
    return getCurrentWeather('$lat,$lon');
  }

  static Future<Map<String, dynamic>> getLastWeather() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token found');
    }

    final url = Uri.parse('$baseUrl/weather/last');

    final response = await http.get(url, headers: _authHeaders(token));

    if (response.statusCode != 200) {
      throw Exception(
        _extractMessage(response, 'Failed to load saved weather'),
      );
    }

    return _decodeMap(response.body);
  }

  static Future<Map<String, dynamic>> getWeatherForecast({
    required String query,
    int days = 7,
  }) async {
    final token = await getToken();

    final url = Uri.parse(
      '$baseUrl/weather/forecast?q=${Uri.encodeQueryComponent(query)}&days=$days',
    );

    final response = await http.get(url, headers: _weatherHeaders(token));

    if (response.statusCode != 200) {
      throw Exception(
        _extractMessage(response, 'Failed to load weather forecast'),
      );
    }

    return _decodeMap(response.body);
  }

  // =========================
  // PREFERENCES
  // =========================

  static Future<Map<String, dynamic>?> getMyPreferences() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token found');
    }

    final url = Uri.parse('$baseUrl/preferences/me');

    final response = await http.get(url, headers: _authHeaders(token));

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to load preferences'));
    }

    return _decodeMap(response.body);
  }

  static Future<Map<String, dynamic>> updateMyPreferences({
    required List<String> favoriteColors,
    required List<String> favoriteStyles,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token found');
    }

    final url = Uri.parse('$baseUrl/preferences/me');

    final Map<String, dynamic> body = {
      'favorite_colors': favoriteColors,
      'favorite_styles': favoriteStyles,
    };

    final response = await http.put(
      url,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        _extractMessage(response, 'Failed to update preferences'),
      );
    }

    return _decodeMap(response.body);
  }

  // =========================
  // AI OUTFIT GENERATION
  // =========================

  static Future<Map<String, dynamic>> generateOutfitImage({
    required String city,
    required String country,
    required String temperature,
    required String weather,
    required String precipitation,
    required String humidity,
    required String wind,
    required String timeOfDay,
    String? style,
    String? color,
    String? gender,
    String? birthDate,
    double? height,
    double? weight,
    String? bodyShape,
    String? skinTone,
    String? extraInstructions,
    int? wardrobeId,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token found');
    }

    final url = Uri.parse('$baseUrl/ai/generate-outfit-image');

    final body = <String, dynamic>{
      'city': city,
      'country': country,
      'temperature': temperature,
      'weather': weather,
      'precipitation': precipitation,
      'humidity': humidity,
      'wind': wind,
      'time_of_day': timeOfDay,
      'style': style,
      'color': color,
      'gender': gender,
      'birth_date': birthDate,
      'height': height,
      'weight': weight,
      'body_shape': bodyShape,
      'skin_tone': skinTone,
      'extra_instructions': extraInstructions,
      'wardrobe_id': wardrobeId,
    };

    body.removeWhere((key, value) => value == null);

    final response = await http.post(
      url,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        _extractMessage(response, 'Failed to generate AI outfit image'),
      );
    }

    return _decodeMap(response.body);
  }

  static Future<List<Map<String, dynamic>>> getAiOutfitHistory() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token found');
    }

    final url = Uri.parse('$baseUrl/ai/outfit-history');

    final response = await http.get(url, headers: _authHeaders(token));

    if (response.statusCode != 200) {
      throw Exception(
        _extractMessage(response, 'Failed to load outfit history'),
      );
    }

    return _decodeListOfMaps(response.body);
  }

  static Future<Map<String, dynamic>> saveAiOutfitHistoryItem(
    Map<String, dynamic> payload,
  ) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token found');
    }

    final url = Uri.parse('$baseUrl/ai/outfit-history');

    final response = await http.post(
      url,
      headers: _authHeaders(token),
      body: jsonEncode(payload),
    );

    if (response.statusCode != 201) {
      throw Exception(
        _extractMessage(response, 'Failed to save outfit history'),
      );
    }

    return _decodeMap(response.body);
  }

  static Future<void> deleteAiOutfitHistoryItem(String id) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token found');
    }

    final url = Uri.parse('$baseUrl/ai/outfit-history/$id');

    final response = await http.delete(url, headers: _authHeaders(token));

    if (response.statusCode != 200) {
      throw Exception(
        _extractMessage(response, 'Failed to delete outfit from history'),
      );
    }
  }

  // =========================
  // WARDROBE
  // =========================

  static Future<List<Map<String, dynamic>>> getWardrobes() async {
    final token = await getToken();
    if (token == null || token.isEmpty) throw Exception('No token found');

    final response = await http.get(
      Uri.parse('$baseUrl/wardrobe/'),
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to load wardrobes'));
    }

    return _decodeListOfMaps(response.body);
  }

  static Future<Map<String, dynamic>> createWardrobe({
    required String name,
    String? description,
    String? address,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) throw Exception('No token found');

    final response = await http.post(
      Uri.parse('$baseUrl/wardrobe/'),
      headers: _authHeaders(token),
      body: jsonEncode({
        'name': name,
        'description': description,
        'address': address,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractMessage(response, 'Failed to create wardrobe'));
    }

    return _decodeMap(response.body);
  }

  static Future<Map<String, dynamic>> getWardrobe(int wardrobeId) async {
    final token = await getToken();
    if (token == null || token.isEmpty) throw Exception('No token found');

    final response = await http.get(
      Uri.parse('$baseUrl/wardrobe/$wardrobeId'),
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      final reason = _extractMessage(response, 'Failed to load wardrobe');
      throw Exception('Failed to load wardrobe #$wardrobeId: $reason');
    }

    return _decodeMap(response.body);
  }

  static Future<Map<String, dynamic>> updateWardrobe({
    required int wardrobeId,
    String? name,
    String? description,
    String? address,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) throw Exception('No token found');

    final body = {'name': name, 'description': description, 'address': address};

    body.removeWhere((key, value) => value == null);

    final response = await http.put(
      Uri.parse('$baseUrl/wardrobe/$wardrobeId'),
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to update wardrobe'));
    }

    return _decodeMap(response.body);
  }

  static Future<void> deleteWardrobe(int wardrobeId) async {
    final token = await getToken();
    if (token == null || token.isEmpty) throw Exception('No token found');

    final response = await http.delete(
      Uri.parse('$baseUrl/wardrobe/$wardrobeId'),
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to delete wardrobe'));
    }
  }

  // =========================
  // OUTFITS
  // =========================

  static Future<Map<String, dynamic>> createOutfit({
    required String title,
    String? imageGeneratedUrl,
    bool isFavorite = false,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) throw Exception('No token found');

    final response = await http.post(
      Uri.parse('$baseUrl/wardrobe/outfits'),
      headers: _authHeaders(token),
      body: jsonEncode({
        'title': title,
        'image_generated_url': imageGeneratedUrl,
        'is_favorite': isFavorite,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractMessage(response, 'Failed to create outfit'));
    }

    return _decodeMap(response.body);
  }

  static Future<List<Map<String, dynamic>>> getOutfits() async {
    final token = await getToken();
    if (token == null || token.isEmpty) throw Exception('No token found');

    final response = await http.get(
      Uri.parse('$baseUrl/wardrobe/outfits/all'),
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to load outfits'));
    }

    return _decodeListOfMaps(response.body);
  }

  static Future<Map<String, dynamic>> getOutfit(int outfitId) async {
    final token = await getToken();
    if (token == null || token.isEmpty) throw Exception('No token found');

    final response = await http.get(
      Uri.parse('$baseUrl/wardrobe/outfits/$outfitId'),
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to load outfit'));
    }

    return _decodeMap(response.body);
  }

  static Future<Map<String, dynamic>> updateOutfit({
    required int outfitId,
    String? title,
    String? imageGeneratedUrl,
    bool? isFavorite,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) throw Exception('No token found');

    final body = {
      'title': title,
      'image_generated_url': imageGeneratedUrl,
      'is_favorite': isFavorite,
    };

    body.removeWhere((key, value) => value == null);

    final response = await http.put(
      Uri.parse('$baseUrl/wardrobe/outfits/$outfitId'),
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to update outfit'));
    }

    return _decodeMap(response.body);
  }

  static Future<void> deleteOutfit(int outfitId) async {
    final token = await getToken();
    if (token == null || token.isEmpty) throw Exception('No token found');

    final response = await http.delete(
      Uri.parse('$baseUrl/wardrobe/outfits/$outfitId'),
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to delete outfit'));
    }
  }

  // =========================
  // WARDROBE ITEMS
  // =========================

  static Future<Map<String, dynamic>> createWardrobeItem({
    required int wardrobeId,
    required String name,
    required String type,
    String? itemSubtype,
    required String category,
    String? color,
    String? material,
    String? season,
    String? imageUrl,
    String? imageFilePath,
    bool precipitationResistant = false,
    int? outfitId,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) throw Exception('No token found');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/wardrobe/$wardrobeId/items'),
    );
    request.headers.addAll(_multipartAuthHeaders(token));
    request.fields['name'] = name;
    request.fields['type'] = type;
    if (itemSubtype != null && itemSubtype.isNotEmpty) {
      request.fields['item_subtype'] = itemSubtype;
    }
    request.fields['category'] = category;
    request.fields['precipitation_resistant'] = precipitationResistant
        .toString();

    if (color != null && color.isNotEmpty) request.fields['color'] = color;
    if (material != null && material.isNotEmpty) {
      request.fields['material'] = material;
    }
    if (season != null && season.isNotEmpty) request.fields['season'] = season;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      request.fields['image_url'] = imageUrl;
    }
    if (outfitId != null) request.fields['outfit_id'] = outfitId.toString();
    if (imageFilePath != null && imageFilePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFilePath),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        _extractMessage(response, 'Failed to create wardrobe item'),
      );
    }

    return _decodeMap(response.body);
  }

  static Future<List<Map<String, dynamic>>> getWardrobeItems(
    int wardrobeId,
  ) async {
    final token = await getToken();
    if (token == null || token.isEmpty) throw Exception('No token found');

    final response = await http.get(
      Uri.parse('$baseUrl/wardrobe/$wardrobeId/items'),
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception(
        _extractMessage(response, 'Failed to load wardrobe items'),
      );
    }

    return _decodeListOfMaps(response.body);
  }

  static Future<Map<String, dynamic>> updateWardrobeItem({
    required int itemId,
    String? name,
    String? type,
    String? itemSubtype,
    String? category,
    String? color,
    String? material,
    String? season,
    String? imageUrl,
    String? imageFilePath,
    bool removeImage = false,
    bool? precipitationResistant,
    int? outfitId,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) throw Exception('No token found');

    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/wardrobe/items/$itemId'),
    );
    request.headers.addAll(_multipartAuthHeaders(token));

    if (name != null) request.fields['name'] = name;
    if (type != null) request.fields['type'] = type;
    if (itemSubtype != null && itemSubtype.isNotEmpty) {
      request.fields['item_subtype'] = itemSubtype;
    }
    if (category != null) request.fields['category'] = category;
    if (color != null && color.isNotEmpty) request.fields['color'] = color;
    if (material != null && material.isNotEmpty) {
      request.fields['material'] = material;
    }
    if (season != null && season.isNotEmpty) request.fields['season'] = season;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      request.fields['image_url'] = imageUrl;
    }
    if (precipitationResistant != null) {
      request.fields['precipitation_resistant'] = precipitationResistant
          .toString();
    }
    if (outfitId != null) request.fields['outfit_id'] = outfitId.toString();
    if (removeImage) request.fields['remove_image'] = 'true';
    if (imageFilePath != null && imageFilePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFilePath),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        _extractMessage(response, 'Failed to update wardrobe item'),
      );
    }

    return _decodeMap(response.body);
  }

  static Future<void> deleteWardrobeItem(int itemId) async {
    final token = await getToken();
    if (token == null || token.isEmpty) throw Exception('No token found');

    final response = await http.delete(
      Uri.parse('$baseUrl/wardrobe/items/$itemId'),
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception(
        _extractMessage(response, 'Failed to delete wardrobe item'),
      );
    }
  }

  // =========================
  // HELPERS
  // =========================

  static Map<String, String> _jsonHeaders() {
    return {'Content-Type': 'application/json'};
  }

  static Map<String, String> _authHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Map<String, String> _multipartAuthHeaders(String token) {
    return {HttpHeaders.authorizationHeader: 'Bearer $token'};
  }

  static Map<String, String> _weatherHeaders(String? token) {
    if (token == null || token.isEmpty) {
      return _jsonHeaders();
    }

    return _authHeaders(token);
  }

  static Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw Exception('Invalid server response');
  }

  static List<Map<String, dynamic>> _decodeListOfMaps(String body) {
    final decoded = jsonDecode(body);

    if (decoded is List) {
      return decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    throw Exception('Invalid server response');
  }

  static String _extractMessage(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);

      if (data is Map && data['detail'] != null) {
        final detail = data['detail'];

        if (detail is List) {
          final friendlyValidationMessage = _formatValidationErrors(detail);
          if (friendlyValidationMessage != null) {
            return friendlyValidationMessage;
          }
        }

        if (detail is Map) {
          final friendlyDetailMessage = _formatDetailMessage(
            Map<String, dynamic>.from(detail),
          );
          if (friendlyDetailMessage != null) {
            return friendlyDetailMessage;
          }
        }

        return detail.toString();
      }

      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}

    return fallback;
  }

  static String? _formatValidationErrors(List<dynamic> detail) {
    final messages = <String>[];

    for (final item in detail) {
      if (item is! Map) continue;

      final rawLoc = item['loc'];
      final rawMsg = item['msg']?.toString() ?? '';
      final rawCtx = item['ctx'];

      final loc = rawLoc is List
          ? rawLoc.map((e) => e.toString()).toList()
          : <String>[];
      final field = loc.isNotEmpty ? loc.last.toLowerCase() : '';

      if (field == 'height' && rawMsg.contains('greater than or equal to')) {
        final minValue = _extractComparisonValue(rawCtx, fallback: '50');
        messages.add('Height must be at least $minValue cm.');
        continue;
      }

      if (field == 'weight' && rawMsg.contains('greater than or equal to')) {
        final minValue = _extractComparisonValue(rawCtx, fallback: '20');
        messages.add('Weight must be at least $minValue kg.');
        continue;
      }

      if (field == 'height') {
        messages.add('Please enter a valid height.');
        continue;
      }

      if (field == 'weight') {
        messages.add('Please enter a valid weight.');
        continue;
      }
    }

    if (messages.isEmpty) return null;

    return messages.toSet().join(' ');
  }

  static String? _formatDetailMessage(Map<String, dynamic> detail) {
    final code = detail['code']?.toString().trim().toLowerCase();

    if (code == 'daily_quota_exceeded') {
      final used = detail['used'];
      final limit = detail['limit'];
      final retryAt = _nextLocalMidnight();
      final retryTime = _formatRetryDateTime(retryAt);

      if (used is int && limit is int && limit > 0) {
        return 'Daily image limit reached ($used of $limit used). Try again at $retryTime.';
      }

      return 'Daily image limit reached. Try again at $retryTime.';
    }

    final message = detail['message']?.toString().trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }

    return null;
  }

  static DateTime _nextLocalMidnight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }

  static String _formatRetryDateTime(DateTime dateTime) {
    final month = _monthName(dateTime.month);
    final day = dateTime.day.toString();
    return '12:00 AM on $month $day (local time)';
  }

  static String _monthName(int month) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    if (month < 1 || month > 12) {
      return 'tomorrow';
    }

    return months[month - 1];
  }

  static String _extractComparisonValue(
    dynamic ctx, {
    required String fallback,
  }) {
    if (ctx is Map && ctx['ge'] != null) {
      final value = ctx['ge'].toString();
      if (value.endsWith('.0')) {
        return value.substring(0, value.length - 2);
      }
      return value;
    }

    return fallback;
  }

  static String _formatDateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String resolveMediaUrl(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return trimmed;
    if (_isLikelyLocalFilePath(trimmed)) {
      return '';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return '$baseUrl$trimmed';
    }
    return trimmed;
  }

  static String? _normalizeProfileImageUrlForRequest(String? path) {
    if (path == null) return null;

    final trimmed = path.trim();
    if (trimmed.isEmpty || _isLikelyLocalFilePath(trimmed)) {
      return null;
    }

    return trimmed;
  }

  static bool _isLikelyLocalFilePath(String path) {
    final normalized = path.trim().replaceAll('\\', '/').toLowerCase();
    if (normalized.isEmpty) return false;

    return normalized.startsWith('file://') ||
        normalized.startsWith('/data/user/') ||
        normalized.startsWith('data/user/') ||
        normalized.startsWith('/data/') ||
        normalized.contains('/android/data/') ||
        RegExp(r'^[a-z]:/').hasMatch(normalized);
  }
}
