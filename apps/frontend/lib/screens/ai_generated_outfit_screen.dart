import 'dart:math';

import 'package:flutter/material.dart';
import 'package:frontend/models/ai_outfit_history_item.dart';
import 'package:frontend/services/ai_outfit_history_service.dart';
import 'package:frontend/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _navy = Color(0xFF173B6D);
const Color _coral = Color(0xFFE85B5B);
const Color _pink = Color(0xFFD95EAE);
const Color _mist = Color(0xFFF3F7FB);
const Color _sky = Color(0xFFE4EEF9);
const Color _amber = Color(0xFFFFE8C7);

class AiGeneratedOutfitScreen extends StatefulWidget {
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
  final String precipitation;
  final String humidity;
  final String wind;
  final String timeOfDay;
  final String? birthDate;
  final double? height;
  final double? weight;
  final bool usedSelectedWardrobeItems;
  final List<String> wardrobeItemsUsed;
  final List<Map<String, dynamic>> wardrobeItemsUsedDetails;
  final String? wardrobeWarning;

  const AiGeneratedOutfitScreen({
    super.key,
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
    required this.precipitation,
    required this.humidity,
    required this.wind,
    required this.timeOfDay,
    this.birthDate,
    this.height,
    this.weight,
    this.usedSelectedWardrobeItems = false,
    this.wardrobeItemsUsed = const [],
    this.wardrobeItemsUsedDetails = const [],
    this.wardrobeWarning,
  });

  @override
  State<AiGeneratedOutfitScreen> createState() =>
      _AiGeneratedOutfitScreenState();
}

class _AiGeneratedOutfitScreenState extends State<AiGeneratedOutfitScreen> {
  bool _isSaving = false;
  bool _isRegenerating = false;
  late String _currentImageUrl;
  late final TextEditingController _promptController;
  final Random _random = Random();
  late bool _usedSelectedWardrobeItems;
  late List<String> _wardrobeItemsUsed;
  late List<Map<String, dynamic>> _wardrobeItemsUsedDetails;
  String? _wardrobeWarning;

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.imageUrl;
    _promptController = TextEditingController();
    _usedSelectedWardrobeItems = widget.usedSelectedWardrobeItems;
    _wardrobeItemsUsed = List<String>.from(widget.wardrobeItemsUsed);
    _wardrobeItemsUsedDetails = widget.wardrobeItemsUsedDetails
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    _wardrobeWarning = widget.wardrobeWarning;
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _returnCurrentImage() {
    if (!mounted) return;
    Navigator.of(context).pop(_currentImageUrl);
  }

  Future<void> _saveCurrentOutfitToHistory() async {
    final item = AiOutfitHistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      imageUrl: _currentImageUrl,
      city: widget.city,
      country: widget.country,
      temperature: widget.temperature,
      weather: widget.weather,
      style: widget.style,
      color: widget.color,
      gender: widget.gender,
      bodyShape: widget.bodyShape,
      skinTone: widget.skinTone,
      usedSelectedWardrobeItems: _usedSelectedWardrobeItems,
      wardrobeItemsUsedDetails: _wardrobeItemsUsedDetails
          .map(AiWardrobeItemDetail.fromJson)
          .toList(growable: false),
      savedAt: DateTime.now().toIso8601String(),
    );

    await AiOutfitHistoryService.addItem(item);
  }

  Future<void> _saveAndReturnCurrentImage() async {
    if (_isSaving || _isRegenerating) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _saveCurrentOutfitToHistory();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Outfit saved to history.')));

      _returnCurrentImage();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save outfit: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _likeOutfit() async {
    await _saveAndReturnCurrentImage();
  }

  Future<void> _regenerateOutfit() async {
    await _regenerateOutfitWithPrompt();
  }

  Future<void> _dislikeOutfit() async {
    if (_isSaving || _isRegenerating) return;

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _regenerateOutfitWithPrompt({String? fallbackPrompt}) async {
    if (_isSaving || _isRegenerating) return;

    final prompt = _promptController.text.trim();
    final extraInstructions = prompt.isNotEmpty
        ? prompt
        : fallbackPrompt ??
              'Create a fresh variation of this outfit. Variant ${1000 + _random.nextInt(9000)}.';

    setState(() {
      _isRegenerating = true;
    });

    try {
      final messenger = ScaffoldMessenger.of(context);
      final prefs = await SharedPreferences.getInstance();
      final wardrobeId = prefs.getInt('selected_ai_wardrobe_id');

      final result = await ApiService.generateOutfitImage(
        wardrobeId: wardrobeId,
        city: widget.city,
        country: widget.country,
        temperature: widget.temperature,
        weather: widget.weather,
        precipitation: widget.precipitation,
        humidity: widget.humidity,
        wind: widget.wind,
        timeOfDay: widget.timeOfDay,
        style: widget.style,
        color: widget.color,
        gender: widget.gender,
        birthDate: widget.birthDate,
        height: widget.height,
        weight: widget.weight,
        bodyShape: widget.bodyShape,
        skinTone: widget.skinTone,
        extraInstructions: extraInstructions,
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

      setState(() {
        _currentImageUrl = imageUrl;
        _usedSelectedWardrobeItems = usedSelectedWardrobeItems;
        _wardrobeItemsUsed = wardrobeItemsUsed;
        _wardrobeItemsUsedDetails = wardrobeItemsUsedDetails;
        _wardrobeWarning = warning;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            warning != null && warning.isNotEmpty
                ? warning
                : 'Outfit regenerated.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isRegenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _saveAndReturnCurrentImage();
      },
      child: Scaffold(
        backgroundColor: _mist,
        appBar: AppBar(
          backgroundColor: _mist,
          surfaceTintColor: _mist,
          elevation: 0,
          foregroundColor: _navy,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _saveAndReturnCurrentImage,
          ),
          title: const Text(
            'AI Generated Outfit',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isVeryShortScreen = constraints.maxHeight < 720;
              final outfitStyleLabel = _displayLabel(
                widget.style,
                fallback: 'AI styled',
              );
              final outfitColorLabel = _displayLabel(
                widget.color,
                fallback: 'Curated palette',
              );
              return Stack(
                children: [
                  Positioned(
                    top: -50,
                    right: -36,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _sky.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 210,
                    left: -62,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _amber.withValues(alpha: 0.30),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: 14,
                      right: 14,
                      top: 8,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.fromLTRB(
                              12,
                              12,
                              12,
                              isVeryShortScreen ? 10 : 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.white, Color(0xFFF8FBFF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: _navy.withValues(alpha: 0.08),
                                  blurRadius: 28,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(26),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.92,
                                        ),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _navy.withValues(alpha: 0.10),
                                          blurRadius: 20,
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Stack(
                                        children: [
                                          Container(
                                            width: double.infinity,
                                            color: Colors.black.withValues(
                                              alpha: 0.04,
                                            ),
                                            child: InteractiveViewer(
                                              minScale: 0.8,
                                              maxScale: 4,
                                              child: Image.network(
                                                _currentImageUrl,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 12,
                                            left: 12,
                                            child: _GlassBadge(
                                              label: 'AI-curated look',
                                              foreground: _navy,
                                            ),
                                          ),
                                          Positioned(
                                            top: 12,
                                            right: 12,
                                            child: _GlassBadge(
                                              label: widget.weather.isEmpty
                                                  ? widget.timeOfDay
                                                  : '${widget.weather} · ${widget.temperature} C',
                                              foreground: _navy,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: isVeryShortScreen ? 8 : 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _UnderImageMetaChip(
                                        icon: Icons.checkroom_rounded,
                                        label: outfitStyleLabel,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _UnderImageMetaChip(
                                        icon: Icons.palette_outlined,
                                        label: outfitColorLabel,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: _UnderImageMetaChip(
                                        icon: Icons.location_on_outlined,
                                        label:
                                            '${widget.city}, ${widget.country}',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: isVeryShortScreen ? 12 : 14,
                            vertical: isVeryShortScreen ? 10 : 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: _navy.withValues(alpha: 0.08),
                                blurRadius: 22,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            top: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((_wardrobeWarning != null ||
                                        !_usedSelectedWardrobeItems) &&
                                    !isVeryShortScreen) ...[
                                  _WardrobeSourceBanner(
                                    usedSelectedWardrobeItems:
                                        _usedSelectedWardrobeItems,
                                    warning: _wardrobeWarning,
                                    wardrobeItemsUsed: _wardrobeItemsUsed,
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Text(
                                  'Tell AI what to change',
                                  style: TextStyle(
                                    color: _navy.withValues(alpha: 0.72),
                                    fontSize: isVeryShortScreen ? 11 : 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _promptController,
                                  enabled: !_isSaving && !_isRegenerating,
                                  minLines: 1,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: _navy,
                                    fontSize: isVeryShortScreen ? 11.5 : 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText:
                                        'Example: more casual, darker color',
                                    hintStyle: TextStyle(
                                      color: _navy.withValues(alpha: 0.38),
                                      fontWeight: FontWeight.w600,
                                      fontSize: isVeryShortScreen ? 11 : 11.5,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.edit_outlined,
                                      color: _coral,
                                      size: isVeryShortScreen ? 16 : 18,
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 34,
                                    ),
                                    filled: true,
                                    fillColor: _mist,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide(
                                        color: _navy.withValues(alpha: 0.06),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide(
                                        color: _coral.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: isVeryShortScreen ? 10 : 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
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
                                          color: _pink.withValues(alpha: 0.18),
                                          blurRadius: 14,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: _isSaving || _isRegenerating
                                          ? null
                                          : _regenerateOutfit,
                                      icon: _isRegenerating
                                          ? const SizedBox(
                                              width: 15,
                                              height: 15,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.auto_awesome_rounded,
                                              size: 16,
                                            ),
                                      label: Text(
                                        _isRegenerating
                                            ? 'Regenerating...'
                                            : 'Regenerate',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        disabledBackgroundColor:
                                            Colors.transparent,
                                        foregroundColor: Colors.white,
                                        disabledForegroundColor: Colors.white70,
                                        shadowColor: Colors.transparent,
                                        padding: EdgeInsets.symmetric(
                                          vertical: isVeryShortScreen ? 9 : 10,
                                        ),
                                        minimumSize: Size(
                                          0,
                                          isVeryShortScreen ? 40 : 44,
                                        ),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        textStyle: TextStyle(
                                          fontSize: isVeryShortScreen
                                              ? 12
                                              : 12.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _isSaving || _isRegenerating
                                            ? null
                                            : _dislikeOutfit,
                                        icon: const Icon(
                                          Icons.thumb_down_alt_outlined,
                                          size: 16,
                                        ),
                                        label: Text(
                                          isVeryShortScreen
                                              ? 'Dislike'
                                              : "I don't like it",
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _navy,
                                          side: BorderSide(
                                            color: _navy.withValues(
                                              alpha: 0.18,
                                            ),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            vertical: isVeryShortScreen
                                                ? 9
                                                : 10,
                                          ),
                                          minimumSize: Size(
                                            0,
                                            isVeryShortScreen ? 40 : 44,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                          textStyle: TextStyle(
                                            fontSize: isVeryShortScreen
                                                ? 11.5
                                                : 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _isSaving || _isRegenerating
                                            ? null
                                            : _likeOutfit,
                                        icon: _isSaving
                                            ? const SizedBox(
                                                width: 15,
                                                height: 15,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.thumb_up_alt_outlined,
                                                size: 16,
                                              ),
                                        label: Text(
                                          _isSaving
                                              ? 'Saving...'
                                              : isVeryShortScreen
                                              ? 'Save'
                                              : 'Save look',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _navy,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            vertical: isVeryShortScreen
                                                ? 9
                                                : 10,
                                          ),
                                          minimumSize: Size(
                                            0,
                                            isVeryShortScreen ? 40 : 44,
                                          ),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                          textStyle: TextStyle(
                                            fontSize: isVeryShortScreen
                                                ? 11.5
                                                : 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _UnderImageMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _UnderImageMetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _mist,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _navy.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(icon, size: 14, color: _navy.withValues(alpha: 0.72)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _navy,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WardrobeSourceBanner extends StatefulWidget {
  final bool usedSelectedWardrobeItems;
  final String? warning;
  final List<String> wardrobeItemsUsed;

  const _WardrobeSourceBanner({
    required this.usedSelectedWardrobeItems,
    required this.warning,
    required this.wardrobeItemsUsed,
  });

  @override
  State<_WardrobeSourceBanner> createState() => _WardrobeSourceBannerState();
}

class _WardrobeSourceBannerState extends State<_WardrobeSourceBanner> {
  @override
  Widget build(BuildContext context) {
    final hasWarning =
        widget.warning != null && widget.warning!.trim().isNotEmpty;
    final parsedItems = widget.wardrobeItemsUsed
        .map(_ParsedWardrobeItem.fromRaw)
        .where((item) => item.hasContent)
        .toList();
    final backgroundColor = widget.usedSelectedWardrobeItems
        ? const Color(0xFFE8F7EF)
        : const Color(0xFFFFF3E8);
    final accentColor = widget.usedSelectedWardrobeItems
        ? const Color(0xFF1E8E5A)
        : const Color(0xFFB86A1B);
    final title = widget.usedSelectedWardrobeItems
        ? 'Created from selected wardrobe'
        : 'AI suggestion used';
    final message = hasWarning
        ? widget.warning!.trim()
        : widget.usedSelectedWardrobeItems
        ? 'The image was generated using matching items from your selected wardrobe.'
        : 'No matching outfit was found in your selected wardrobe.';
    final itemCountLabel = parsedItems.length == 1
        ? '1 item used'
        : '${parsedItems.length} items used';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.usedSelectedWardrobeItems
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              color: accentColor,
              size: 18,
            ),
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
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _navy.withValues(alpha: 0.76),
                    fontSize: 11.5,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (widget.usedSelectedWardrobeItems && parsedItems.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                itemCountLabel,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ParsedWardrobeItem {
  final String title;
  final String slotLabel;
  final List<String> attributes;
  final IconData icon;

  const _ParsedWardrobeItem({
    required this.title,
    required this.slotLabel,
    required this.attributes,
    required this.icon,
  });

  bool get hasContent => title.trim().isNotEmpty || attributes.isNotEmpty;

  factory _ParsedWardrobeItem.fromRaw(String raw) {
    String name = '';
    String type = '';
    String subtype = '';
    String category = '';
    String color = '';
    String material = '';
    String season = '';
    bool rainResistant = false;

    final parts = raw
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);

    for (final part in parts) {
      if (part.startsWith('type ')) {
        type = part.substring(5).trim();
      } else if (part.startsWith('subtype ')) {
        subtype = part.substring(8).trim();
      } else if (part.startsWith('style/category ')) {
        category = part.substring(15).trim();
      } else if (part.startsWith('color ')) {
        color = part.substring(6).trim();
      } else if (part.startsWith('material ')) {
        material = part.substring(9).trim();
      } else if (part.startsWith('season ')) {
        season = part.substring(7).trim();
      } else if (part == 'rain resistant') {
        rainResistant = true;
      } else if (name.isEmpty) {
        name = part;
      }
    }

    final normalizedType = _formatWardrobeText(type);
    final normalizedSubtype = _formatWardrobeText(subtype);
    final normalizedCategory = _formatWardrobeText(category);
    final normalizedColor = _formatWardrobeText(color);
    final normalizedMaterial = _formatWardrobeText(material);
    final normalizedSeason = _formatWardrobeText(season);
    final normalizedName = _formatWardrobeText(name);
    final title = normalizedName.isNotEmpty
        ? normalizedName
        : (normalizedSubtype.isNotEmpty
              ? normalizedSubtype
              : (normalizedType.isNotEmpty ? normalizedType : 'Wardrobe item'));

    return _ParsedWardrobeItem(
      title: title,
      slotLabel: normalizedSubtype.isNotEmpty
          ? '$normalizedSubtype${normalizedType.isNotEmpty ? ' • $normalizedType' : ''}'
          : normalizedType,
      attributes: [
        if (normalizedCategory.isNotEmpty) normalizedCategory,
        if (normalizedColor.isNotEmpty) normalizedColor,
        if (normalizedMaterial.isNotEmpty) normalizedMaterial,
        if (normalizedSeason.isNotEmpty) normalizedSeason,
        if (rainResistant) 'Rain resistant',
      ],
      icon: _iconForWardrobeType(type),
    );
  }
}

String _formatWardrobeText(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return '';

  return normalized
      .split(RegExp(r'[\s\-_]+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _displayLabel(String value, {required String fallback}) {
  final formatted = _formatWardrobeText(value);
  return formatted.isEmpty ? fallback : formatted;
}

IconData _iconForWardrobeType(String type) {
  switch (type.trim().toLowerCase()) {
    case 'top':
      return Icons.checkroom_outlined;
    case 'bottom':
      return Icons.dry_cleaning_outlined;
    case 'shoe':
    case 'shoes':
      return Icons.hiking_outlined;
    case 'outerwear':
      return Icons.layers_outlined;
    default:
      return Icons.style_outlined;
  }
}

class _GlassBadge extends StatelessWidget {
  final String label;
  final Color foreground;

  const _GlassBadge({required this.label, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
