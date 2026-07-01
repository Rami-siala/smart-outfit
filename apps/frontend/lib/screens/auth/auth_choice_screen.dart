import 'package:flutter/material.dart';
import 'package:frontend/screens/auth/sign_in_screen.dart';
import 'package:frontend/screens/auth/sign_up_screen.dart';

class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F4FF),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF7F6FF), Color(0xFFF5F2FF), Color(0xFFF7F5FF)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 780;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 24 : 32,
                  vertical: compact ? 18 : 28,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (compact ? 36 : 56),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const Spacer(),
                        _HeroBadge(compact: compact),
                        SizedBox(height: compact ? 28 : 36),
                        Text(
                          'Smart Outfit',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF0D1833),
                            fontSize: compact ? 38 : 44,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                          ),
                        ),
                        SizedBox(height: compact ? 18 : 20),
                        const _MiniIconRow(),
                        SizedBox(height: compact ? 18 : 22),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Text(
                            'Discover outfits designed around your wardrobe, daily weather, and the way you love to dress.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(
                                0xFF0D1833,
                              ).withValues(alpha: 0.78),
                              fontSize: compact ? 16 : 18,
                              height: 1.65,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 54 : 68),
                        _PrimaryAuthButton(
                          compact: compact,
                          label: 'Sign in with Email',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignInScreen(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: compact ? 34 : 42),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Text(
                              'Don’t have an account?',
                              style: TextStyle(
                                color: const Color(
                                  0xFF0D1833,
                                ).withValues(alpha: 0.82),
                                fontSize: compact ? 15 : 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: const Color(0xFF5425F8),
                                  fontSize: compact ? 15 : 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final bool compact;

  const _HeroBadge({required this.compact});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 118.0 : 132.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B46FF).withValues(alpha: 0.10),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: const Center(
        child: SizedBox(
          width: 58,
          height: 58,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 2,
                top: 16,
                child: Icon(
                  Icons.checkroom_outlined,
                  color: Color(0xFF4D2AE8),
                  size: 30,
                ),
              ),
              Positioned(
                right: 0,
                top: 2,
                child: Icon(
                  Icons.wb_sunny_outlined,
                  color: Color(0xFF4D2AE8),
                  size: 24,
                ),
              ),
              Positioned(
                right: 4,
                bottom: 2,
                child: Icon(
                  Icons.cloud_outlined,
                  color: Color(0xFF9FA3C7),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniIconRow extends StatelessWidget {
  const _MiniIconRow();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFB0AEC4);

    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.wb_sunny_outlined, color: color, size: 22),
        SizedBox(width: 12),
        Icon(Icons.cloud_outlined, color: color, size: 22),
        SizedBox(width: 12),
        Icon(Icons.thermostat_outlined, color: color, size: 22),
        SizedBox(width: 12),
        Icon(Icons.checkroom_outlined, color: color, size: 22),
      ],
    );
  }
}

class _PrimaryAuthButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool compact;

  const _PrimaryAuthButton({
    required this.label,
    required this.onTap,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF5425D9), Color(0xFFA01864)],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C228E).withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: compact ? 72 : 78,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            textStyle: TextStyle(
              fontSize: compact ? 18 : 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
