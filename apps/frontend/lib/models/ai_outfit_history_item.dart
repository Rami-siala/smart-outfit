class AiWardrobeItemDetail {
  final String id;
  final String name;
  final String type;
  final String itemSubtype;
  final String category;
  final String color;
  final String material;
  final String season;
  final String imageUrl;
  final String visualDescription;
  final bool precipitationResistant;
  final bool wardrobeMatched;
  final String summary;

  const AiWardrobeItemDetail({
    this.id = '',
    this.name = '',
    this.type = '',
    this.itemSubtype = '',
    this.category = '',
    this.color = '',
    this.material = '',
    this.season = '',
    this.imageUrl = '',
    this.visualDescription = '',
    this.precipitationResistant = false,
    this.wardrobeMatched = false,
    this.summary = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'itemSubtype': itemSubtype,
      'item_subtype': itemSubtype,
      'category': category,
      'color': color,
      'material': material,
      'season': season,
      'imageUrl': imageUrl,
      'image_url': imageUrl,
      'visualDescription': visualDescription,
      'visual_description': visualDescription,
      'precipitationResistant': precipitationResistant,
      'precipitation_resistant': precipitationResistant,
      'wardrobeMatched': wardrobeMatched,
      'wardrobe_matched': wardrobeMatched,
      'summary': summary,
    };
  }

  factory AiWardrobeItemDetail.fromJson(Map<String, dynamic> json) {
    return AiWardrobeItemDetail(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      itemSubtype:
          json['itemSubtype']?.toString() ??
          json['item_subtype']?.toString() ??
          '',
      category: json['category']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      material: json['material']?.toString() ?? '',
      season: json['season']?.toString() ?? '',
      imageUrl:
          json['imageUrl']?.toString() ??
          json['image_url']?.toString() ??
          '',
      visualDescription:
          json['visualDescription']?.toString() ??
          json['visual_description']?.toString() ??
          '',
      precipitationResistant:
          json['precipitationResistant'] == true ||
          json['precipitation_resistant'] == true,
      wardrobeMatched:
          json['wardrobeMatched'] == true ||
          json['wardrobe_matched'] == true,
      summary: json['summary']?.toString() ?? '',
    );
  }
}

class AiOutfitHistoryItem {
  final String id;
  final String imageUrl;
  final String city;
  final String country;
  final String temperature;
  final String weather;
  final String style;
  final String color;
  final String gender;
  final String bodyShape;
  final String skinTone;
  final bool usedSelectedWardrobeItems;
  final List<AiWardrobeItemDetail>? _wardrobeItemsUsedDetails;
  final String savedAt;

  List<AiWardrobeItemDetail> get wardrobeItemsUsedDetails =>
      _wardrobeItemsUsedDetails ?? const <AiWardrobeItemDetail>[];

  const AiOutfitHistoryItem({
    required this.id,
    required this.imageUrl,
    required this.city,
    required this.country,
    required this.temperature,
    required this.weather,
    required this.style,
    required this.color,
    required this.gender,
    this.bodyShape = '',
    this.skinTone = '',
    this.usedSelectedWardrobeItems = false,
    List<AiWardrobeItemDetail>? wardrobeItemsUsedDetails,
    required this.savedAt,
  }) : _wardrobeItemsUsedDetails = wardrobeItemsUsedDetails;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'image_url': imageUrl,
      'city': city,
      'country': country,
      'temperature': temperature,
      'weather': weather,
      'style': style,
      'color': color,
      'gender': gender,
      'bodyShape': bodyShape,
      'body_shape': bodyShape,
      'skinTone': skinTone,
      'skin_tone': skinTone,
      'usedSelectedWardrobeItems': usedSelectedWardrobeItems,
      'used_selected_wardrobe_items': usedSelectedWardrobeItems,
      'wardrobeItemsUsedDetails': wardrobeItemsUsedDetails
          .map((item) => item.toJson())
          .toList(),
      'wardrobe_items_used_details': wardrobeItemsUsedDetails
          .map((item) => item.toJson())
          .toList(),
      'savedAt': savedAt,
      'saved_at': savedAt,
    };
  }

  factory AiOutfitHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawWardrobeDetails =
        json['wardrobeItemsUsedDetails'] ?? json['wardrobe_items_used_details'];
    final wardrobeItemsUsedDetails = rawWardrobeDetails is List
        ? rawWardrobeDetails
              .whereType<Map>()
              .map(
                (item) => AiWardrobeItemDetail.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <AiWardrobeItemDetail>[];

    return AiOutfitHistoryItem(
      id: json['id']?.toString() ?? '',
      imageUrl:
          json['imageUrl']?.toString() ??
          json['image_url']?.toString() ??
          '',
      city: json['city']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      temperature: json['temperature']?.toString() ?? '',
      weather: json['weather']?.toString() ?? '',
      style: json['style']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      bodyShape:
          json['bodyShape']?.toString() ??
          json['body_shape']?.toString() ??
          '',
      skinTone:
          json['skinTone']?.toString() ??
          json['skin_tone']?.toString() ??
          '',
      usedSelectedWardrobeItems:
          json['usedSelectedWardrobeItems'] == true ||
          json['used_selected_wardrobe_items'] == true,
      wardrobeItemsUsedDetails: wardrobeItemsUsedDetails,
      savedAt:
          json['savedAt']?.toString() ??
          json['saved_at']?.toString() ??
          '',
    );
  }
}
