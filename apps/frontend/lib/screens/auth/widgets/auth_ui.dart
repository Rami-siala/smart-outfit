import 'package:flutter/material.dart';
import 'package:frontend/app/app_theme.dart';

class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.mist,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final panelMinHeight = (constraints.maxHeight - 250).clamp(
            420.0,
            double.infinity,
          ).toDouble();

          return DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFF7F9FD),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.navy.withValues(alpha: 0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: onBack,
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppTheme.navy,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 132,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: -30,
                            top: 18,
                            child: _AuthGlowBubble(
                              size: 120,
                              colors: [
                                AppTheme.coral.withValues(alpha: 0.12),
                                AppTheme.pink.withValues(alpha: 0.03),
                              ],
                            ),
                          ),
                          Positioned(
                            right: -10,
                            top: -12,
                            child: _AuthGlowBubble(
                              size: 150,
                              colors: [
                                AppTheme.navy.withValues(alpha: 0.12),
                                const Color(0xFF77B6EA).withValues(alpha: 0.03),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 18,
                            right: 18,
                            bottom: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.88),
                                    Colors.white.withValues(alpha: 0.68),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.navy.withValues(alpha: 0.08),
                                    blurRadius: 24,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppTheme.navy,
                                          AppTheme.navySoft,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(
                                      Icons.lock_reset_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Private account recovery',
                                          style: TextStyle(
                                            color: AppTheme.navy.withValues(
                                              alpha: 0.56,
                                            ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Fast, secure access reset for your style account.',
                                          style: TextStyle(
                                            color: AppTheme.navy,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.97, end: 1),
                      duration: const Duration(milliseconds: 360),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, (1 - value) * 24),
                          child: Transform.scale(scale: value, child: child),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        constraints: BoxConstraints(
                          maxWidth: 460,
                          minHeight: panelMinHeight,
                        ),
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.97),
                              const Color(0xFFFFFCFE).withValues(alpha: 0.94),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.navy.withValues(alpha: 0.09),
                              blurRadius: 34,
                              offset: const Offset(0, 18),
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
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.pink.withValues(alpha: 0.14),
                                    AppTheme.coral.withValues(alpha: 0.14),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppTheme.pink.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 14,
                                    color: AppTheme.navy,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Smart Style',
                                    style: TextStyle(
                                      color: AppTheme.navy,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              title,
                              style: const TextStyle(
                                color: AppTheme.navy,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: AppTheme.navy.withValues(alpha: 0.62),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 28),
                            child,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AuthGlowBubble extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _AuthGlowBubble({
    required this.size,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;
  final String? errorText;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.navy.withValues(alpha: 0.74),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          textInputAction: textInputAction,
          style: const TextStyle(
            color: AppTheme.navy,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            errorText: errorText,
            prefixIcon: Icon(icon, color: AppTheme.pink, size: 20),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool enabled;
  final VoidCallback? onPressed;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: enabled
              ? const [AppTheme.coral, AppTheme.pink]
              : [
                  AppTheme.coral.withValues(alpha: 0.45),
                  AppTheme.pink.withValues(alpha: 0.45),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppTheme.coral.withValues(alpha: 0.22),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: enabled && !isLoading ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}

class SocialAuthButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget icon;
  final String label;
  final Color? backgroundColor;
  final Color foregroundColor;
  final BorderSide? borderSide;

  const SocialAuthButton({
    super.key,
    required this.onTap,
    required this.icon,
    required this.label,
    this.backgroundColor,
    this.foregroundColor = AppTheme.navy,
    this.borderSide,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor ?? Colors.white,
          foregroundColor: foregroundColor,
          side: borderSide ??
              BorderSide(
                color: AppTheme.navy.withValues(alpha: 0.08),
              ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: icon,
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class AuthFooterLink extends StatelessWidget {
  final String prompt;
  final String actionLabel;
  final VoidCallback onTap;

  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text(
            prompt,
            style: TextStyle(
              color: AppTheme.navy.withValues(alpha: 0.62),
              fontWeight: FontWeight.w500,
            ),
          ),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.coral, AppTheme.pink],
                ).createShader(bounds),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
