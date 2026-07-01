import 'dart:io';

import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _navy = Color(0xFF173B6D);
const Color _midnight = Color(0xFF0D2240);
const Color _mist = Color(0xFFF3F7FB);
const Color _slate = Color(0xFF4E6688);
const Color _sky = Color(0xFF77B6EA);
const Color _peach = Color(0xFFFFD7C2);
const Color _mint = Color(0xFFCFEEDC);
const Color _gold = Color(0xFFF2C66D);

const List<String> _itemTypes = [
  'top',
  'bottom',
  'shoe',
  'outwear',
  'accessory',
];

const Map<String, List<String>> _itemSubtypesByType = {
  'top': ['t_shirt', 'polo', 'shirt', 'dress_shirt', 'hoodie', 'sweater', 'tank_top'],
  'bottom': ['shorts', 'jeans', 'joggers', 'trousers'],
  'shoe': ['sneakers', 'running_shoes', 'boots', 'loafers', 'sandals'],
  'outwear': ['blazer', 'coat', 'raincoat', 'puffer_jacket', 'denim_jacket'],
  'accessory': ['bag', 'watch', 'scarf', 'hat', 'belt'],
};

const List<String> _itemCategories = [
  'casual',
  'chic',
  'sport',
];

const List<String> _itemColors = [
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

const List<String> _itemSeasons = [
  'summer',
  'winter',
  'autumn',
  'spring',
];

class WardrobeDetailsScreen extends StatefulWidget {
  final int wardrobeId;
  final String wardrobeName;
  final bool isGuest;
  final Map<String, dynamic>? guestWardrobe;

  const WardrobeDetailsScreen({
    super.key,
    required this.wardrobeId,
    required this.wardrobeName,
    this.isGuest = false,
    this.guestWardrobe,
  });

  @override
  State<WardrobeDetailsScreen> createState() => _WardrobeDetailsScreenState();
}

class _WardrobeDetailsScreenState extends State<WardrobeDetailsScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _wardrobe;
  List<Map<String, dynamic>> _items = const [];
  Set<int> _favoriteItemIds = <int>{};
  String? _selectedSeasonFilter;
  String? _selectedTypeFilter;
  String? _selectedColorFilter;
  String? _selectedStyleFilter;

  @override
  void initState() {
    super.initState();
    _loadFavoriteItems();
    _loadData();
  }

  String get _favoriteItemsStorageKey =>
      'wardrobe_favorite_items_${widget.isGuest ? 'guest_' : ''}${widget.wardrobeId}';

  Future<void> _loadFavoriteItems() async {
    final prefs = await SharedPreferences.getInstance();
    final storedIds =
        prefs
            .getStringList(_favoriteItemsStorageKey)
            ?.map(int.tryParse)
            .whereType<int>()
            .toSet() ??
        <int>{};

    if (!mounted) return;
    setState(() {
      _favoriteItemIds = storedIds;
    });
  }

  Future<void> _persistFavoriteItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favoriteItemsStorageKey,
      _favoriteItemIds.map((id) => id.toString()).toList(),
    );
  }

  Future<void> _toggleFavoriteItem(Map<String, dynamic> item) async {
    final itemId = _asInt(item['id']);
    setState(() {
      if (_favoriteItemIds.contains(itemId)) {
        _favoriteItemIds.remove(itemId);
      } else {
        _favoriteItemIds.add(itemId);
      }
    });
    await _persistFavoriteItems();
  }

  void _closeGuestDetails() {
    if (!widget.isGuest) {
      Navigator.of(context).maybePop();
      return;
    }

    final wardrobe = Map<String, dynamic>.from(_wardrobe ?? widget.guestWardrobe ?? {});
    wardrobe['items'] = _items;
    wardrobe['updated_at'] = DateTime.now().toIso8601String();
    Navigator.of(context).pop(wardrobe);
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.isGuest) {
        final wardrobe = Map<String, dynamic>.from(widget.guestWardrobe ?? {});
        final items = ((wardrobe['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();

        if (!mounted) return;

        final validIds = items.map((item) => _asInt(item['id'])).toSet();

        setState(() {
          _wardrobe = wardrobe;
          _items = items;
          _favoriteItemIds = _favoriteItemIds.where(validIds.contains).toSet();
          _error = null;
        });
        return;
      }

      final wardrobeFuture = ApiService.getWardrobe(widget.wardrobeId);
      final itemsFuture = ApiService.getWardrobeItems(widget.wardrobeId);

      final wardrobe = await wardrobeFuture;
      List<Map<String, dynamic>> items = const [];
      String? loadWarning;

      try {
        items = await itemsFuture;
      } catch (e) {
        loadWarning = e.toString().replaceFirst('Exception: ', '');
      }

      if (!mounted) return;

      final validIds = items.map((item) => _asInt(item['id'])).toSet();

      setState(() {
        _wardrobe = Map<String, dynamic>.from(wardrobe);
        _items = List<Map<String, dynamic>>.from(items);
        _favoriteItemIds = _favoriteItemIds.where(validIds.contains).toSet();
        _error = loadWarning;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openItemForm({Map<String, dynamic>? item}) async {
    final nameController = TextEditingController(
      text: item?['name']?.toString() ?? '',
    );
    final materialController = TextEditingController(
      text: item?['material']?.toString() ?? '',
    );
    var selectedType = item?['type']?.toString() ?? _itemTypes.first;
    var selectedSubtype =
        _normalizeItemSubtype(item?['item_subtype']?.toString()) ??
        _defaultSubtypeForType(selectedType);
    var selectedCategory =
        _normalizeItemCategory(item?['category']?.toString()) ??
        _itemCategories.first;
    String? selectedColor = item?['color']?.toString();
    String? selectedSeason = item?['season']?.toString();
    var precipitationResistant = _asBool(item?['precipitation_resistant']);
    final initialImagePath = item?['image_url']?.toString();
    String? selectedImagePath = initialImagePath;
    var isSaving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF7F9FC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_peach, _gold],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.checkroom_rounded,
                          color: _midnight,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item == null
                                  ? 'Create wardrobe item'
                                  : 'Edit wardrobe item',
                              style: const TextStyle(
                                color: _navy,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add a polished piece with style, season, and image details.',
                              style: TextStyle(
                                color: _slate.withValues(alpha: 0.92),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _dialogPill(
                        icon: _itemTypeIcon(selectedType),
                        label: _capitalizeLabel(selectedType),
                      ),
                      _dialogPill(
                        icon: _itemSubtypeIcon(selectedSubtype),
                        label: _capitalizeLabel(selectedSubtype),
                      ),
                      _dialogPill(
                        icon: _styleIcon(selectedCategory),
                        label: _capitalizeLabel(selectedCategory),
                      ),
                      _dialogPill(
                        icon: selectedSeason == null
                            ? Icons.calendar_month_outlined
                            : _seasonIcon(selectedSeason!),
                        label: selectedSeason == null
                            ? 'Any season'
                            : _capitalizeLabel(selectedSeason!),
                      ),
                      _dialogPill(
                        colorDot: selectedColor == null
                            ? null
                            : _itemColorValue(selectedColor!),
                        icon: selectedColor == null
                            ? Icons.palette_outlined
                            : null,
                        label: selectedColor == null
                            ? 'Open color'
                            : _capitalizeLabel(selectedColor!),
                      ),
                    ],
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dialogSectionHeader(
                              icon: Icons.badge_outlined,
                              title: 'Item identity',
                              subtitle: 'Name the piece and describe it clearly.',
                            ),
                            const SizedBox(height: 12),
                            _textField(
                              controller: nameController,
                              label: 'Name',
                              hint: 'White sneakers',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _navy.withValues(alpha: 0.96),
                              const Color(0xFF2E5D96),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Smart styling preview',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_capitalizeLabel(selectedSubtype)} ${_capitalizeLabel(selectedType)} pieces in ${_capitalizeLabel(selectedCategory)} style${selectedSeason != null ? ' for ${_capitalizeLabel(selectedSeason!)}' : ''}${selectedColor != null ? ' with a ${_capitalizeLabel(selectedColor!)} palette' : ''} are easier to recommend in outfit generation.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.86),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dialogSectionHeader(
                              icon: Icons.style_outlined,
                              title: 'Style details',
                              subtitle:
                                  'Describe how the item should behave in wardrobe suggestions.',
                            ),
                            const SizedBox(height: 12),
                            _dropdownField<String>(
                              value: selectedType,
                              label: 'Type',
                              leadingIcon: _itemTypeIcon(selectedType),
                              showSelectedItemIcon: false,
                              items: _itemTypes
                                  .map(
                                    (value) => _dropdownTextItem<String>(
                                      value: value,
                                      label: _capitalizeLabel(value),
                                      icon: _itemTypeIcon(value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setStateDialog(() {
                                  selectedType = value;
                                  final subtypeOptions =
                                      _subtypesForType(selectedType);
                                  if (!subtypeOptions.contains(selectedSubtype)) {
                                    selectedSubtype = subtypeOptions.first;
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            _dropdownField<String>(
                              value: selectedSubtype,
                              label: 'Subtype',
                              leadingIcon: _itemSubtypeIcon(selectedSubtype),
                              showSelectedItemIcon: false,
                              items: _subtypesForType(selectedType)
                                  .map(
                                    (value) => _dropdownTextItem<String>(
                                      value: value,
                                      label: _capitalizeLabel(value),
                                      icon: _itemSubtypeIcon(value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setStateDialog(() {
                                  selectedSubtype = value;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            _dropdownField<String>(
                              value: selectedCategory,
                              label: 'Category',
                              leadingIcon: _styleIcon(selectedCategory),
                              showSelectedItemIcon: false,
                              items: _itemCategories
                                  .map(
                                    (value) => _dropdownTextItem<String>(
                                      value: value,
                                      label: _capitalizeLabel(value),
                                      icon: _styleIcon(value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setStateDialog(() {
                                  selectedCategory = value;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            _dropdownField<String?>(
                              value: selectedColor,
                              label: 'Color',
                              leadingIcon: Icons.palette_outlined,
                              items: [
                                _dropdownTextItem<String?>(
                                  value: null,
                                  label: 'No color',
                                  icon: Icons.block_outlined,
                                ),
                                ..._itemColors.map(
                                  (value) => _dropdownColorItem<String?>(
                                    value: value,
                                    label: _capitalizeLabel(value),
                                    color: _itemColorValue(value),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setStateDialog(() {
                                  selectedColor = value;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            _textField(
                              controller: materialController,
                              label: 'Material',
                              hint: 'Cotton',
                            ),
                            const SizedBox(height: 12),
                            _dropdownField<String?>(
                              value: selectedSeason,
                              label: 'Season',
                              leadingIcon: selectedSeason == null
                                  ? Icons.calendar_month_outlined
                                  : _seasonIcon(selectedSeason!),
                              showSelectedItemIcon: false,
                              items: [
                                _dropdownTextItem<String?>(
                                  value: null,
                                  label: 'No season',
                                  icon: Icons.calendar_today_outlined,
                                ),
                                ..._itemSeasons.map(
                                  (value) => _dropdownTextItem<String?>(
                                    value: value,
                                    label: _capitalizeLabel(value),
                                    icon: _seasonIcon(value),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setStateDialog(() {
                                  selectedSeason = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _dialogSectionHeader(
                            icon: Icons.image_outlined,
                            title: 'Visual reference',
                            subtitle:
                                'A clean photo helps styling and wardrobe recognition feel more accurate.',
                          ),
                          const SizedBox(height: 10),
                          _buildImagePickerCard(
                            imagePath: selectedImagePath,
                            onTakePhoto: () async {
                              final path = await _pickItemImage(ImageSource.camera);
                              if (path == null) return;
                              setStateDialog(() {
                                selectedImagePath = path;
                              });
                            },
                            onPickGallery: () async {
                              final path = await _pickItemImage(ImageSource.gallery);
                              if (path == null) return;
                              setStateDialog(() {
                                selectedImagePath = path;
                              });
                            },
                            onRemoveImage: selectedImagePath == null
                                ? null
                                : () {
                                    setStateDialog(() {
                                      selectedImagePath = null;
                                    });
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () {
                            setStateDialog(() {
                              precipitationResistant = !precipitationResistant;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: precipitationResistant
                                        ? const Color(0xFFE5F7EF)
                                        : _mist,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.water_drop_outlined,
                                    color: precipitationResistant
                                        ? const Color(0xFF2C7C61)
                                        : _navy,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Rain-ready item',
                                        style: TextStyle(
                                          color: _navy,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        precipitationResistant
                                            ? 'This piece is marked as suitable for wet weather.'
                                            : 'Tap to mark this item as suitable for rainy conditions.',
                                        style: const TextStyle(
                                          color: _slate,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  activeThumbColor: _navy,
                                  value: precipitationResistant,
                                  onChanged: (value) {
                                    setStateDialog(() {
                                      precipitationResistant = value;
                                    });
                                  },
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
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: _navy,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final typedName = nameController.text.trim();
                          final name = typedName.isNotEmpty
                              ? typedName
                              : _buildGeneratedItemName(
                                  type: selectedType,
                                  subtype: selectedSubtype,
                                  category: selectedCategory,
                                  color: selectedColor,
                                );

                          setStateDialog(() {
                            isSaving = true;
                          });

                          try {
                            if (widget.isGuest) {
                              final guestItem = <String, dynamic>{
                                'id': item != null
                                    ? _asInt(item['id'])
                                    : DateTime.now().microsecondsSinceEpoch,
                                'wardrobe_id': widget.wardrobeId,
                                'name': name,
                                'type': selectedType,
                                'item_subtype': selectedSubtype,
                                'category': selectedCategory,
                                'color': selectedColor,
                                'material': _optionalText(materialController.text),
                                'season': selectedSeason,
                                'image_url': selectedImagePath,
                                'precipitation_resistant': precipitationResistant,
                                'updated_at': DateTime.now().toIso8601String(),
                                'created_at': item?['created_at']?.toString() ??
                                    DateTime.now().toIso8601String(),
                              };

                              if (!mounted) return;

                              setState(() {
                                if (item == null) {
                                  _items = [..._items, guestItem];
                                } else {
                                  _items = _items
                                      .map(
                                        (existing) => _asInt(existing['id']) ==
                                                _asInt(item['id'])
                                            ? guestItem
                                            : existing,
                                      )
                                      .toList();
                                }
                                _wardrobe = {
                                  ...?_wardrobe,
                                  'items': _items,
                                  'updated_at':
                                      DateTime.now().toIso8601String(),
                                };
                              });
                            } else if (item == null) {
                              await ApiService.createWardrobeItem(
                                wardrobeId: widget.wardrobeId,
                                name: name,
                                type: selectedType,
                                itemSubtype: selectedSubtype,
                                category: selectedCategory,
                                color: selectedColor,
                                material: _optionalText(materialController.text),
                                season: selectedSeason,
                                imageFilePath: _deviceImagePath(selectedImagePath),
                                precipitationResistant: precipitationResistant,
                              );
                            } else {
                              await ApiService.updateWardrobeItem(
                                itemId: _asInt(item['id']),
                                name: name,
                                type: selectedType,
                                itemSubtype: selectedSubtype,
                                category: selectedCategory,
                                color: selectedColor,
                                material: _optionalText(materialController.text),
                                season: selectedSeason,
                                imageUrl: _isBackendImagePath(selectedImagePath)
                                    ? selectedImagePath
                                    : null,
                                imageFilePath: _deviceImagePath(selectedImagePath),
                                removeImage: initialImagePath != null &&
                                    initialImagePath.isNotEmpty &&
                                    (selectedImagePath == null ||
                                        selectedImagePath?.isEmpty == true),
                                precipitationResistant: precipitationResistant,
                              );
                            }

                            if (context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              _showSnackBar(
                                e.toString().replaceFirst('Exception: ', ''),
                              );
                            }

                            setStateDialog(() {
                              isSaving = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(item == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      if (widget.isGuest) {
        _showSnackBar(item == null ? 'Wardrobe item added' : 'Wardrobe item updated');
      } else {
        await _loadData();
      }
    }
  }

  Future<void> _confirmDeleteItem(Map<String, dynamic> item) async {
    final confirmed = await _confirmDelete(
      title: 'Delete item',
      message: 'Delete "${item['name'] ?? 'this item'}"?',
    );

    if (!confirmed) return;

    try {
      _favoriteItemIds.remove(_asInt(item['id']));
      await _persistFavoriteItems();
      if (widget.isGuest) {
        setState(() {
          _items = _items
              .where((existing) => _asInt(existing['id']) != _asInt(item['id']))
              .toList();
          _wardrobe = {
            ...?_wardrobe,
            'items': _items,
            'updated_at': DateTime.now().toIso8601String(),
          };
        });
      } else {
        await ApiService.deleteWardrobeItem(_asInt(item['id']));
        await _loadData();
      }
      _showSnackBar('Wardrobe item deleted');
    } catch (e) {
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isGuest,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !widget.isGuest) return;
        _closeGuestDetails();
      },
      child: Scaffold(
        backgroundColor: _mist,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _isLoading
            ? null
            : SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      heroTag: 'add_item',
                      backgroundColor: _navy.withValues(alpha: 0.82),
                      foregroundColor: Colors.white,
                      elevation: 10,
                      onPressed: () => _openItemForm(),
                      child: const Icon(Icons.add_rounded, size: 30),
                    ),
                  ],
                ),
              ),
        body: RefreshIndicator(
          onRefresh: _loadData,
          color: _navy,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _navy),
      );
    }

    final wardrobe = _wardrobe;

    if (wardrobe == null) {
      final message = _error == null || _error!.trim().isEmpty
          ? 'Wardrobe not found. Requested wardrobe ID: ${widget.wardrobeId}.'
          : '${_error!}\nRequested wardrobe ID: ${widget.wardrobeId}.';
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 132),
        children: [
          _buildTopBar(),
          const SizedBox(height: 18),
          _buildErrorCard(message),
        ],
      );
    }

    final filteredItems = _filteredItems;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 132),
      children: [
        _buildTopBar(),
        const SizedBox(height: 18),
        if (_error != null) ...[
          _buildErrorCard(_error!),
          const SizedBox(height: 18),
        ],
        _buildWardrobeSummary(wardrobe),
        const SizedBox(height: 18),
        _buildOverviewRow(),
        const SizedBox(height: 22),
        _buildSectionHeader(
          title: 'Wardrobe items',
          subtitle: 'Pieces stored in this collection',
        ),
        const SizedBox(height: 12),
        _buildFiltersPanel(),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          _buildEmptyCard(
            title: 'No items yet',
            description:
                'Add your first wardrobe item to start building this collection.',
          )
        else if (filteredItems.isEmpty)
          _buildEmptyCard(
            title: _filteredItemsTitle(),
            description:
                'There are no wardrobe items for these filters yet. Try another filter or add a new item.',
          )
        else
          _buildItemsGrid(filteredItems),
      ],
    );
  }

  Widget _buildWardrobeSummary(Map<String, dynamic> wardrobe) {
    final description = wardrobe['description']?.toString() ?? '';
    final address = wardrobe['address']?.toString() ?? '';
    final createdAt = _formatDate(wardrobe['created_at']?.toString());

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _midnight,
            _navy,
            Color(0xFF3567A4),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _midnight.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: 4,
            child: _glowBubble(_sky.withValues(alpha: 0.22), 76),
          ),
          Positioned(
            right: 44,
            bottom: -18,
            child: _glowBubble(_gold.withValues(alpha: 0.16), 58),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.checkroom_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Wardrobe details',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          wardrobe['name']?.toString() ?? widget.wardrobeName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _summaryPill(
                    icon: Icons.layers_outlined,
                    label: '${_items.length} items',
                  ),
                  if (address.isNotEmpty)
                    _summaryPill(
                      icon: Icons.location_on_outlined,
                      label: address,
                    ),
                  if (createdAt != null)
                    _summaryPill(
                      icon: Icons.event_outlined,
                      label: createdAt,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsGrid(List<Map<String, dynamic>> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final childAspectRatio = width < 360
            ? 0.62
            : width < 420
                ? 0.60
                : width < 520
                    ? 0.64
                    : 0.70;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 1),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 4,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) => _buildItemCatalogCard(items[index]),
        );
      },
    );
  }

  List<Map<String, dynamic>> get _filteredItems {
    return _items.where((item) {
      final season = item['season']?.toString().trim().toLowerCase();
      final type = item['type']?.toString().trim().toLowerCase();
      final color = item['color']?.toString().trim().toLowerCase();
      final style = _normalizeItemCategory(item['category']?.toString());

      final matchesSeason =
          _selectedSeasonFilter == null || season == _selectedSeasonFilter;
      final matchesType =
          _selectedTypeFilter == null || type == _selectedTypeFilter;
      final matchesColor =
          _selectedColorFilter == null || color == _selectedColorFilter;
      final matchesStyle =
          _selectedStyleFilter == null || style == _selectedStyleFilter;

      return matchesSeason && matchesType && matchesColor && matchesStyle;
    }).toList();
  }

  String _filteredItemsTitle() {
    final labels = <String>[
      if (_selectedTypeFilter != null) _capitalizeLabel(_selectedTypeFilter!),
      if (_selectedColorFilter != null) _capitalizeLabel(_selectedColorFilter!),
      if (_selectedStyleFilter != null) _capitalizeLabel(_selectedStyleFilter!),
      if (_selectedSeasonFilter != null) _capitalizeLabel(_selectedSeasonFilter!),
    ];

    if (labels.isEmpty) return 'No matching items';

    return 'No ${labels.join(' / ')} items';
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: _closeGuestDetails,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _navy,
          ),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _wardrobe?['name']?.toString() ?? widget.wardrobeName,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isGuest
                    ? 'Organize pieces and keep this temporary guest wardrobe polished.'
                    : 'Organize pieces and keep this wardrobe polished.',
                style: TextStyle(
                  color: _slate,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: _loadData,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _navy,
          ),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _buildOverviewRow() {
    final rainReady = _items.where((item) {
      return _asBool(item['precipitation_resistant']);
    }).length;
    final favorites = _items.where((item) {
      return _favoriteItemIds.contains(_asInt(item['id']));
    }).length;
    final stylesCount = _items
        .map((item) => _normalizeItemCategory(item['category']?.toString()) ?? '')
        .where((style) => style.isNotEmpty)
        .toSet()
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _overviewCard(
                title: 'Items',
                value: '${_items.length}',
                subtitle: 'Pieces saved',
                color: _peach,
                icon: Icons.inventory_2_rounded,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _overviewCard(
                title: 'Rain-ready',
                value: '$rainReady',
                subtitle: 'Weather-proof',
                color: _mint,
                icon: Icons.water_drop_outlined,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _overviewCard(
                title: 'Favorites',
                value: '$favorites',
                subtitle: 'Favorite items',
                color: const Color(0xFFD7D8FF),
                icon: Icons.favorite_outline_rounded,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _overviewCard(
                title: 'Styles',
                value: '$stylesCount',
                subtitle: 'Style types',
                color: const Color(0xFFFFE7B8),
                icon: Icons.auto_awesome_outlined,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _overviewCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _midnight, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: _navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: _navy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: _slate,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onPressed,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _slate,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onPressed != null)
          FilledButton.tonalIcon(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _navy,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(actionLabel),
          ),
      ],
    );
  }

  int get _activeFilterCount {
    var count = 0;
    if (_selectedTypeFilter != null) count++;
    if (_selectedColorFilter != null) count++;
    if (_selectedStyleFilter != null) count++;
    if (_selectedSeasonFilter != null) count++;
    return count;
  }

  Widget _buildFiltersPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _mist,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      size: 15,
                      color: _navy,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _activeFilterCount == 0
                          ? 'Smart filters'
                          : '$_activeFilterCount active',
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _activeFilterCount == 0
                    ? null
                    : () {
                        setState(() {
                          _selectedTypeFilter = null;
                          _selectedColorFilter = null;
                          _selectedStyleFilter = null;
                          _selectedSeasonFilter = null;
                        });
                      },
                child: const Text('Clear all'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Filter your catalog faster',
            style: TextStyle(
              color: _navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose a type, color, style, or season from compact selectors.',
            style: TextStyle(
              color: _slate,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          if (_activeFilterCount > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_selectedTypeFilter != null)
                  _activeFilterPill(
                    label: 'Type: ${_capitalizeLabel(_selectedTypeFilter!)}',
                    onTap: () => setState(() => _selectedTypeFilter = null),
                  ),
                if (_selectedColorFilter != null)
                  _activeFilterPill(
                    label: 'Color: ${_capitalizeLabel(_selectedColorFilter!)}',
                    onTap: () => setState(() => _selectedColorFilter = null),
                  ),
                if (_selectedStyleFilter != null)
                  _activeFilterPill(
                    label: 'Style: ${_capitalizeLabel(_selectedStyleFilter!)}',
                    onTap: () => setState(() => _selectedStyleFilter = null),
                  ),
                if (_selectedSeasonFilter != null)
                  _activeFilterPill(
                    label: 'Season: ${_capitalizeLabel(_selectedSeasonFilter!)}',
                    onTap: () => setState(() => _selectedSeasonFilter = null),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: _filterSelectorTile(
                      title: 'Type',
                      value: _selectedTypeFilter == null
                          ? 'All types'
                          : _capitalizeLabel(_selectedTypeFilter!),
                      icon: _selectedTypeFilter == null
                          ? Icons.apps_rounded
                          : _itemTypeIcon(_selectedTypeFilter!),
                      onTap: () => _showFilterPicker<String>(
                        title: 'Select type',
                        selectedValue: _selectedTypeFilter,
                        options: [
                          const _FilterOption(
                            value: null,
                            label: 'All types',
                            icon: Icons.apps_rounded,
                          ),
                          ..._itemTypes.map(
                            (type) => _FilterOption<String>(
                              value: type,
                              label: _capitalizeLabel(type),
                              icon: _itemTypeIcon(type),
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          setState(() {
                            _selectedTypeFilter = value;
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _filterSelectorTile(
                      title: 'Color',
                      value: _selectedColorFilter == null
                          ? 'All colors'
                          : _capitalizeLabel(_selectedColorFilter!),
                      icon: Icons.palette_outlined,
                      colorDot: _selectedColorFilter == null
                          ? null
                          : _itemColorValue(_selectedColorFilter!),
                      onTap: () => _showFilterPicker<String>(
                        title: 'Select color',
                        selectedValue: _selectedColorFilter,
                        options: [
                          const _FilterOption(
                            value: null,
                            label: 'All colors',
                            icon: Icons.palette_outlined,
                          ),
                          ..._itemColors.map(
                            (color) => _FilterOption<String>(
                              value: color,
                              label: _capitalizeLabel(color),
                              colorDot: _itemColorValue(color),
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          setState(() {
                            _selectedColorFilter = value;
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _filterSelectorTile(
                      title: 'Style',
                      value: _selectedStyleFilter == null
                          ? 'All styles'
                          : _capitalizeLabel(_selectedStyleFilter!),
                      icon: _selectedStyleFilter == null
                          ? Icons.style_outlined
                          : _styleIcon(_selectedStyleFilter!),
                      onTap: () => _showFilterPicker<String>(
                        title: 'Select style',
                        selectedValue: _selectedStyleFilter,
                        options: [
                          const _FilterOption(
                            value: null,
                            label: 'All styles',
                            icon: Icons.style_outlined,
                          ),
                          ..._itemCategories.map(
                            (style) => _FilterOption<String>(
                              value: style,
                              label: _capitalizeLabel(style),
                              icon: _styleIcon(style),
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          setState(() {
                            _selectedStyleFilter = value;
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _filterSelectorTile(
                      title: 'Season',
                      value: _selectedSeasonFilter == null
                          ? 'All seasons'
                          : _capitalizeLabel(_selectedSeasonFilter!),
                      icon: _selectedSeasonFilter == null
                          ? Icons.calendar_month_outlined
                          : _seasonIcon(_selectedSeasonFilter!),
                      onTap: () => _showFilterPicker<String>(
                        title: 'Select season',
                        selectedValue: _selectedSeasonFilter,
                        options: [
                          const _FilterOption(
                            value: null,
                            label: 'All seasons',
                            icon: Icons.calendar_month_outlined,
                          ),
                          ..._itemSeasons.map(
                            (season) => _FilterOption<String>(
                              value: season,
                              label: _capitalizeLabel(season),
                              icon: _seasonIcon(season),
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          setState(() {
                            _selectedSeasonFilter = value;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _filterSelectorTile({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    Color? colorDot,
  }) {
    return Material(
      color: _mist,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _navy.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: colorDot == null
                    ? Icon(icon, size: 18, color: _navy)
                    : Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: colorDot,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorDot == Colors.white
                                  ? _navy.withValues(alpha: 0.18)
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _slate,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _navy.withValues(alpha: 0.72),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeFilterPill({
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _navy,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.close_rounded,
                size: 14,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFilterPicker<T>({
    required String title,
    required T? selectedValue,
    required List<_FilterOption<T>> options,
    required ValueChanged<T?> onSelected,
  }) async {
    final result = await showModalBottomSheet<_FilterPickerResult<T>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 52,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9E1EC),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final isSelected = option.value == selectedValue;
                        return Material(
                          color: isSelected ? _navy : _mist,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => Navigator.of(context).pop(
                              _FilterPickerResult<T>(value: option.value),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.14)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: option.colorDot == null
                                        ? Icon(
                                            option.icon ?? Icons.tune_rounded,
                                            size: 18,
                                            color: isSelected ? Colors.white : _navy,
                                          )
                                        : Center(
                                            child: Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: option.colorDot,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: option.colorDot == Colors.white
                                                      ? _navy.withValues(alpha: 0.18)
                                                      : Colors.transparent,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      option.label,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : _navy,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result != null) {
      onSelected(result.value);
    }
  }

  Widget _buildItemCatalogCard(Map<String, dynamic> item) {
    final itemId = _asInt(item['id']);
    final isFavorite = _favoriteItemIds.contains(itemId);
    final type = item['type']?.toString() ?? '';
    final subtype = _normalizeItemSubtype(item['item_subtype']?.toString()) ?? '';
    final category = _normalizeItemCategory(item['category']?.toString()) ?? '';
    final color = item['color']?.toString() ?? '';
    final season = item['season']?.toString() ?? '';
    final imagePath = item['image_url']?.toString() ?? '';
    final resistant = _asBool(item['precipitation_resistant']);
    final material = item['material']?.toString() ?? '';
    final subtitleParts = <String>[
      if (subtype.isNotEmpty) _capitalizeLabel(subtype),
      if (type.isNotEmpty) _capitalizeLabel(type),
      if (category.isNotEmpty) _capitalizeLabel(category),
    ];
    final detailTags = <String>[
      if (color.isNotEmpty) _capitalizeLabel(color),
      if (season.isNotEmpty) _capitalizeLabel(season),
      if (material.isNotEmpty) material,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 170;
        final imageCard = Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(compact ? 18 : 22),
                child: imagePath.isNotEmpty
                    ? _buildItemImage(imagePath)
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_peach, _gold],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.checkroom_rounded,
                            color: _midnight,
                            size: compact ? 34 : 40,
                          ),
                        ),
                      ),
              ),
            ),
            Positioned(
              top: compact ? 6 : 8,
              left: compact ? 6 : 8,
              child: _cardActionButton(
                icon: isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                tooltip: isFavorite ? 'Remove favorite' : 'Mark favorite',
                color: isFavorite ? const Color(0xFFC6546A) : _navy,
                onTap: () => _toggleFavoriteItem(item),
                size: compact ? 30 : 34,
                iconSize: compact ? 15 : 17,
                fillColor: isFavorite
                    ? const Color(0xFFFFEEF2)
                    : Colors.white.withValues(alpha: 0.94),
              ),
            ),
            Positioned(
              top: compact ? 6 : 8,
              right: compact ? 6 : 8,
              child: Column(
                children: [
                  _cardActionButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit item',
                    onTap: () => _openItemForm(item: item),
                    size: compact ? 30 : 34,
                    iconSize: compact ? 15 : 17,
                    fillColor: Colors.white.withValues(alpha: 0.94),
                  ),
                  SizedBox(height: compact ? 6 : 8),
                  _cardActionButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete item',
                    color: const Color(0xFFC6546A),
                    onTap: () => _confirmDeleteItem(item),
                    size: compact ? 30 : 34,
                    iconSize: compact ? 15 : 17,
                    fillColor: Colors.white.withValues(alpha: 0.94),
                  ),
                ],
              ),
            ),
            if (resistant)
              Positioned(
                left: compact ? 6 : 8,
                bottom: compact ? 6 : 8,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 8 : 10,
                    vertical: compact ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F7EF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Rain-ready',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF2C7C61),
                      fontSize: compact ? 8.8 : 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        );

        return Align(
          alignment: Alignment.topCenter,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(compact ? 24 : 28),
              boxShadow: [
                BoxShadow(
                  color: _navy.withValues(alpha: 0.06),
                  blurRadius: compact ? 16 : 20,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 8 : 10,
                compact ? 8 : 10,
                compact ? 8 : 10,
                compact ? 10 : 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: compact ? 0.98 : 0.98,
                    child: imageCard,
                  ),
                  SizedBox(height: compact ? 5 : 10),
                  Text(
                    item['name']?.toString() ?? 'Unnamed item',
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _navy,
                      fontSize: compact ? 13.4 : 15,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: compact ? 2 : 5),
                  Text(
                    subtitleParts.isEmpty
                        ? 'Wardrobe item'
                        : subtitleParts.join(' | '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _slate,
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (detailTags.isNotEmpty) ...[
                    SizedBox(height: compact ? 5 : 8),
                    compact
                        ? SizedBox(
                            height: 22,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (var index = 0;
                                      index < detailTags.length;
                                      index++) ...[
                                    if (index > 0) const SizedBox(width: 4),
                                    _miniTag(
                                      detailTags[index],
                                      compact: true,
                                      fontSize: 8.6,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final tag in detailTags)
                                _miniTag(
                                  tag,
                                  fontSize: 10,
                                ),
                            ],
                          ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _pickItemImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      return pickedFile?.path;
    } catch (_) {
      _showSnackBar('Unable to pick image right now');
      return null;
    }
  }

  Widget _buildImagePickerCard({
    required String? imagePath,
    required Future<void> Function() onTakePhoto,
    required Future<void> Function() onPickGallery,
    required VoidCallback? onRemoveImage,
  }) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _navy.withValues(alpha: 0.16),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 170,
                decoration: BoxDecoration(
                  color: _mist,
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: imagePath != null && imagePath.isNotEmpty
                    ? _buildItemImage(imagePath)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 34,
                            color: _navy,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Capture Item',
                            style: TextStyle(
                              color: _navy,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Clear, well-lit photos work best for AI style suggestions',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _slate,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onTakePhoto,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Take Photo'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: onPickGallery,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE9EDF3),
                        foregroundColor: _navy,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
              if (onRemoveImage != null) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onRemoveImage,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove image'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemImage(String imagePath) {
    if (_isBackendImagePath(imagePath)) {
      return Image.network(
        ApiService.resolveMediaUrl(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _brokenItemImage();
        },
      );
    }

    final file = File(imagePath);
    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _brokenItemImage();
      },
    );
  }

  Widget _brokenItemImage() {
    return Container(
      color: _mist,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: _navy,
        size: 30,
      ),
    );
  }

  bool _isBackendImagePath(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) return false;
    final normalized = imagePath.trim();
    return normalized.startsWith('/static/') ||
        normalized.startsWith('http://') ||
        normalized.startsWith('https://');
  }

  String? _deviceImagePath(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) return null;
    if (_isBackendImagePath(imagePath)) return null;
    return imagePath;
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Colors.red,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard({
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_peach, _gold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.inbox_rounded,
              color: _midnight,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: _navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _slate,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowBubble(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _miniTag(
    String label, {
    bool compact = false,
    double fontSize = 10,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: _mist,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _navy,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _dialogSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _mist,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _navy, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _slate,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dialogPill({
    IconData? icon,
    Color? colorDot,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _navy.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (colorDot != null)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colorDot,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorDot == Colors.white
                      ? _navy.withValues(alpha: 0.16)
                      : Colors.transparent,
                ),
              ),
            )
          else if (icon != null)
            Icon(icon, size: 14, color: _navy),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _navy,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = _navy,
    double size = 38,
    double iconSize = 20,
    Color? fillColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: fillColor ?? color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        elevation: fillColor == null ? 0 : 2,
        shadowColor: _navy.withValues(alpha: 0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: color, size: iconSize),
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: _mist,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _dropdownField<T>({
    required T value,
    required String label,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    IconData? leadingIcon,
    bool showSelectedItemIcon = true,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FBFF),
        labelStyle: const TextStyle(
          color: _slate,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelStyle: const TextStyle(
          color: _navy,
          fontWeight: FontWeight.w800,
        ),
        prefixIcon: leadingIcon == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 4, right: 2),
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _navy.withValues(alpha: 0.10),
                        const Color(0xFFD970C4).withValues(alpha: 0.14),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(leadingIcon, color: _navy, size: 18),
                ),
              ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 52,
          minHeight: 44,
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 18, 14, 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: _navy.withValues(alpha: 0.10),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: _navy,
            width: 1.5,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          selectedItemBuilder: showSelectedItemIcon
              ? null
              : (context) => items
                    .map(
                      (item) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _dropdownItemLabel(item),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                    .toList(),
          borderRadius: BorderRadius.circular(22),
          dropdownColor: Colors.white,
          menuMaxHeight: 320,
          icon: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _navy,
              size: 18,
            ),
          ),
          style: const TextStyle(
            color: _navy,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  String _dropdownItemLabel<T>(DropdownMenuItem<T> item) {
    final child = item.child;
    if (child is Row) {
      for (final widget in child.children) {
        if (widget is Expanded && widget.child is Text) {
          return (widget.child as Text).data ?? '';
        }
        if (widget is Text) {
          return widget.data ?? '';
        }
      }
    }
    if (child is Text) {
      return child.data ?? '';
    }
    return '';
  }

  DropdownMenuItem<T> _dropdownTextItem<T>({
    required T value,
    required String label,
    IconData? icon,
  }) {
    return DropdownMenuItem<T>(
      value: value,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon ?? Icons.label_outline_rounded,
              color: _navy,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _navy,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  DropdownMenuItem<T> _dropdownColorItem<T>({
    required T value,
    required String label,
    required Color color,
  }) {
    return DropdownMenuItem<T>(
      value: value,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: color == Colors.white ? 0.94 : 1),
                  color == Colors.white
                      ? const Color(0xFFF4F6FA)
                      : color.withValues(alpha: 0.72),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color == Colors.white
                    ? _navy.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _navy,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.parse(value.toString());
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value?.toString().toLowerCase() == 'true';
}



String? _optionalText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return null;

  try {
    final date = DateTime.parse(iso).toLocal();
    final month = _monthLabel(date.month);
    return '$month ${date.day}, ${date.year}';
  } catch (_) {
    return null;
  }
}

String _monthLabel(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return months[month - 1];
}

String _capitalizeLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return normalized;
  return normalized
      .split(RegExp(r'[\s\-_]+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _buildGeneratedItemName({
  required String type,
  required String subtype,
  required String category,
  String? color,
}) {
  final parts = <String>[
    subtype.trim().toLowerCase(),
    type.trim().toLowerCase(),
    category.trim().toLowerCase(),
    if (color != null && color.trim().isNotEmpty) color.trim().toLowerCase(),
  ];

  return parts.join(' ').trim();
}

IconData _seasonIcon(String season) {
  switch (season.trim().toLowerCase()) {
    case 'summer':
      return Icons.wb_sunny_outlined;
    case 'winter':
      return Icons.ac_unit_rounded;
    case 'autumn':
      return Icons.park_outlined;
    case 'spring':
      return Icons.local_florist_outlined;
    default:
      return Icons.filter_alt_outlined;
  }
}

IconData _itemTypeIcon(String type) {
  switch (type.trim().toLowerCase()) {
    case 'top':
      return Icons.checkroom_outlined;
    case 'bottom':
      return Icons.shopping_bag_outlined;
    case 'shoe':
      return Icons.hiking_outlined;
    case 'accessory':
      return Icons.watch_outlined;
    case 'outwear':
      return Icons.dry_cleaning_outlined;
    default:
      return Icons.category_outlined;
  }
}

List<String> _subtypesForType(String type) {
  return List<String>.from(
    _itemSubtypesByType[type.trim().toLowerCase()] ?? const <String>[],
  );
}

String _defaultSubtypeForType(String type) {
  final subtypes = _subtypesForType(type);
  return subtypes.isNotEmpty ? subtypes.first : '';
}

String? _normalizeItemSubtype(String? subtype) {
  final normalized = subtype?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized;
}

IconData _itemSubtypeIcon(String subtype) {
  switch (subtype.trim().toLowerCase()) {
    case 't_shirt':
    case 'tank_top':
    case 'polo':
    case 'shirt':
    case 'dress_shirt':
      return Icons.iron_outlined;
    case 'hoodie':
    case 'sweater':
      return Icons.checkroom_outlined;
    case 'shorts':
    case 'jeans':
    case 'joggers':
    case 'trousers':
      return Icons.dry_cleaning_outlined;
    case 'sneakers':
    case 'running_shoes':
    case 'boots':
    case 'loafers':
    case 'sandals':
      return Icons.hiking_outlined;
    case 'blazer':
    case 'coat':
    case 'raincoat':
    case 'puffer_jacket':
    case 'denim_jacket':
      return Icons.layers_outlined;
    case 'bag':
      return Icons.shopping_bag_outlined;
    case 'watch':
      return Icons.watch_outlined;
    case 'scarf':
      return Icons.waves_outlined;
    case 'hat':
      return Icons.face_3_outlined;
    case 'belt':
      return Icons.linear_scale_outlined;
    default:
      return Icons.category_outlined;
  }
}

IconData _styleIcon(String style) {
  switch ((_normalizeItemCategory(style) ?? style.trim().toLowerCase())) {
    case 'casual':
      return Icons.weekend_outlined;
    case 'chic':
      return Icons.business_center_outlined;
    case 'sport':
      return Icons.fitness_center_outlined;
    default:
      return Icons.style_outlined;
  }
}

String? _normalizeItemCategory(String? category) {
  final normalized = category?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized;
}

Color _itemColorValue(String color) {
  switch (color.trim().toLowerCase()) {
    case 'black':
      return const Color(0xFF1E1E1E);
    case 'white':
      return Colors.white;
    case 'beige':
      return const Color(0xFFD9C3A5);
    case 'blue':
      return const Color(0xFF4A7DDB);
    case 'red':
      return const Color(0xFFD94B5C);
    case 'green':
      return const Color(0xFF4FA36C);
    case 'pink':
      return const Color(0xFFE58AB5);
    case 'brown':
      return const Color(0xFF8B5E3C);
    case 'gray':
      return const Color(0xFF9AA3AF);
    case 'purple':
      return const Color(0xFF8A63D2);
    default:
      return const Color(0xFFCBD5E1);
  }
}

class _FilterOption<T> {
  final T? value;
  final String label;
  final IconData? icon;
  final Color? colorDot;

  const _FilterOption({
    required this.value,
    required this.label,
    this.icon,
    this.colorDot,
  });
}

class _FilterPickerResult<T> {
  final T? value;

  const _FilterPickerResult({
    required this.value,
  });
}
