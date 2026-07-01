import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:frontend/models/ai_outfit_history_item.dart';
import 'package:frontend/services/ai_outfit_history_service.dart';

const Color _navy = Color(0xFF173B6D);
const Color _navySoft = Color(0xFF2B568D);
const Color _mist = Color(0xFFF3F7FB);
const Color _pink = Color(0xFFD970C4);
const Color _coral = Color(0xFFE85B5B);

class AiOutfitHistoryScreen extends StatefulWidget {
  const AiOutfitHistoryScreen({super.key});

  @override
  State<AiOutfitHistoryScreen> createState() => _AiOutfitHistoryScreenState();
}

class _AiOutfitHistoryScreenState extends State<AiOutfitHistoryScreen> {
  late Future<List<AiOutfitHistoryItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = AiOutfitHistoryService.getHistory();
  }

  void _reload() {
    setState(() {
      _future = AiOutfitHistoryService.getHistory();
    });
  }

  Future<void> _handleRefresh() async {
    _reload();
    await _future;
  }

  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              'Remove outfit?',
              style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
            ),
            content: const Text(
              'Are you sure you want to remove this outfit from your AI history?',
              style: TextStyle(color: _navy, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: _navySoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _coral,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteItem(String id) async {
    final confirmed = await _confirmDelete();
    if (!confirmed) return;

    await AiOutfitHistoryService.removeItem(id);
    if (!mounted) return;

    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Outfit removed from history')),
    );
  }

  Future<void> _openImagePreview(AiOutfitHistoryItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AiOutfitHistoryPreviewScreen(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mist,
      appBar: AppBar(
        backgroundColor: _mist,
        surfaceTintColor: _mist,
        elevation: 0,
        foregroundColor: _navy,
        title: const Text(
          'AI Outfit History',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<List<AiOutfitHistoryItem>>(
        future: _future,
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _HistoryStateView(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load history',
              message: 'Please try refreshing this screen.',
              actionLabel: 'Retry',
              onPressed: _reload,
            );
          }

          if (items.isEmpty) {
            return _HistoryStateView(
              icon: Icons.history_toggle_off_rounded,
              title: 'No saved AI outfits yet',
              message:
                  'When you like an AI-generated outfit, it will appear here for quick access.',
              actionLabel: 'Refresh',
              onPressed: _reload,
            );
          }

          return RefreshIndicator(
            color: _navy,
            onRefresh: _handleRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _buildHeader(items.length),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.62,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildHistoryCard(items[index]),
                      childCount: items.length,
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

  Widget _buildHeader(int count) {
    return Container(
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
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Saved looks',
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
                  'Your AI outfit collection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Revisit outfits you liked and keep your best ideas close.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Center(
              child: Text(
                '$count',
                style: const TextStyle(
                  color: _navy,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(AiOutfitHistoryItem item) {
    final weather = _cleanValue(item.weather);
    final style = _cleanValue(item.style);
    final color = _cleanValue(item.color);
    final temperature = _cleanValue(item.temperature);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () => _openImagePreview(item),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: _navy.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _buildHistoryImage(item.imageUrl),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.06),
                          Colors.transparent,
                          _navy.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.94),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Remove outfit',
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 19,
                        color: _pink,
                      ),
                      onPressed: () => _deleteItem(item.id),
                    ),
                  ),
                ),
                if (item.usedSelectedWardrobeItems)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E8E5A).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.checkroom_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Wardrobe match',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _navy.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.city}, ${item.country}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (style != null) _buildChip(Icons.checkroom, style),
                            if (color != null)
                              _buildChip(Icons.palette_outlined, color),
                            if (weather != null)
                              _buildChip(Icons.wb_cloudy_outlined, weather),
                            if (temperature != null)
                              _buildChip(Icons.thermostat_rounded, temperature),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryImage(String imageUrl) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildImageFallback(),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: _navy,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.white,
        size: 36,
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String? _cleanValue(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }
}

class _HistoryStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  const _HistoryStateView({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _navy.withValues(alpha: 0.06),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _mist,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, color: _pink, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _navy.withValues(alpha: 0.68),
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: onPressed,
                child: Text(
                  actionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiOutfitHistoryPreviewScreen extends StatelessWidget {
  final AiOutfitHistoryItem item;

  const _AiOutfitHistoryPreviewScreen({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final hasWardrobeDetails =
        item.usedSelectedWardrobeItems && item.wardrobeItemsUsedDetails.isNotEmpty;

    return Scaffold(
      backgroundColor: _navy,
      body: Stack(
        children: [
          Positioned.fill(
            child: _PreviewBackground(imageUrl: item.imageUrl),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.12),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.18),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreviewHeader(
                    city: item.city,
                    country: item.country,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _PreviewImageCard(
                      imageUrl: item.imageUrl,
                      fillScreen: true,
                    ),
                  ),
                  if (hasWardrobeDetails) ...[
                    const SizedBox(height: 10),
                    _HistoryWardrobeDetailsPanel(
                      item: item,
                      onViewDetails: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _WardrobeItemsDetailsScreen(item: item),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  final String city;
  final String country;
  final VoidCallback onBack;

  const _PreviewHeader({
    required this.city,
    required this.country,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.14),
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$city, $country',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
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

class _PreviewImageCard extends StatelessWidget {
  final String imageUrl;
  final bool fillScreen;

  const _PreviewImageCard({
    required this.imageUrl,
    this.fillScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(fillScreen ? 0 : 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.04),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.2,
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: fillScreen ? 1 : 0.92,
                  maxScale: 4,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      fillScreen ? 0 : 4,
                      fillScreen ? 0 : 4,
                      fillScreen ? 0 : 4,
                      fillScreen ? 0 : 4,
                    ),
                    child: Image.network(
                      imageUrl,
                      fit: fillScreen ? BoxFit.cover : BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      alignment: Alignment.center,
                      errorBuilder: (context, error, stackTrace) =>
                          const _PreviewFallback(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryWardrobeDetailsPanel extends StatelessWidget {
  final AiOutfitHistoryItem item;
  final VoidCallback onViewDetails;

  const _HistoryWardrobeDetailsPanel({
    required this.item,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final details = item.wardrobeItemsUsedDetails;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onViewDetails,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF29B36A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.checkroom_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Wardrobe match',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${details.length} items used',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.90),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const Row(
                    children: [
                      Text(
                        'View details',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
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

class _WardrobeItemsDetailsScreen extends StatelessWidget {
  final AiOutfitHistoryItem item;

  const _WardrobeItemsDetailsScreen({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final details = item.wardrobeItemsUsedDetails;

    return Scaffold(
      backgroundColor: _navy,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _navySoft,
              _navy,
              const Color(0xFF102844),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: _WardrobeDetailsHeader(
                  city: item.city,
                  country: item.country,
                  itemCount: details.length,
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                  children: [
                    _WardrobeDetailsIntro(itemCount: details.length),
                    const SizedBox(height: 16),
                    ...details.asMap().entries.map(
                      (entry) => Padding(
                        padding: EdgeInsets.only(
                          bottom: entry.key == details.length - 1 ? 0 : 12,
                        ),
                        child: _HistoryWardrobeItemCard(
                          detail: entry.value,
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
}

class _WardrobeDetailsHeader extends StatelessWidget {
  final String city;
  final String country;
  final int itemCount;
  final VoidCallback onBack;

  const _WardrobeDetailsHeader({
    required this.city,
    required this.country,
    required this.itemCount,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.14),
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$city, $country',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$itemCount wardrobe item${itemCount == 1 ? '' : 's'} used',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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

class _WardrobeDetailsIntro extends StatelessWidget {
  final int itemCount;

  const _WardrobeDetailsIntro({
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF355B93),
            Color(0xFF27487F),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF29B36A),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.checkroom_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Wardrobe match',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$itemCount items used',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.90),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'All Items Used For This Look',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'A complete breakdown of the wardrobe pieces selected for this recommendation.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _DetailInfoChip(
                icon: Icons.fact_check_outlined,
                label: 'Full wardrobe breakdown',
              ),
              _DetailInfoChip(
                icon: Icons.style_outlined,
                label: 'Matched recommendation pieces',
              ),
              _DetailInfoChip(
                icon: Icons.visibility_outlined,
                label: 'No duplicate image preview',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailInfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.88), size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WardrobeStatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _WardrobeStatChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.88),
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryWardrobeItemCard extends StatelessWidget {
  final AiWardrobeItemDetail detail;

  const _HistoryWardrobeItemCard({
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final title = _formatWardrobeText(
      detail.name.isNotEmpty
          ? detail.name
          : (detail.itemSubtype.isNotEmpty ? detail.itemSubtype : detail.type),
    );
    final slotLabel = [
      _formatWardrobeText(detail.itemSubtype),
      _formatWardrobeText(detail.type),
    ].where((value) => value.isNotEmpty).join(' / ');
    final attributes = [
      _formatWardrobeText(detail.category),
      _formatWardrobeText(detail.color),
      _formatWardrobeText(detail.material),
      _formatWardrobeText(detail.season),
      if (detail.precipitationResistant) 'Rain Resistant',
    ].where((value) => value.isNotEmpty).toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  _iconForWardrobeType(detail.type),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Wardrobe item' : title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (slotLabel.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBFD1EE).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          slotLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.90),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (attributes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: attributes
                  .map(
                    (attribute) => _WardrobeStatChip(
                      icon: _chipIconForAttribute(attribute),
                      label: attribute,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (detail.visualDescription.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                detail.visualDescription.trim(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontSize: 10.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

IconData _chipIconForAttribute(String value) {
  final normalized = value.trim().toLowerCase();

  switch (normalized) {
    case 'summer':
    case 'spring':
    case 'winter':
    case 'autumn':
    case 'fall':
      return Icons.wb_sunny_outlined;
    case 'black':
    case 'white':
    case 'blue':
    case 'red':
    case 'green':
    case 'brown':
    case 'gray':
    case 'grey':
      return Icons.palette_outlined;
    case 'rain resistant':
      return Icons.umbrella_outlined;
    default:
      return Icons.sell_outlined;
  }
}

class _PreviewBackground extends StatelessWidget {
  final String imageUrl;

  const _PreviewBackground({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const _PreviewFallback(),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            color: Colors.black.withValues(alpha: 0.18),
          ),
        ),
      ],
    );
  }
}

class _PreviewFallback extends StatelessWidget {
  const _PreviewFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.white,
        size: 48,
      ),
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

IconData _iconForWardrobeType(String type) {
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
