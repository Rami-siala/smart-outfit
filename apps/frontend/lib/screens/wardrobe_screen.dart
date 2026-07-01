import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:frontend/screens/wardrobe_details_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _navy = Color(0xFF173B6D);
const Color _midnight = Color(0xFF0D2240);
const Color _mist = Color(0xFFF3F7FB);
const Color _slate = Color(0xFF4E6688);
const Color _sky = Color(0xFF77B6EA);
const Color _peach = Color(0xFFFFD7C2);
const Color _gold = Color(0xFFF2C66D);
const String _guestWardrobesKey = 'guest_wardrobes';
const List<String> _guestItemTypes = [
  'top',
  'bottom',
  'shoe',
  'outwear',
  'accessory',
];
const Map<String, List<String>> _guestItemSubtypesByType = {
  'top': ['t_shirt', 'polo', 'shirt', 'dress_shirt', 'hoodie', 'sweater'],
  'bottom': ['shorts', 'jeans', 'joggers', 'trousers'],
  'shoe': ['sneakers', 'running_shoes', 'boots', 'sandals'],
  'outwear': ['blazer', 'coat', 'raincoat', 'jacket'],
  'accessory': ['bag', 'watch', 'scarf', 'hat', 'belt'],
};
const List<String> _guestItemCategories = ['casual', 'chic', 'sport'];
const List<String> _guestItemColors = [
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
const List<String> _guestItemSeasons = ['summer', 'winter', 'autumn', 'spring'];

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key, this.isGuest = false});

  final bool isGuest;

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _wardrobes = const [];

  int? _selectedAiWardrobeId;
  String? _selectedAiWardrobeName;

  @override
  void initState() {
    super.initState();
    _loadSelectedAiWardrobe();
    _loadWardrobes();
  }

  Future<void> _loadSelectedAiWardrobe() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _selectedAiWardrobeId = prefs.getInt('selected_ai_wardrobe_id');
      _selectedAiWardrobeName = prefs.getString('selected_ai_wardrobe_name');
    });
  }

  Future<void> _selectWardrobeForAi(Map<String, dynamic> wardrobe) async {
    final id = _asInt(wardrobe['id']);
    final name = wardrobe['name']?.toString() ?? 'Wardrobe';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_ai_wardrobe_id', id);
    await prefs.setString('selected_ai_wardrobe_name', name);

    if (!mounted) return;

    setState(() {
      _selectedAiWardrobeId = id;
      _selectedAiWardrobeName = name;
    });

    _showSnackBar('$name selected for AI outfits');
  }

  Future<void> _loadWardrobes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final wardrobes = widget.isGuest
          ? await _loadGuestWardrobes()
          : await ApiService.getWardrobes();

      if (!mounted) return;

      setState(() {
        _wardrobes = wardrobes;
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

  Future<void> _openWardrobeForm({Map<String, dynamic>? wardrobe}) async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => WardrobeFormScreen(
          wardrobe: wardrobe,
          isGuest: widget.isGuest,
        ),
      ),
    );

    if (widget.isGuest && result is Map<String, dynamic>) {
      await _upsertGuestWardrobe(result);
      return;
    }

    if (result == true) {
      await _loadWardrobes();
    }
  }

  Future<void> _confirmDeleteWardrobe(Map<String, dynamic> wardrobe) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete wardrobe'),
            content: Text(
              'Delete "${wardrobe['name'] ?? 'this wardrobe'}"? This also removes its items.',
            ),
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

    if (!confirmed) return;

    try {
      if (widget.isGuest) {
        final id = _asInt(wardrobe['id']);
        final updated = _wardrobes.where((entry) => _asInt(entry['id']) != id).toList();

        if (_selectedAiWardrobeId == id) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('selected_ai_wardrobe_id');
          await prefs.remove('selected_ai_wardrobe_name');

          if (mounted) {
            setState(() {
              _selectedAiWardrobeId = null;
              _selectedAiWardrobeName = null;
            });
          }
        }

        await _saveGuestWardrobes(updated);
        if (!mounted) return;

        setState(() {
          _wardrobes = updated;
        });
        _showSnackBar('Wardrobe deleted');
        return;
      }

      final id = _asInt(wardrobe['id']);
      await ApiService.deleteWardrobe(id);

      if (_selectedAiWardrobeId == id) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('selected_ai_wardrobe_id');
        await prefs.remove('selected_ai_wardrobe_name');

        if (mounted) {
          setState(() {
            _selectedAiWardrobeId = null;
            _selectedAiWardrobeName = null;
          });
        }
      }

      await _loadWardrobes();
      _showSnackBar('Wardrobe deleted');
    } catch (e) {
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openWardrobeDetails(Map<String, dynamic> wardrobe) async {
    if (widget.isGuest) {
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => WardrobeDetailsScreen(
            wardrobeId: _asInt(wardrobe['id']),
            wardrobeName: wardrobe['name']?.toString() ?? 'Wardrobe',
            isGuest: true,
            guestWardrobe: wardrobe,
          ),
        ),
      );
      if (result != null) {
        await _upsertGuestWardrobe(result);
      }
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WardrobeDetailsScreen(
          wardrobeId: _asInt(wardrobe['id']),
          wardrobeName: wardrobe['name']?.toString() ?? 'Wardrobe',
        ),
      ),
    );

    if (!mounted) return;
    await _loadWardrobes();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<List<Map<String, dynamic>>> _loadGuestWardrobes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_guestWardrobesKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveGuestWardrobes(List<Map<String, dynamic>> wardrobes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_guestWardrobesKey, jsonEncode(wardrobes));
  }

  Future<void> _upsertGuestWardrobe(Map<String, dynamic> wardrobe) async {
    final updated = _wardrobes.map(Map<String, dynamic>.from).toList();
    final id = _asInt(wardrobe['id']);
    final index = updated.indexWhere((entry) => _asInt(entry['id']) == id);

    if (index >= 0) {
      updated[index] = wardrobe;
    } else {
      updated.insert(0, wardrobe);
    }

    await _saveGuestWardrobes(updated);
    if (!mounted) return;

    setState(() {
      _wardrobes = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showFloatingCreateButton = !_isLoading && _wardrobes.isNotEmpty;

    return Scaffold(
      backgroundColor: _mist,
      floatingActionButton: showFloatingCreateButton
          ? FloatingActionButton.extended(
              onPressed: () => _openWardrobeForm(),
              backgroundColor: _midnight,
              foregroundColor: Colors.white,
              elevation: 2,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New wardrobe',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadWardrobes,
        color: _navy,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final isEmpty = _wardrobes.isEmpty;
    final bottomPadding = isEmpty ? 28.0 : 120.0;
    final topInset = MediaQuery.of(context).padding.top;
    final topPadding = topInset + 16;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _navy),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, topPadding, 20, bottomPadding),
        children: [
          _buildHeroHeader(),
          const SizedBox(height: 18),
          _buildErrorCard(),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, bottomPadding),
      children: [
        _buildHeroHeader(),
        const SizedBox(height: 18),
        _buildOverviewRow(),
        SizedBox(height: isEmpty ? 18 : 22),
        _buildSectionTitle(),
        SizedBox(height: isEmpty ? 12 : 14),
        if (_wardrobes.isEmpty) _buildEmptyState() else ..._buildWardrobeCards(),
      ],
    );
  }

  Widget _buildHeroHeader() {
    final styledCount = _wardrobes.length;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_midnight, _navy, Color(0xFF3567A4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _midnight.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
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
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(38, 38),
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: _loadWardrobes,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(38, 38),
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Smart Wardrobe',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                styledCount == 0
                    ? 'Build a wardrobe space that feels curated, colorful, and ready for every outfit idea.'
                    : 'You have $styledCount wardrobe${styledCount == 1 ? '' : 's'} ready for styling, planning, and outfit ideas.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
              if (_selectedAiWardrobeName != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'AI wardrobe: $_selectedAiWardrobeName',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _heroBadge(
                    icon: Icons.checkroom_rounded,
                    label: '$styledCount closets',
                  ),
                  _heroBadge(
                    icon: Icons.tips_and_updates_outlined,
                    label: styledCount > 2 ? 'Well organized' : 'Ready to grow',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewRow() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_peach, _gold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.dashboard_customize_rounded,
              color: _midnight,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wardrobe overview',
                  style: TextStyle(
                    color: _slate,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_wardrobes.length} wardrobe${_wardrobes.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedAiWardrobeName == null
                      ? 'Select one wardrobe to use for AI outfit generation.'
                      : 'AI will use $_selectedAiWardrobeName for outfit generation.',
                  style: const TextStyle(
                    color: _slate,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _overviewPill(
                      icon: Icons.auto_awesome_rounded,
                      label: _selectedAiWardrobeName == null
                          ? 'Select AI wardrobe'
                          : 'AI wardrobe selected',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your wardrobes',
                style: TextStyle(
                  color: _navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Open any collection or select one for AI generation.',
                style: TextStyle(
                  color: _slate,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${_wardrobes.length} total',
            style: const TextStyle(
              color: _navy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
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
            _error!,
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
            onPressed: _loadWardrobes,
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_peach, _gold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.checkroom_rounded,
              color: _midnight,
              size: 42,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No wardrobes yet',
            style: TextStyle(
              color: _navy,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Start with one beautiful collection for your everyday pieces, event looks, or seasonal favorites.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _slate,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: const [
              _SuggestionChip(label: 'Casual essentials'),
              _SuggestionChip(label: 'Weekend looks'),
              _SuggestionChip(label: 'Office edits'),
            ],
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _openWardrobeForm(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _midnight,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create first wardrobe'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWardrobeCards() {
    return List<Widget>.generate(_wardrobes.length, (index) {
      final wardrobe = _wardrobes[index];
      final wardrobeId = _asInt(wardrobe['id']);
      final isSelectedForAi = _selectedAiWardrobeId == wardrobeId;
      final name = wardrobe['name']?.toString() ?? 'Unnamed wardrobe';
      final description = wardrobe['description']?.toString() ?? '';
      final address = wardrobe['address']?.toString() ?? '';
      final createdAt = _formatDate(wardrobe['created_at']?.toString());
      final accent = isSelectedForAi ? _gold : _cardAccent(index);
      final badgeText = address.isNotEmpty
          ? 'Stored in $address'
          : description.isNotEmpty
              ? 'Styled collection'
              : 'Ready for items';

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () => _openWardrobeDetails(wardrobe),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelectedForAi
                      ? _gold.withValues(alpha: 0.95)
                      : accent.withValues(alpha: 0.10),
                  width: isSelectedForAi ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isSelectedForAi ? _gold : _navy)
                        .withValues(alpha: isSelectedForAi ? 0.16 : 0.06),
                    blurRadius: isSelectedForAi ? 28 : 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent.withValues(alpha: 0.92),
                              accent.withValues(alpha: 0.55),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Icon(
                          isSelectedForAi
                              ? Icons.auto_awesome_rounded
                              : Icons.checkroom_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: _navy,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _headerAiButton(
                            selected: isSelectedForAi,
                            onTap: () => _selectWardrobeForAi(wardrobe),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _headerIconButton(
                                icon: Icons.edit_outlined,
                                tooltip: 'Edit wardrobe',
                                onTap: () => _openWardrobeForm(wardrobe: wardrobe),
                              ),
                              const SizedBox(width: 6),
                              _headerIconButton(
                                icon: Icons.delete_outline_rounded,
                                tooltip: 'Delete wardrobe',
                                color: const Color(0xFFC6546A),
                                onTap: () => _confirmDeleteWardrobe(wardrobe),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      description,
                      style: const TextStyle(
                        color: _slate,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (address.isNotEmpty)
                        _infoChip(
                          icon: Icons.location_on_outlined,
                          label: address,
                        ),
                      if (createdAt != null)
                        _infoChip(
                          icon: Icons.event_outlined,
                          label: createdAt,
                        ),
                      _infoChip(
                        icon: Icons.arrow_outward_rounded,
                        label: widget.isGuest ? 'Open overview' : 'Open details',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _heroBadge({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _mist,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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

  Widget _headerAiButton({
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFFFF7E6) : _mist,
      borderRadius: BorderRadius.circular(selected ? 18 : 999),
      child: InkWell(
        borderRadius: BorderRadius.circular(selected ? 18 : 999),
        onTap: onTap,
        child: Container(
          padding: selected
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(selected ? 18 : 999),
            border: Border.all(
              color: selected
                  ? _gold.withValues(alpha: 0.95)
                  : _navy.withValues(alpha: 0.08),
            ),
          ),
          child: selected
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.checkroom,
                      size: 16,
                      color: _gold,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Styled',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ],
                )
              : const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.checkroom_outlined,
                    size: 18,
                    color: _navy,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = _navy,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _mist,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: color.withValues(alpha: 0.10),
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _mist,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _navy),
          const SizedBox(width: 6),
          Text(
            label,
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

  Color _cardAccent(int index) {
    const colors = [
      Color(0xFF2B5F9E),
      Color(0xFFCC6B49),
      Color(0xFF2F7A63),
      Color(0xFF7C5CE0),
      Color(0xFFB8577C),
    ];

    return colors[index % colors.length];
  }
}

class WardrobeFormScreen extends StatefulWidget {
  const WardrobeFormScreen({super.key, this.wardrobe, this.isGuest = false});

  final Map<String, dynamic>? wardrobe;
  final bool isGuest;

  @override
  State<WardrobeFormScreen> createState() => _WardrobeFormScreenState();
}

class _WardrobeFormScreenState extends State<WardrobeFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  bool _isSaving = false;

  bool get _isEditing => widget.wardrobe != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.wardrobe?['name']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.wardrobe?['description']?.toString() ?? '',
    );
    _addressController = TextEditingController(
      text: widget.wardrobe?['address']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveWardrobe() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Wardrobe name is required');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.isGuest) {
        final existing = widget.wardrobe == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(widget.wardrobe!);
        final now = DateTime.now().toIso8601String();
        final localWardrobe = <String, dynamic>{
          'id': existing['id'] ?? DateTime.now().millisecondsSinceEpoch,
          'name': name,
          'description': _optionalText(_descriptionController.text) ?? '',
          'address': _optionalText(_addressController.text) ?? '',
          'created_at': existing['created_at'] ?? now,
          'updated_at': now,
          'items': existing['items'] ?? <Map<String, dynamic>>[],
        };

        if (!mounted) return;
        Navigator.of(context).pop(localWardrobe);
        return;
      }

      if (_isEditing) {
        await ApiService.updateWardrobe(
          wardrobeId: _asInt(widget.wardrobe!['id']),
          name: name,
          description: _optionalText(_descriptionController.text),
          address: _optionalText(_addressController.text),
        );
      } else {
        await ApiService.createWardrobe(
          name: name,
          description: _optionalText(_descriptionController.text),
          address: _optionalText(_addressController.text),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Edit wardrobe' : 'New wardrobe';
    final subtitle = _isEditing
        ? 'Update the name, description, and address for this wardrobe.'
        : 'Create a smart wardrobe space with a name, description, and address.';

    return Scaffold(
      backgroundColor: _mist,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _midnight,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_midnight, _navy, Color(0xFF3567A4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: _midnight.withValues(alpha: 0.18),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.checkroom_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: _navy.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wardrobe details',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Fill in the basic information for this wardrobe.',
                      style: TextStyle(
                        color: _slate,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildFormField(
                      controller: _nameController,
                      label: 'Name',
                      hint: 'Main wardrobe',
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    _buildFormField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Everyday pieces and essentials',
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: 14),
                    _buildFormField(
                      controller: _addressController,
                      label: 'Address',
                      hint: 'Bedroom closet',
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveWardrobe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _midnight,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _isSaving
                              ? 'Saving...'
                              : _isEditing
                                  ? 'Save wardrobe'
                                  : 'Create wardrobe',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputAction? textInputAction,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: _mist,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
    );
  }
}

class _GuestWardrobeDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> wardrobe;

  const _GuestWardrobeDetailsScreen({
    required this.wardrobe,
  });

  @override
  State<_GuestWardrobeDetailsScreen> createState() =>
      _GuestWardrobeDetailsScreenState();
}

class _GuestWardrobeDetailsScreenState extends State<_GuestWardrobeDetailsScreen> {
  late Map<String, dynamic> _wardrobe;
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _wardrobe = Map<String, dynamic>.from(widget.wardrobe);
    _items = ((widget.wardrobe['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  void _close() {
    _wardrobe['items'] = _items;
    _wardrobe['updated_at'] = DateTime.now().toIso8601String();
    Navigator.of(context).pop(_wardrobe);
  }

  Future<void> _openItemForm({Map<String, dynamic>? item}) async {
    final nameController = TextEditingController(
      text: item?['name']?.toString() ?? '',
    );
    final materialController = TextEditingController(
      text: item?['material']?.toString() ?? '',
    );
    var selectedType = item?['type']?.toString() ?? _guestItemTypes.first;
    var selectedSubtype =
        item?['item_subtype']?.toString() ??
        (_guestItemSubtypesByType[selectedType]?.first ?? '');
    var selectedCategory =
        item?['category']?.toString() ?? _guestItemCategories.first;
    var selectedColor = item?['color']?.toString() ?? _guestItemColors.first;
    var selectedSeason = item?['season']?.toString() ?? _guestItemSeasons.first;
    var rainReady = item?['precipitation_resistant'] == true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final subtypeOptions =
                _guestItemSubtypesByType[selectedType] ?? const <String>[];

            if (!subtypeOptions.contains(selectedSubtype) &&
                subtypeOptions.isNotEmpty) {
              selectedSubtype = subtypeOptions.first;
            }

            return AlertDialog(
              title: Text(item == null ? 'Add guest item' : 'Edit guest item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Item name',
                        hintText: 'Black hoodie',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: _guestItemTypes
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_capitalizeLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedType = value;
                          selectedSubtype =
                              _guestItemSubtypesByType[value]?.first ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSubtype.isEmpty ? null : selectedSubtype,
                      decoration: const InputDecoration(labelText: 'Subtype'),
                      items: subtypeOptions
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_capitalizeLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedSubtype = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Style'),
                      items: _guestItemCategories
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_capitalizeLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedColor,
                      decoration: const InputDecoration(labelText: 'Color'),
                      items: _guestItemColors
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_capitalizeLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedColor = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSeason,
                      decoration: const InputDecoration(labelText: 'Season'),
                      items: _guestItemSeasons
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_capitalizeLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedSeason = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: materialController,
                      decoration: const InputDecoration(
                        labelText: 'Material',
                        hintText: 'Cotton',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Rain ready'),
                      value: rainReady,
                      onChanged: (value) {
                        setDialogState(() {
                          rainReady = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Item name is required')),
                      );
                      return;
                    }

                    final now = DateTime.now().toIso8601String();
                    final updatedItem = <String, dynamic>{
                      'id': item?['id'] ?? DateTime.now().millisecondsSinceEpoch,
                      'name': name,
                      'type': selectedType,
                      'item_subtype': selectedSubtype,
                      'category': selectedCategory,
                      'color': selectedColor,
                      'season': selectedSeason,
                      'material': materialController.text.trim(),
                      'precipitation_resistant': rainReady,
                      'created_at': item?['created_at'] ?? now,
                      'updated_at': now,
                    };

                    setState(() {
                      final index = _items.indexWhere(
                        (entry) => _asInt(entry['id']) == _asInt(updatedItem['id']),
                      );
                      if (index >= 0) {
                        _items[index] = updatedItem;
                      } else {
                        _items.insert(0, updatedItem);
                      }
                    });

                    Navigator.of(context).pop(true);
                  },
                  child: Text(item == null ? 'Add item' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      setState(() {});
    }
  }

  void _deleteItem(Map<String, dynamic> item) {
    setState(() {
      _items.removeWhere((entry) => _asInt(entry['id']) == _asInt(item['id']));
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = _wardrobe['name']?.toString() ?? 'Wardrobe';
    final description = _wardrobe['description']?.toString() ?? '';
    final address = _wardrobe['address']?.toString() ?? '';

    return Scaffold(
      backgroundColor: _mist,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openItemForm(),
        backgroundColor: _midnight,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add item',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Row(
              children: [
                _CircleActionButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: _close,
                ),
                const Spacer(),
                _CircleActionButton(
                  icon: Icons.edit_rounded,
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_midnight, _navy, Color(0xFF3567A4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: _midnight.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
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
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Guest wardrobe details',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (description.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (address.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      address,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _SuggestionChip(label: '${_items.length} items'),
                      const _SuggestionChip(label: 'Temporary guest storage'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Wardrobe items',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${_items.length} total',
                  style: const TextStyle(
                    color: _slate,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Add pieces to this guest wardrobe. They stay temporary and disappear when you log out.',
              style: TextStyle(
                color: _slate.withValues(alpha: 0.86),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _mist,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.checkroom_rounded,
                        color: _navy,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No items yet',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap "Add item" to build this guest wardrobe.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _slate,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._items.map(_buildGuestItemCard),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestItemCard(Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? '';
    final subtype = item['item_subtype']?.toString() ?? '';
    final color = item['color']?.toString() ?? '';
    final season = item['season']?.toString() ?? '';
    final category = item['category']?.toString() ?? '';
    final material = item['material']?.toString() ?? '';
    final rainReady = item['precipitation_resistant'] == true;

    final tags = [
      if (subtype.isNotEmpty) _capitalizeLabel(subtype),
      if (category.isNotEmpty) _capitalizeLabel(category),
      if (color.isNotEmpty) _capitalizeLabel(color),
      if (season.isNotEmpty) _capitalizeLabel(season),
      if (material.trim().isNotEmpty) material.trim(),
      if (rainReady) 'Rain Ready',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _navy.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _mist,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    _guestItemTypeIcon(type),
                    color: _navy,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name']?.toString() ?? 'Unnamed item',
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _capitalizeLabel(type),
                        style: TextStyle(
                          color: _slate.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    _MiniActionButton(
                      icon: Icons.edit_rounded,
                      onTap: () => _openItemForm(item: item),
                    ),
                    const SizedBox(height: 8),
                    _MiniActionButton(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      onTap: () => _deleteItem(item),
                    ),
                  ],
                ),
              ],
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((tag) => _SuggestionChip(label: tag)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleActionButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: _navy),
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _MiniActionButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _mist,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color ?? _navy, size: 20),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;

  const _SuggestionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _mist,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _navy,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.parse(value.toString());
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

String _capitalizeLabel(String value) {
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

IconData _guestItemTypeIcon(String type) {
  switch (type.trim().toLowerCase()) {
    case 'top':
      return Icons.checkroom_outlined;
    case 'bottom':
      return Icons.dry_cleaning_outlined;
    case 'shoe':
      return Icons.hiking_outlined;
    case 'outwear':
    case 'outerwear':
      return Icons.layers_outlined;
    case 'accessory':
      return Icons.watch_outlined;
    default:
      return Icons.style_outlined;
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
