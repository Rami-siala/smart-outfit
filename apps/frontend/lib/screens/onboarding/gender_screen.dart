import 'package:flutter/material.dart';
import 'package:frontend/app/app_theme.dart';
import 'package:frontend/screens/onboarding/preferences_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'details_user_screen.dart';

class GenderScreen extends StatefulWidget {
  final String fullName;
  final DateTime birthDate;
  final bool isGuest;
  final Map<String, dynamic>? guestWeather;
  final bool confirmLogoutOnExit;

  const GenderScreen({
    super.key,
    required this.fullName,
    required this.birthDate,
    this.isGuest = false,
    this.guestWeather,
    this.confirmLogoutOnExit = false,
  });

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  String? _selectedGender;
  bool _isLoadingSavedGender = true;
  bool _isSavingGender = false;

  @override
  void initState() {
    super.initState();
    if (widget.isGuest) {
      _isLoadingSavedGender = false;
      return;
    }
    _loadSavedGender();
  }

  Future<void> _loadSavedGender() async {
    try {
      final profile = await ApiService.getMyProfile();

      if (profile != null) {
        final savedGender = profile['gender']?.toString().trim();

        if (savedGender == 'male' || savedGender == 'female') {
          _selectedGender = savedGender;
        }
      }
    } catch (e) {
      debugPrint('LOAD GENDER ERROR: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSavedGender = false;
        });
      }
    }
  }

  void _selectGender(String gender) {
    if (_isSavingGender) return;

    setState(() {
      _selectedGender = gender;
    });
  }

  Future<void> _goBack() async {
    if (_isSavingGender) return;

    if (widget.isGuest) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSavingGender = true;
    });

    try {
      await ApiService.updateMyProfile(
        birthDate: widget.birthDate,
        gender: _selectedGender,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingGender = false;
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

  Future<void> _goNext() async {
    if (_isSavingGender) return;

    if (_selectedGender == null) {
      _showMessage('Please choose your gender');
      return;
    }

    if (widget.isGuest) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PreferencesScreen(
            selectedGender: _selectedGender!,
            isGuest: true,
            guestWeather: widget.guestWeather,
            confirmLogoutOnExit: widget.confirmLogoutOnExit,
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSavingGender = true;
    });

    try {
      await ApiService.updateMyProfile(
        birthDate: widget.birthDate,
        gender: _selectedGender!,
      );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DetailsUserScreen(
            fullName: widget.fullName,
            birthDate: widget.birthDate,
            gender: _selectedGender!,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingGender = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isLoadingSavedGender || _isSavingGender;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            const _GenderBackground(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight <= 940;
                  final tight = constraints.maxHeight <= 900;
                  final veryTight = constraints.maxHeight <= 760;
                  final topPadding = veryTight ? 6.0 : (tight ? 10.0 : 14.0);
                  final bottomPadding =
                      (veryTight ? 8.0 : (tight ? 14.0 : 24.0)) + bottomInset;

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
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
                              _GenderTopBar(isBusy: isBusy, onBack: _goBack),
                              SizedBox(
                                height: veryTight ? 8 : (tight ? 14 : 26),
                              ),
                              _GenderHeroPanel(
                                compact: compact,
                                tight: tight,
                                veryTight: veryTight,
                              ),
                              SizedBox(
                                height: veryTight ? 8 : (tight ? 12 : 18),
                              ),
                              _GenderQuestionCard(
                                selectedGender: _selectedGender,
                                isBusy: isBusy,
                                isSavingGender: _isSavingGender,
                                compact: compact,
                                tight: tight,
                                veryTight: veryTight,
                                onSelectFemale: () => _selectGender('female'),
                                onSelectMale: () => _selectGender('male'),
                                onBack: _goBack,
                                onNext: _goNext,
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
            if (_isLoadingSavedGender)
              Container(
                color: Colors.black.withValues(alpha: 0.16),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GenderTopBar extends StatelessWidget {
  final bool isBusy;
  final VoidCallback onBack;

  const _GenderTopBar({required this.isBusy, required this.onBack});

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
              Icon(Icons.diversity_3_rounded, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Profile details',
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

class _GenderHeroPanel extends StatelessWidget {
  final bool compact;
  final bool tight;
  final bool veryTight;

  const _GenderHeroPanel({
    required this.compact,
    required this.tight,
    required this.veryTight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        veryTight ? 16 : (tight ? 18 : 22),
        veryTight ? 14 : (tight ? 18 : 22),
        veryTight ? 16 : (tight ? 18 : 22),
        veryTight ? 14 : (compact ? 16 : 20),
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
          _GenderBadge(compact: compact, veryTight: veryTight),
          SizedBox(height: veryTight ? 8 : (compact ? 12 : 18)),
          const Text(
            'Question 3 of 5',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: veryTight ? 4 : (tight ? 6 : 10)),
          Text(
            'Tell us your\ngender',
            style: TextStyle(
              color: Colors.white,
              fontSize: veryTight ? 25 : (tight ? 28 : 34),
              height: 1.02,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!veryTight) ...[
            SizedBox(height: tight ? 8 : 10),
            Text(
              'Choose the profile option that fits you best so the next steps and recommendations feel more tailored.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: tight ? 13 : 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          SizedBox(height: veryTight ? 10 : (compact ? 12 : 18)),
          const _GenderProgressPills(),
        ],
      ),
    );
  }
}

class _GenderQuestionCard extends StatelessWidget {
  final String? selectedGender;
  final bool isBusy;
  final bool isSavingGender;
  final bool compact;
  final bool tight;
  final bool veryTight;
  final VoidCallback onSelectFemale;
  final VoidCallback onSelectMale;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _GenderQuestionCard({
    required this.selectedGender,
    required this.isBusy,
    required this.isSavingGender,
    required this.compact,
    required this.tight,
    required this.veryTight,
    required this.onSelectFemale,
    required this.onSelectMale,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        veryTight ? 14 : (compact ? 16 : 20),
        veryTight ? 14 : (compact ? 18 : 22),
        veryTight ? 14 : (compact ? 16 : 20),
        veryTight ? 14 : (compact ? 16 : 20),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 28 : 32),
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
                Icon(
                  Icons.person_outline_rounded,
                  size: 16,
                  color: AppTheme.pink,
                ),
                SizedBox(width: 8),
                Text(
                  'Identity',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: veryTight ? 8 : (compact ? 12 : 16)),
          Text(
            'Choose your gender',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: veryTight ? 20 : (tight ? 21 : 24),
              height: 1.08,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!veryTight) ...[
            SizedBox(height: tight ? 6 : 8),
            Text(
              'This helps us keep your profile details consistent throughout the rest of onboarding.',
              style: TextStyle(
                color: AppTheme.navy.withValues(alpha: 0.62),
                fontSize: tight ? 13 : 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          SizedBox(height: veryTight ? 10 : (compact ? 14 : 22)),
          Row(
            children: [
              Expanded(
                child: _GenderChoiceTile(
                  label: 'Female',
                  subtitle: 'Styled for you',
                  isSelected: selectedGender == 'female',
                  onTap: isBusy ? null : onSelectFemale,
                  accent: const Color(0xFFFF6A83),
                  compact: compact,
                  veryTight: veryTight,
                  child: _FemaleAvatar(compact: compact, veryTight: veryTight),
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: _GenderChoiceTile(
                  label: 'Male',
                  subtitle: 'Styled for you',
                  isSelected: selectedGender == 'male',
                  onTap: isBusy ? null : onSelectMale,
                  accent: const Color(0xFF5A87C5),
                  compact: compact,
                  veryTight: veryTight,
                  child: _MaleAvatar(compact: compact, veryTight: veryTight),
                ),
              ),
            ],
          ),
          SizedBox(height: veryTight ? 10 : (compact ? 12 : 14)),
          Container(
            padding: EdgeInsets.all(veryTight ? 10 : (compact ? 12 : 14)),
            decoration: BoxDecoration(
              color: AppTheme.mist,
              borderRadius: BorderRadius.circular(compact ? 18 : 20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 30 : 34,
                  height: compact ? 30 : 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppTheme.coral,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedGender == null
                        ? 'Select one option to continue smoothly to the next profile step.'
                        : 'Great, your selection is ready. You can still change it before moving on.',
                    style: TextStyle(
                      color: AppTheme.navy.withValues(alpha: 0.74),
                      fontSize: tight ? 12 : 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: veryTight ? 10 : (compact ? 12 : 22)),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: veryTight ? 46 : (compact ? 52 : 56),
                  child: OutlinedButton(
                    onPressed: isBusy ? null : onBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.navy,
                      backgroundColor: AppTheme.mist,
                      side: BorderSide(
                        color: AppTheme.navy.withValues(alpha: 0.10),
                      ),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: veryTight ? 46 : (compact ? 52 : 56),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.coral, AppTheme.pink],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.coral.withValues(alpha: 0.26),
                          blurRadius: 20,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: isBusy ? null : onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        disabledForegroundColor: Colors.white70,
                      ),
                      child: isSavingGender
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenderChoiceTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color accent;
  final bool compact;
  final bool veryTight;
  final Widget child;

  const _GenderChoiceTile({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.accent,
    required this.compact,
    required this.veryTight,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.fromLTRB(
            veryTight ? 10 : (compact ? 12 : 14),
            veryTight ? 10 : (compact ? 12 : 16),
            veryTight ? 10 : (compact ? 12 : 14),
            veryTight ? 10 : (compact ? 12 : 14),
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.10)
                : const Color(0xFFF7F9FD),
            borderRadius: BorderRadius.circular(compact ? 20 : 24),
            border: Border.all(
              color: isSelected ? accent : const Color(0xFFE5ECF5),
              width: isSelected ? 1.6 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: isSelected ? 1 : 0,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
              ),
              child,
              SizedBox(height: veryTight ? 6 : (compact ? 10 : 12)),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.navy,
                  fontSize: veryTight ? 15 : (compact ? 16 : 17),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (!veryTight) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.navy.withValues(alpha: 0.52),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FemaleAvatar extends StatelessWidget {
  final bool compact;
  final bool veryTight;

  const _FemaleAvatar({required this.compact, required this.veryTight});

  @override
  Widget build(BuildContext context) {
    final size = veryTight ? 52.0 : (compact ? 60.0 : 72.0);
    final scale = size / 72.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6A83).withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 12 * scale,
            child: Container(
              width: 34 * scale,
              height: 22 * scale,
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B5E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
            ),
          ),
          Positioned(
            top: 24 * scale,
            child: Container(
              width: 30 * scale,
              height: 24 * scale,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD8C8),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Positioned(
            top: 31 * scale,
            left: 25 * scale,
            child: Container(
              width: 4 * scale,
              height: 4 * scale,
              decoration: const BoxDecoration(
                color: Color(0xFF1C2A39),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 31 * scale,
            right: 25 * scale,
            child: Container(
              width: 4 * scale,
              height: 4 * scale,
              decoration: const BoxDecoration(
                color: Color(0xFF1C2A39),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 38 * scale,
            child: Container(
              width: 10 * scale,
              height: 5 * scale,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1C2A39), width: 1.4),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12 * scale,
            child: Container(
              width: 32 * scale,
              height: 14 * scale,
              decoration: const BoxDecoration(
                color: Color(0xFFFF5468),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaleAvatar extends StatelessWidget {
  final bool compact;
  final bool veryTight;

  const _MaleAvatar({required this.compact, required this.veryTight});

  @override
  Widget build(BuildContext context) {
    final size = veryTight ? 52.0 : (compact ? 60.0 : 72.0);
    final scale = size / 72.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5A87C5).withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 24 * scale,
            child: Container(
              width: 30 * scale,
              height: 24 * scale,
              decoration: BoxDecoration(
                color: const Color(0xFFD8E8F8),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Positioned(
            top: 15 * scale,
            child: Container(
              width: 36 * scale,
              height: 18 * scale,
              decoration: const BoxDecoration(
                color: Color(0xFF4F7FB3),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(10),
                ),
              ),
            ),
          ),
          Positioned(
            top: 31 * scale,
            left: 25 * scale,
            child: Container(
              width: 4 * scale,
              height: 4 * scale,
              decoration: const BoxDecoration(
                color: Color(0xFF203040),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 31 * scale,
            right: 25 * scale,
            child: Container(
              width: 4 * scale,
              height: 4 * scale,
              decoration: const BoxDecoration(
                color: Color(0xFF203040),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 38 * scale,
            child: Container(
              width: 10 * scale,
              height: 5 * scale,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF203040), width: 1.4),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12 * scale,
            child: Container(
              width: 32 * scale,
              height: 14 * scale,
              decoration: const BoxDecoration(
                color: Color(0xFF5A87C5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderBadge extends StatelessWidget {
  final bool compact;
  final bool veryTight;

  const _GenderBadge({required this.compact, required this.veryTight});

  @override
  Widget build(BuildContext context) {
    final size = veryTight ? 58.0 : (compact ? 72.0 : 88.0);
    final iconSize = veryTight ? 21.0 : 26.0;
    final iconOffset = veryTight ? 14.0 : 18.0;

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
          Positioned(
            left: iconOffset,
            top: veryTight ? 20 : 24,
            child: Icon(
              Icons.female_rounded,
              color: AppTheme.pink,
              size: iconSize,
            ),
          ),
          Positioned(
            right: iconOffset,
            top: veryTight ? 20 : 24,
            child: Icon(
              Icons.male_rounded,
              color: AppTheme.navy,
              size: iconSize,
            ),
          ),
          Positioned(
            top: veryTight ? 8 : 12,
            right: veryTight ? 8 : 12,
            child: Container(
              width: veryTight ? 10 : 12,
              height: veryTight ? 10 : 12,
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

class _GenderProgressPills extends StatelessWidget {
  const _GenderProgressPills();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final isCompleted = index == 0 || index == 1;
        final isActive = index == 2;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == 4 ? 0 : 8),
            height: 8,
            decoration: BoxDecoration(
              color: isCompleted || isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _GenderBackground extends StatelessWidget {
  const _GenderBackground();

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
