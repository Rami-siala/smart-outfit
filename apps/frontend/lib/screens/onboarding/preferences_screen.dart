import 'package:flutter/material.dart';
import 'package:frontend/app/app_theme.dart';
import 'package:frontend/models/outfit_recommendation_data.dart';
import 'package:frontend/screens/outfit_recommendation_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/outfit_recommendation_service.dart';
import 'package:frontend/screens/weather/location_choice_screen.dart';

class PreferencesScreen extends StatefulWidget {
  final String selectedGender;
  final bool isGuest;
  final Map<String, dynamic>? guestWeather;
  final bool confirmLogoutOnExit;

  const PreferencesScreen({
    super.key,
    required this.selectedGender,
    this.isGuest = false,
    this.guestWeather,
    this.confirmLogoutOnExit = false,
  });

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _didReloadAfterOpen = false;

  final List<String> _styleOptions = ['sport', 'casual', 'chic'];

  final List<_ColorOption> _quickColors = const [
    _ColorOption('black', Color(0xFF101114)),
    _ColorOption('white', Color(0xFFFFFFFF)),
    _ColorOption('beige', Color(0xFFF2EBCF)),
    _ColorOption('blue', Color(0xFF4D63D8)),
    _ColorOption('red', Color(0xFFE74A43)),
    _ColorOption('green', Color(0xFF43A757)),
    _ColorOption('pink', Color(0xFFD9236E)),
    _ColorOption('brown', Color(0xFF8A6353)),
    _ColorOption('gray', Color(0xFFA8A8AD)),
    _ColorOption('purple', Color(0xFF8F32BC)),
  ];

  final List<String> _selectedColors = [];
  final Set<String> _selectedStyles = {};

  @override
  void initState() {
    super.initState();
    if (widget.isGuest) {
      _isLoading = false;
      return;
    }
    _loadPreferences();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.isGuest) return;

    if (_didReloadAfterOpen) return;
    _didReloadAfterOpen = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadPreferences(showLoader: false);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadPreferences({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final data = await ApiService.getMyPreferences();

      if (!mounted) return;

      setState(() {
        _selectedColors.clear();
        _selectedStyles.clear();

        if (data != null) {
          final dynamic colorsRaw = data['favorite_colors'];
          final dynamic stylesRaw = data['favorite_styles'];

          if (colorsRaw is List) {
            _selectedColors.addAll(
              colorsRaw
                  .map((e) => e.toString().trim().toLowerCase())
                  .where((e) => e.isNotEmpty),
            );
          }

          if (stylesRaw is List) {
            _selectedStyles.addAll(
              stylesRaw
                  .map((e) => e.toString().trim().toLowerCase())
                  .where((e) => _styleOptions.contains(e)),
            );
          }
        }

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('LOAD PREFERENCES ERROR: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    Color backgroundColor = Colors.redAccent,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  void _toggleQuickColor(String colorName) {
    setState(() {
      if (_selectedColors.contains(colorName)) {
        _selectedColors.remove(colorName);
      } else {
        _selectedColors
          ..clear()
          ..add(colorName);
      }
    });
  }

  void _toggleStyle(String style) {
    setState(() {
      if (_selectedStyles.contains(style)) {
        _selectedStyles.remove(style);
      } else {
        _selectedStyles
          ..clear()
          ..add(style);
      }
    });
  }

  Future<void> _handleSave() async {
    if (_selectedColors.isEmpty || _selectedStyles.isEmpty) {
      _showMessage('Please choose one color and one style');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.isGuest) {
        final weather = widget.guestWeather ?? <String, dynamic>{};
        final recommendation =
            await OutfitRecommendationService.buildRecommendation(
              selectedGender: widget.selectedGender,
              selectedColor: _selectedColors.first,
              selectedStyle: _selectedStyles.first,
              weather: weather,
            );

        if (!mounted) return;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OutfitRecommendationScreen(
              isGuest: true,
              confirmLogoutOnExit: widget.confirmLogoutOnExit,
              data: OutfitRecommendationData.fromRecommendationMap(
                recommendation,
                gender: widget.selectedGender,
                color: _selectedColors.first,
                style: _selectedStyles.first,
                weather: (weather['condition'] ?? weather['weather_category'])
                    ?.toString(),
              ),
            ),
          ),
        );
        return;
      }

      await ApiService.updateMyPreferences(
        favoriteColors: _selectedColors,
        favoriteStyles: _selectedStyles.toList(),
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LocationChoiceScreen(
            selectedGender: widget.selectedGender,
            selectedColor: _selectedColors.first,
            selectedStyle: _selectedStyles.first,
            confirmLogoutOnExit: true,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  IconData _styleIcon(String style) {
    switch (style) {
      case 'sport':
        return Icons.sports_basketball_outlined;
      case 'casual':
        return Icons.weekend_outlined;
      case 'chic':
        return Icons.auto_awesome_outlined;
      default:
        return Icons.checkroom_outlined;
    }
  }

  String _styleSubtitle(String style) {
    switch (style) {
      case 'sport':
        return 'Active and fresh';
      case 'casual':
        return 'Relaxed and everyday';
      case 'chic':
        return 'Refined and bold';
      default:
        return 'Personal style';
    }
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isLoading || _isSaving;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const _PreferencesBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight <= 940;
                final tight = constraints.maxHeight <= 900;
                final topPadding = tight ? 8.0 : (compact ? 10.0 : 14.0);
                final bottomPadding =
                    (tight ? 10.0 : (compact ? 14.0 : 24.0)) + bottomInset;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        18,
                        topPadding,
                        18,
                        bottomPadding,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              constraints.maxHeight -
                              topPadding -
                              bottomPadding,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PreferencesTopBar(
                              isBusy: isBusy,
                              onBack: () => Navigator.of(context).pop(),
                            ),
                            SizedBox(height: tight ? 8 : (compact ? 12 : 26)),
                            _PreferencesHeroPanel(
                              compact: compact,
                              tight: tight,
                            ),
                            SizedBox(height: tight ? 8 : (compact ? 10 : 18)),
                            _PreferencesCard(
                              quickColors: _quickColors,
                              selectedColors: _selectedColors,
                              selectedStyles: _selectedStyles,
                              styleOptions: _styleOptions,
                              compact: compact,
                              tight: tight,
                              onToggleQuickColor: _toggleQuickColor,
                              onToggleStyle: _toggleStyle,
                              styleIcon: _styleIcon,
                              styleSubtitle: _styleSubtitle,
                              capitalize: _capitalize,
                            ),
                            SizedBox(height: tight ? 8 : (compact ? 10 : 18)),
                            _PreferencesBottomActions(
                              isBusy: isBusy,
                              isSaving: _isSaving,
                              compact: compact,
                              onBack: () => Navigator.of(context).pop(),
                              onSave: _handleSave,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.16),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreferencesTopBar extends StatelessWidget {
  final bool isBusy;
  final VoidCallback onBack;

  const _PreferencesTopBar({required this.isBusy, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: IconButton(
            onPressed: isBusy ? null : onBack,
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_border_rounded,
                size: 16,
                color: Colors.white,
              ),
              SizedBox(width: 8),
              Text(
                'Style preferences',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreferencesHeroPanel extends StatelessWidget {
  final bool compact;
  final bool tight;

  const _PreferencesHeroPanel({required this.compact, required this.tight});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        tight ? 16 : (compact ? 18 : 22),
        tight ? 14 : (compact ? 16 : 22),
        tight ? 16 : (compact ? 18 : 22),
        tight ? 14 : (compact ? 16 : 20),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 26,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreferencesBadge(compact: compact, tight: tight),
          SizedBox(height: tight ? 8 : (compact ? 10 : 18)),
          const Text(
            'Question 5 of 5',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: tight ? 4 : (compact ? 6 : 10)),
          Text(
            'Tell us about\nyour preferences',
            style: TextStyle(
              color: Colors.white,
              fontSize: tight ? 24 : (compact ? 28 : 34),
              height: 1.02,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!tight) ...[
            SizedBox(height: compact ? 6 : 10),
            Text(
              'Choose the color and style direction that best matches the looks you want to receive.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: compact ? 13 : 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          SizedBox(height: tight ? 10 : (compact ? 12 : 18)),
          const _PreferencesProgressPills(),
        ],
      ),
    );
  }
}

class _PreferencesCard extends StatelessWidget {
  final List<_ColorOption> quickColors;
  final List<String> selectedColors;
  final Set<String> selectedStyles;
  final List<String> styleOptions;
  final ValueChanged<String> onToggleQuickColor;
  final ValueChanged<String> onToggleStyle;
  final IconData Function(String style) styleIcon;
  final String Function(String style) styleSubtitle;
  final String Function(String value) capitalize;
  final bool compact;
  final bool tight;

  const _PreferencesCard({
    required this.quickColors,
    required this.selectedColors,
    required this.selectedStyles,
    required this.styleOptions,
    required this.compact,
    required this.tight,
    required this.onToggleQuickColor,
    required this.onToggleStyle,
    required this.styleIcon,
    required this.styleSubtitle,
    required this.capitalize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        tight ? 16 : (compact ? 18 : 20),
        tight ? 16 : (compact ? 18 : 22),
        tight ? 16 : (compact ? 18 : 20),
        tight ? 14 : (compact ? 16 : 20),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.mist,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.palette_outlined, size: 16, color: AppTheme.pink),
                SizedBox(width: 8),
                Text(
                  'Style identity',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: tight ? 10 : (compact ? 12 : 18)),
          Text(
            'Choose one favorite color',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: tight ? 20 : (compact ? 22 : 24),
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!tight) ...[
            const SizedBox(height: 6),
            Text(
              'Pick the color you want to see most in your recommendations.',
              style: TextStyle(
                color: AppTheme.navy.withValues(alpha: 0.62),
                fontSize: compact ? 13 : 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          SizedBox(height: tight ? 10 : (compact ? 12 : 18)),
          Wrap(
            spacing: tight ? 8 : 12,
            runSpacing: tight ? 8 : 12,
            children: quickColors.map((colorOption) {
              final isSelected = selectedColors.contains(colorOption.name);

              return _ColorTile(
                option: colorOption,
                isSelected: isSelected,
                compact: compact,
                tight: tight,
                onTap: () => onToggleQuickColor(colorOption.name),
              );
            }).toList(),
          ),
          if (!tight && selectedColors.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedColors.map((color) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.mist,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.coral,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        capitalize(color),
                        style: const TextStyle(
                          color: AppTheme.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          SizedBox(height: tight ? 14 : (compact ? 18 : 28)),
          Text(
            'Choose one favorite style',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: tight ? 20 : (compact ? 22 : 24),
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!tight) ...[
            const SizedBox(height: 6),
            Text(
              'Select the mood that should guide your outfit suggestions.',
              style: TextStyle(
                color: AppTheme.navy.withValues(alpha: 0.62),
                fontSize: compact ? 13 : 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          SizedBox(height: tight ? 10 : (compact ? 12 : 18)),
          Column(
            children: styleOptions.map((style) {
              final isSelected = selectedStyles.contains(style);

              return Padding(
                padding: EdgeInsets.only(bottom: tight ? 8 : 12),
                child: _StyleTile(
                  label: capitalize(style),
                  subtitle: styleSubtitle(style),
                  icon: styleIcon(style),
                  isSelected: isSelected,
                  compact: compact,
                  tight: tight,
                  onTap: () => onToggleStyle(style),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ColorTile extends StatelessWidget {
  final _ColorOption option;
  final bool isSelected;
  final bool compact;
  final bool tight;
  final VoidCallback onTap;

  const _ColorTile({
    required this.option,
    required this.isSelected,
    required this.compact,
    required this.tight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final needsBorder = option.name == 'white' || option.name == 'beige';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: tight ? 60 : (compact ? 72 : 92),
          padding: EdgeInsets.fromLTRB(
            tight ? 6 : 10,
            tight ? 8 : 12,
            tight ? 6 : 10,
            tight ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? option.color.withValues(alpha: 0.14)
                : const Color(0xFFF7F9FD),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected ? AppTheme.pink : const Color(0xFFE7ECF4),
              width: isSelected ? 1.6 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.pink.withValues(alpha: 0.14),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: tight ? 26 : 34,
                    height: tight ? 26 : 34,
                    decoration: BoxDecoration(
                      color: option.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: needsBorder
                            ? const Color(0xFFDDE4EE)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: tight ? 15 : 18,
                    ),
                ],
              ),
              SizedBox(height: tight ? 5 : 10),
              Text(
                option.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.navy,
                  fontSize: tight ? 11 : 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final bool compact;
  final bool tight;
  final VoidCallback onTap;

  const _StyleTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.compact,
    required this.tight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.fromLTRB(
            tight ? 10 : 16,
            tight ? 10 : 16,
            tight ? 10 : 16,
            tight ? 10 : 16,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.pink.withValues(alpha: 0.10)
                : const Color(0xFFF7F9FD),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? AppTheme.pink : const Color(0xFFE7ECF4),
              width: isSelected ? 1.6 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.pink.withValues(alpha: 0.14),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: tight ? 34 : 46,
                height: tight ? 34 : 46,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.pink : Colors.white,
                  borderRadius: BorderRadius.circular(tight ? 12 : 16),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : AppTheme.pink,
                  size: tight ? 19 : 24,
                ),
              ),
              SizedBox(width: tight ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: AppTheme.navy,
                        fontSize: tight ? 15 : 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!tight) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.navy.withValues(alpha: 0.56),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: isSelected ? 1 : 0,
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.coral,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferencesBottomActions extends StatelessWidget {
  final bool isBusy;
  final bool isSaving;
  final bool compact;
  final VoidCallback onBack;
  final VoidCallback onSave;

  const _PreferencesBottomActions({
    required this.isBusy,
    required this.isSaving,
    required this.compact,
    required this.onBack,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: compact ? 48 : 56,
            child: OutlinedButton(
              onPressed: isBusy ? null : onBack,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
              ),
              child: const Text(
                'Back',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: compact ? 48 : 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Color(0xFFFFF3F7)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: ElevatedButton(
                onPressed: isBusy ? null : onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppTheme.pink,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppTheme.pink,
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 170;

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Save preferences',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: compact ? 15 : 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              SizedBox(width: compact ? 6 : 10),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: compact ? 18 : 20,
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreferencesBadge extends StatelessWidget {
  final bool compact;
  final bool tight;

  const _PreferencesBadge({required this.compact, required this.tight});

  @override
  Widget build(BuildContext context) {
    final size = tight ? 58.0 : (compact ? 68.0 : 88.0);
    final innerSize = tight ? 38.0 : (compact ? 44.0 : 52.0);
    final iconSize = tight ? 23.0 : (compact ? 25.0 : 28.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.98),
            const Color(0xFFFFF2F7),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.65),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: AppTheme.pink.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.navySoft, AppTheme.navy],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              color: Colors.white,
              size: iconSize,
            ),
          ),
          Positioned(
            top: tight ? 8 : 11,
            right: tight ? 8 : 11,
            child: Container(
              width: tight ? 10 : 14,
              height: tight ? 10 : 14,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.coral, AppTheme.pink],
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferencesProgressPills extends StatelessWidget {
  const _PreferencesProgressPills();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == 4 ? 0 : 8),
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _PreferencesBackground extends StatelessWidget {
  const _PreferencesBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B4E7C), Color(0xFF7A367B), Color(0xFFC03B6F)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            left: -40,
            child: _GlowOrb(
              size: 220,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            top: 160,
            right: -30,
            child: _GlowOrb(
              size: 170,
              color: const Color(0xFFFFC2D9).withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            bottom: -40,
            left: 30,
            child: _GlowOrb(
              size: 180,
              color: const Color(0xFFFFE6F1).withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _ColorOption {
  final String name;
  final Color color;

  const _ColorOption(this.name, this.color);
}
