import 'dart:convert';

import 'package:frontend/models/ai_outfit_history_item.dart';
import 'package:frontend/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiOutfitHistoryService {
  static const String _key = 'liked_ai_outfit_history';

  static Future<List<AiOutfitHistoryItem>> getHistory() async {
    try {
      final response = await ApiService.getAiOutfitHistory();
      final items = response
          .map(AiOutfitHistoryItem.fromJson)
          .where(_hasDisplayableImage)
          .toList(growable: false);

      await _saveCache(items);
      return items;
    } catch (_) {
      final cached = await _getCachedHistory();
      final filtered = cached.where(_hasDisplayableImage).toList(growable: false);

      if (filtered.length != cached.length) {
        await _saveCache(filtered);
      }

      return filtered;
    }
  }

  static Future<void> addItem(AiOutfitHistoryItem item) async {
    final saved = await ApiService.saveAiOutfitHistoryItem({
      'image_url': item.imageUrl,
      'city': item.city,
      'country': item.country,
      'temperature': item.temperature,
      'weather': item.weather,
      'style': item.style,
      'color': item.color,
      'gender': item.gender,
      'body_shape': item.bodyShape,
      'skin_tone': item.skinTone,
      'used_selected_wardrobe_items': item.usedSelectedWardrobeItems,
      'wardrobe_items_used_details': item.wardrobeItemsUsedDetails
          .map((detail) => detail.toJson())
          .toList(growable: false),
    });

    final savedItem = AiOutfitHistoryItem.fromJson(saved);
    final current = await _getCachedHistory();
    final updated = [
      savedItem,
      ...current.where((entry) => entry.id != savedItem.id),
    ];

    await _saveCache(updated);
  }

  static Future<void> removeItem(String id) async {
    await ApiService.deleteAiOutfitHistoryItem(id);
    final current = await _getCachedHistory();
    final updated = current.where((item) => item.id != id).toList();
    await _saveCache(updated);
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<List<AiOutfitHistoryItem>> _getCachedHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_key) ?? [];

    return rawList
        .map((raw) {
          try {
            final decoded = jsonDecode(raw) as Map<String, dynamic>;
            return AiOutfitHistoryItem.fromJson(decoded);
          } catch (_) {
            return null;
          }
        })
        .whereType<AiOutfitHistoryItem>()
        .toList(growable: false);
  }

  static bool _hasDisplayableImage(AiOutfitHistoryItem item) {
    final url = item.imageUrl.trim();
    return url.isNotEmpty &&
        (url.contains('/static/ai_outfit_history/') ||
            url.startsWith('http://') ||
            url.startsWith('https://'));
  }

  static Future<void> _saveCache(List<AiOutfitHistoryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      items.map((item) => jsonEncode(item.toJson())).toList(growable: false),
    );
  }
}
