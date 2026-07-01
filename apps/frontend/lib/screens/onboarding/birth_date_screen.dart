import 'package:flutter/material.dart';
import 'package:frontend/app/app_theme.dart';
import 'package:frontend/services/api_service.dart';
import 'gender_screen.dart';

const List<String> _monthLabels = <String>[
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

class BirthDateScreen extends StatefulWidget {
  final String fullName;

  const BirthDateScreen({
    super.key,
    required this.fullName,
  });

  @override
  State<BirthDateScreen> createState() => _BirthDateScreenState();
}

class _BirthDateScreenState extends State<BirthDateScreen> {
  DateTime? _selectedDate;
  bool _isLoadingSavedDate = true;
  bool _isSavingDate = false;

  @override
  void initState() {
    super.initState();
    _loadSavedBirthDate();
  }

  Future<void> _loadSavedBirthDate() async {
    try {
      final profile = await ApiService.getMyProfile();

      if (profile != null) {
        final birthDateValue = profile['birth_date'];

        if (birthDateValue != null &&
            birthDateValue.toString().trim().isNotEmpty) {
          final parsedDate = DateTime.tryParse(birthDateValue.toString());
          if (parsedDate != null) {
            _selectedDate = parsedDate;
          }
        }
      }
    } catch (e) {
      debugPrint('LOAD BIRTH DATE ERROR: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSavedDate = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate =
        _selectedDate ?? DateTime(now.year - 18, now.month, now.day);

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _BirthDatePickerSheet(
          initialDate: initialDate,
          firstDate: DateTime(1950, 1, 1),
          lastDate: now,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String get _formattedDate {
    if (_selectedDate == null) return 'Select your birth date';

    final d = _selectedDate!;
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();

    return '$day / $month / $year';
  }

  void _showMessage(String message, {Color backgroundColor = Colors.redAccent}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  Future<void> _goBack() async {
    if (_isSavingDate) return;

    setState(() {
      _isSavingDate = true;
    });

    try {
      if (_selectedDate != null) {
        await ApiService.updateMyProfile(
          birthDate: _selectedDate!,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDate = false;
        });
      }
    }
  }

  Future<void> _goNext() async {
    if (_isSavingDate) return;

    if (_selectedDate == null) {
      _showMessage('Please select your birth date');
      return;
    }

    setState(() {
      _isSavingDate = true;
    });

    try {
      await ApiService.updateMyProfile(
        birthDate: _selectedDate!,
      );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GenderScreen(
            fullName: widget.fullName,
            birthDate: _selectedDate!,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDate = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isLoadingSavedDate || _isSavingDate;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            const _BirthBackground(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BirthTopBar(
                          isBusy: isBusy,
                          onBack: _goBack,
                        ),
                        const SizedBox(height: 26),
                        const _BirthHeroPanel(),
                        const SizedBox(height: 18),
                        _BirthQuestionCard(
                          formattedDate: _formattedDate,
                          isBusy: isBusy,
                          isSavingDate: _isSavingDate,
                          hasSelectedDate: _selectedDate != null,
                          onPickDate: _pickDate,
                          onBack: _goBack,
                          onNext: _goNext,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoadingSavedDate)
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

class _BirthTopBar extends StatelessWidget {
  final bool isBusy;
  final VoidCallback onBack;

  const _BirthTopBar({
    required this.isBusy,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: IconButton(
            onPressed: isBusy ? null : onBack,
            tooltip: 'Back',
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cake_outlined,
                size: 16,
                color: Colors.white,
              ),
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

class _BirthHeroPanel extends StatelessWidget {
  const _BirthHeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
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
          const _BirthBadge(),
          const SizedBox(height: 18),
          const Text(
            'Question 2 of 5',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'When is your\nbirthday?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1.02,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your birth date helps us complete your profile and personalize the experience more accurately.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          const _BirthProgressPills(),
        ],
      ),
    );
  }
}

class _BirthQuestionCard extends StatelessWidget {
  final String formattedDate;
  final bool isBusy;
  final bool isSavingDate;
  final bool hasSelectedDate;
  final VoidCallback onPickDate;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _BirthQuestionCard({
    required this.formattedDate,
    required this.isBusy,
    required this.isSavingDate,
    required this.hasSelectedDate,
    required this.onPickDate,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
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
                Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: AppTheme.pink,
                ),
                SizedBox(width: 8),
                Text(
                  'Personal timeline',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pick your birth date',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 24,
              height: 1.08,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the exact date or the closest one you want to use on your profile.',
            style: TextStyle(
              color: AppTheme.navy.withValues(alpha: 0.62),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 22),
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: isBusy ? null : onPickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FD),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE5ECF5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      color: AppTheme.pink,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasSelectedDate ? 'Selected date' : 'Birth date',
                          style: TextStyle(
                            color: AppTheme.navy.withValues(alpha: 0.48),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            color: hasSelectedDate
                                ? AppTheme.navy
                                : AppTheme.pink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.pink,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.mist,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppTheme.coral,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This stays part of your profile details and helps keep your onboarding information complete.',
                    style: TextStyle(
                      color: AppTheme.navy.withValues(alpha: 0.74),
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
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
                      child: isSavingDate
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
                                    fontSize: 17,
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

class _BirthBadge extends StatelessWidget {
  const _BirthBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
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
            top: 11,
            right: 11,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.coral, AppTheme.pink],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.coral.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.navySoft, AppTheme.navy],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.navy.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 10,
                  child: Row(
                    children: List.generate(
                      3,
                      (index) => Container(
                        width: 4,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 15,
                  child: Container(
                    width: 28,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Positioned(
                  top: 15,
                  child: Container(
                    width: 28,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.pink,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  top: 22,
                  child: Text(
                    '12',
                    style: TextStyle(
                      color: AppTheme.navy,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
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

class _BirthProgressPills extends StatelessWidget {
  const _BirthProgressPills();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final isCompleted = index == 0;
        final isActive = index == 1;

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

class _BirthBackground extends StatelessWidget {
  const _BirthBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2B4E7C),
            Color(0xFF7A367B),
            Color(0xFFC03B6F),
          ],
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
            top: 180,
            right: -40,
            child: _GlowOrb(
              size: 190,
              color: const Color(0xFFFFC2D9).withValues(alpha: 0.16),
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

  const _GlowOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _BirthDatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _BirthDatePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_BirthDatePickerSheet> createState() => _BirthDatePickerSheetState();
}

class _BirthDatePickerSheetState extends State<_BirthDatePickerSheet> {
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
    _selectedDay = widget.initialDate.day;
    _clampDay();
  }

  int get _daysInSelectedMonth {
    return DateTime(_selectedYear, _selectedMonth + 1, 0).day;
  }

  void _clampDay() {
    final maxDay = _daysInSelectedMonth;
    if (_selectedDay > maxDay) {
      _selectedDay = maxDay;
    }
  }

  DateTime get _resolvedDate {
    final candidate = DateTime(_selectedYear, _selectedMonth, _selectedDay);
    if (candidate.isBefore(widget.firstDate)) return widget.firstDate;
    if (candidate.isAfter(widget.lastDate)) return widget.lastDate;
    return candidate;
  }

  @override
  Widget build(BuildContext context) {
    final years = List<int>.generate(
      widget.lastDate.year - widget.firstDate.year + 1,
      (index) => widget.firstDate.year + index,
    ).reversed.toList();
    final days = List<int>.generate(_daysInSelectedMonth, (index) => index + 1);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7DFEB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Choose your birth date',
                style: TextStyle(
                  color: AppTheme.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pick the day, month, and year directly.',
                style: TextStyle(
                  color: AppTheme.navy.withValues(alpha: 0.62),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _PickerField<int>(
                      label: 'Day',
                      value: _selectedDay,
                      items: days,
                      itemLabel: (value) => value.toString().padLeft(2, '0'),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedDay = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _PickerField<int>(
                      label: 'Month',
                      value: _selectedMonth,
                      items: List<int>.generate(12, (index) => index + 1),
                      itemLabel: (value) => _monthLabels[value - 1],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedMonth = value;
                          _clampDay();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PickerField<int>(
                label: 'Year',
                value: _selectedYear,
                items: years,
                itemLabel: (value) => value.toString(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedYear = value;
                    _clampDay();
                    final adjusted = _resolvedDate;
                    _selectedYear = adjusted.year;
                    _selectedMonth = adjusted.month;
                    _selectedDay = adjusted.day;
                  });
                },
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.mist,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'Selected: ${_resolvedDate.day.toString().padLeft(2, '0')} ${_monthLabels[_resolvedDate.month - 1]} ${_resolvedDate.year}',
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.navy,
                          backgroundColor: AppTheme.mist,
                          side: BorderSide(
                            color: AppTheme.navy.withValues(alpha: 0.10),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppTheme.coral, AppTheme.pink],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(_resolvedDate);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                          ),
                          child: const Text(
                            'Use this date',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
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
    );
  }
}

class _PickerField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;

  const _PickerField({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.navy.withValues(alpha: 0.60),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FD),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5ECF5)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              borderRadius: BorderRadius.circular(18),
              dropdownColor: Colors.white,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppTheme.pink,
              ),
              style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
