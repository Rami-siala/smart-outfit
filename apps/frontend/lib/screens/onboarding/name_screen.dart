import 'package:flutter/material.dart';
import 'package:frontend/app/app_theme.dart';
import 'package:frontend/screens/auth/sign_in_screen.dart';
import 'package:frontend/screens/onboarding/birth_date_screen.dart';
import 'package:frontend/services/api_service.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final TextEditingController _nameController = TextEditingController();

  bool _isLoadingSavedName = true;
  bool _isSavingName = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadSavedName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedName() async {
    try {
      final me = await ApiService.getMe();
      final savedName = (me['full_name'] ?? '').toString().trim();

      if (savedName.isNotEmpty) {
        _nameController.text = savedName;
      }
    } catch (e) {
      debugPrint('LOAD SAVED NAME ERROR: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSavedName = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await ApiService.logout();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const SignInScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  Future<void> _goNext() async {
    if (_isSavingName) return;

    final fullName = _nameController.text.trim();

    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSavingName = true;
    });

    try {
      await ApiService.updateMe(fullName: fullName);

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BirthDateScreen(fullName: fullName),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingName = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isBusy =
        _isLoadingSavedName || _isSavingName || _isLoggingOut;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            const _NameBackground(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TopBar(
                          isBusy: isBusy,
                          isLoggingOut: _isLoggingOut,
                          onLogout: _logout,
                        ),
                        const SizedBox(height: 26),
                        const _HeroPanel(),
                        const SizedBox(height: 18),
                        _QuestionCard(
                          controller: _nameController,
                          isBusy: isBusy,
                          isSavingName: _isSavingName,
                          onSubmitted: _goNext,
                          onNext: _goNext,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoadingSavedName)
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

class _TopBar extends StatelessWidget {
  final bool isBusy;
  final bool isLoggingOut;
  final VoidCallback onLogout;

  const _TopBar({
    required this.isBusy,
    required this.isLoggingOut,
    required this.onLogout,
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
            onPressed: isBusy ? null : onLogout,
            tooltip: 'Logout',
            icon: isLoggingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.logout_rounded,
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
                Icons.auto_awesome_rounded,
                size: 16,
                color: Colors.white,
              ),
              SizedBox(width: 8),
              Text(
                'Style setup',
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

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

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
          const _QuestionBadge(),
          const SizedBox(height: 18),
          const Text(
            'Question 1 of 5',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Let\'s start with\nyour name',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1.02,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'We\'ll use it to personalize your setup and make the rest of onboarding feel more human.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          const _ProgressPills(),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isBusy;
  final bool isSavingName;
  final VoidCallback onSubmitted;
  final VoidCallback onNext;

  const _QuestionCard({
    required this.controller,
    required this.isBusy,
    required this.isSavingName,
    required this.onSubmitted,
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
                  Icons.person_outline_rounded,
                  size: 16,
                  color: AppTheme.pink,
                ),
                SizedBox(width: 8),
                Text(
                  'Your identity',
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
            'What should we call you?',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 24,
              height: 1.08,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use your real name or a name you\'re comfortable seeing throughout the app.',
            style: TextStyle(
              color: AppTheme.navy.withValues(alpha: 0.62),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FD),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE5ECF5)),
            ),
            child: TextField(
              controller: controller,
              enabled: !isBusy,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmitted(),
              style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.badge_outlined,
                  color: AppTheme.pink,
                ),
                hintText: 'Enter your name',
                hintStyle: TextStyle(
                  color: AppTheme.navy.withValues(alpha: 0.35),
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
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
                    Icons.lightbulb_outline_rounded,
                    color: AppTheme.coral,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This helps us personalize your onboarding flow before we suggest outfits and weather-aware looks.',
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
          SizedBox(
            width: double.infinity,
            height: 58,
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
                child: isSavingName
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
        ],
      ),
    );
  }
}

class _QuestionBadge extends StatelessWidget {
  const _QuestionBadge();

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
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 15,
              height: 15,
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
          Positioned(
            left: 10,
            bottom: 12,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD7E7),
                borderRadius: BorderRadius.circular(999),
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
                Container(
                  width: 26,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white, width: 1.7),
                  ),
                ),
                Positioned(
                  bottom: 13,
                  right: 13,
                  child: Transform.rotate(
                    angle: -0.42,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.white, width: 1.7),
                          bottom: BorderSide(color: Colors.white, width: 1.7),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 17,
                  child: Container(
                    width: 12,
                    height: 1.7,
                    color: Colors.white.withValues(alpha: 0.95),
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

class _ProgressPills extends StatelessWidget {
  const _ProgressPills();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final isActive = index == 0;
        final isNext = index == 1;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == 4 ? 0 : 8),
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white
                  : isNext
                      ? Colors.white.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _NameBackground extends StatelessWidget {
  const _NameBackground();

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
            top: 150,
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
