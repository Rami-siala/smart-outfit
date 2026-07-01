import 'package:flutter/material.dart';
import 'package:frontend/app/app_theme.dart';
import 'package:frontend/screens/auth/forgot_pss/email_verification_screen.dart';
import 'package:frontend/screens/auth/widgets/auth_ui.dart';
import 'package:frontend/services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {Color color = AppTheme.coral}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  bool _validateEmail() {
    final email = _emailController.text.trim().toLowerCase();
    const emailPattern = r'^[^@\s]+@[^@\s]+\.[^@\s]+$';

    setState(() {
      _emailError = email.isEmpty
          ? 'Please enter your email'
          : (!RegExp(emailPattern).hasMatch(email)
              ? 'Please enter a valid email'
              : null);
    });

    return _emailError == null;
  }

  Future<void> _handleProceed() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim().toLowerCase();

    if (!_validateEmail()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.forgotPassword(email: email);

      if (!mounted) return;

      _showMessage(
        'Reset code sent successfully',
        color: Colors.green,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(email: email),
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

  bool get _canSubmit => _emailController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Forgot Password',
      subtitle: 'Enter the email linked to your account',
      onBack: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.mist,
                  Colors.white.withValues(alpha: 0.92),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.navy.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.navy, AppTheme.navySoft],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'What happens next',
                        style: TextStyle(
                          color: AppTheme.navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'We will send a 4-digit verification code to help you create a new password.',
                        style: TextStyle(
                          color: AppTheme.navy.withValues(alpha: 0.66),
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7FB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.pink.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: AppTheme.pink,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Use the email connected to your profile so we can verify you faster.',
                    style: TextStyle(
                      color: AppTheme.navy.withValues(alpha: 0.68),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFBFCFF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.navy.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recovery email',
                  style: TextStyle(
                    color: AppTheme.navy.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 12),
                AuthTextField(
                  controller: _emailController,
                  label: 'Email',
                  hintText: 'you@example.com',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  errorText: _emailError,
                  onChanged: (_) => setState(() => _emailError = null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          AuthPrimaryButton(
            label: 'Send Code',
            isLoading: _isLoading,
            enabled: _canSubmit,
            onPressed: _handleProceed,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Secure reset powered by email verification',
              style: TextStyle(
                color: AppTheme.navy.withValues(alpha: 0.48),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
