import 'package:flutter/material.dart';
import 'package:frontend/app/app_theme.dart';
import 'package:frontend/screens/auth/auth_choice_screen.dart';
import 'package:frontend/screens/auth/forgot_pss/forgot_password_screen.dart';
import 'package:frontend/screens/auth/post_login_redirect_screen.dart';
import 'package:frontend/screens/auth/sign_up_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/location_service.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_validateInputs()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.login(
        email: email,
        password: password,
      );
      await LocationService.resetLocationPreferenceForLogin();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login successful'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const PostLoginRedirectScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _validateInputs() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    const emailPattern = r'^[^@\s]+@[^@\s]+\.[^@\s]+$';

    setState(() {
      _emailError = email.isEmpty
          ? 'Please enter your email'
          : (!RegExp(emailPattern).hasMatch(email)
              ? 'Enter a valid email address'
              : null);
      _passwordError = password.isEmpty
          ? 'Please enter your password'
          : (password.length < 6
              ? 'Password must be at least 6 characters'
              : null);
    });

    return _emailError == null && _passwordError == null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.coral,
      ),
    );
  }

  bool get _canSubmit =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const AuthChoiceScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FF),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8F7FF),
              Color(0xFFF4F2FF),
              Color(0xFFF8F6FF),
            ],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _AuthBackgroundGlow()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 760;
                  final horizontalPadding = compact ? 22.0 : 28.0;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      compact ? 10 : 14,
                      horizontalPadding,
                      MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            _AuthTopBar(onBack: _handleBack),
                            SizedBox(height: compact ? 18 : 26),
                            const _BrandHero(
                              title: 'Smart Outfit',
                              subtitle:
                                  'Sign in to continue your personalized style journey.',
                            ),
                            SizedBox(height: compact ? 18 : 26),
                            _AuthCard(
                              compact: compact,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _AuthInputField(
                                    controller: _emailController,
                                    label: 'EMAIL ADDRESS',
                                    hintText: 'name@example.com',
                                    icon: Icons.mail_outline_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    errorText: _emailError,
                                    onChanged: (_) => setState(() => _emailError = null),
                                    compact: compact,
                                  ),
                                  SizedBox(height: compact ? 14 : 18),
                                  _AuthInputField(
                                    controller: _passwordController,
                                    label: 'PASSWORD',
                                    hintText: 'Password',
                                    icon: Icons.lock_outline_rounded,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    errorText: _passwordError,
                                    onChanged: (_) => setState(() => _passwordError = null),
                                    compact: compact,
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: const Color(0xFF7D7A90),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: compact ? 6 : 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ForgotPasswordScreen(),
                                          ),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF432BE6),
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          fontSize: compact ? 14 : 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: compact ? 12 : 16),
                                  _PrimaryActionButton(
                                    label: 'Sign In',
                                    compact: compact,
                                    enabled: _canSubmit,
                                    isLoading: _isLoading,
                                    onPressed: _handleSignIn,
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Padding(
                              padding: EdgeInsets.only(top: compact ? 18 : 22),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  Text(
                                    "Don't have an account?",
                                    style: TextStyle(
                                      color: const Color(0xFF101B31)
                                          .withValues(alpha: 0.82),
                                      fontSize: compact ? 15 : 16,
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
                                    child: const Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        color: Color(0xFF432BE6),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthBackgroundGlow extends StatelessWidget {
  const _AuthBackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          right: -40,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFDCCEFF).withValues(alpha: 0.55),
                  const Color(0xFFDCCEFF).withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -90,
          bottom: -20,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFE9DDFF).withValues(alpha: 0.48),
                  const Color(0xFFE9DDFF).withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthTopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _AuthTopBar({
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B46FF).withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF4A33E6),
              size: 32,
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'SMART OUTFIT',
                style: TextStyle(
                  color: Color(0xFF4A33E6),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _BrandHero extends StatelessWidget {
  final String title;
  final String subtitle;

  const _BrandHero({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _HeroMark(),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF101B31),
            fontSize: 34,
            height: 1.02,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 10),
        const _MiniIconRow(),
        const SizedBox(height: 12),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF101B31).withValues(alpha: 0.74),
            fontSize: 17,
            height: 1.55,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _HeroMark extends StatelessWidget {
  const _HeroMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B46FF).withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: const Center(
        child: SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            children: [
              Positioned(
                left: 6,
                top: 28,
                child: Icon(
                  Icons.checkroom_outlined,
                  color: Color(0xFF4D2AE8),
                  size: 30,
                ),
              ),
              Positioned(
                right: 10,
                top: 8,
                child: Icon(
                  Icons.wb_sunny_outlined,
                  color: Color(0xFF4D2AE8),
                  size: 24,
                ),
              ),
              Positioned(
                right: 14,
                bottom: 12,
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
        Icon(Icons.wb_sunny_outlined, color: color, size: 20),
        SizedBox(width: 12),
        Icon(Icons.cloud_outlined, color: color, size: 20),
        SizedBox(width: 12),
        Icon(Icons.thermostat_outlined, color: color, size: 20),
        SizedBox(width: 12),
        Icon(Icons.checkroom_outlined, color: color, size: 20),
      ],
    );
  }
}

class _AuthCard extends StatelessWidget {
  final Widget child;
  final bool compact;

  const _AuthCard({
    required this.child,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 22,
        compact ? 18 : 22,
        compact ? 18 : 22,
        compact ? 20 : 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1E4F).withValues(alpha: 0.07),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AuthInputField extends StatelessWidget {
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
  final bool compact;

  const _AuthInputField({
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
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF77748B),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          textInputAction: textInputAction,
          style: TextStyle(
            color: obscureText ? const Color(0xFF9DA3B8) : const Color(0xFF2A2E45),
            fontSize: compact ? 15 : 16,
            fontWeight: FontWeight.w500,
            letterSpacing: obscureText ? 2.2 : 0,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            errorText: errorText,
            filled: true,
            fillColor: const Color(0xFFF4F5FF),
            prefixIcon: Icon(
              icon,
              color: const Color(0xFF7D7A90),
              size: compact ? 24 : 26,
            ),
            suffixIcon: suffixIcon,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: compact ? 16 : 18,
            ),
            hintStyle: TextStyle(
              color: const Color(0xFFB2B5C7),
              fontSize: compact ? 15 : 16,
              fontWeight: FontWeight.w400,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: const BorderSide(
                color: Color(0xFF7862F5),
                width: 1.4,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: const BorderSide(
                color: Color(0xFFCE5C5C),
                width: 1.2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: const BorderSide(
                color: Color(0xFFCE5C5C),
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final bool compact;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  const _PrimaryActionButton({
    required this.label,
    required this.compact,
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = enabled
        ? const [
            Color(0xFF5425D9),
            Color(0xFFA01864),
          ]
        : [
            const Color(0xFF5425D9).withValues(alpha: 0.45),
            const Color(0xFFA01864).withValues(alpha: 0.45),
          ];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: const Color(0xFF7C228E).withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ]
            : null,
      ),
      child: SizedBox(
        width: double.infinity,
        height: compact ? 58 : 64,
        child: ElevatedButton(
          onPressed: enabled && !isLoading ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: compact ? 17 : 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.arrow_forward_rounded, size: compact ? 24 : 28),
                  ],
                ),
        ),
      ),
    );
  }
}
