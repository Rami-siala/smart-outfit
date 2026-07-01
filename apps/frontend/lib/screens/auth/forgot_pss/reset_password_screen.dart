import 'package:flutter/material.dart';
import 'package:frontend/app/app_theme.dart';
import 'package:frontend/screens/auth/sign_in_screen.dart';
import 'package:frontend/screens/auth/widgets/auth_ui.dart';
import 'package:frontend/services/api_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String code;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.code,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  bool _validateInputs() {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    setState(() {
      _passwordError = password.isEmpty
          ? 'Please enter your new password'
          : (password.length < 6
              ? 'Password must be at least 6 characters'
              : null);
      _confirmPasswordError = confirmPassword.isEmpty
          ? 'Please confirm your password'
          : (confirmPassword != password ? 'Passwords do not match' : null);
    });

    return _passwordError == null && _confirmPasswordError == null;
  }

  Future<void> _handleConfirm() async {
    FocusScope.of(context).unfocus();

    final password = _passwordController.text.trim();

    if (!_validateInputs()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.resetPassword(
        email: widget.email,
        code: widget.code,
        newPassword: password,
      );

      if (!mounted) return;

      _showMessage(
        'Password reset successfully',
        color: Colors.green,
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const SignInScreen(),
        ),
        (route) => false,
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

  bool get _canSubmit =>
      _passwordController.text.isNotEmpty &&
      _confirmPasswordController.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create New Password',
      subtitle: 'Choose a secure password for ${widget.email}',
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
                    Icons.lock_person_outlined,
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
                        'Create a secure password',
                        style: TextStyle(
                          color: AppTheme.navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your new password should be at least 6 characters and easy for you to remember.',
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
                  Icons.shield_outlined,
                  size: 18,
                  color: AppTheme.pink,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Use something memorable to you, but hard for others to guess.',
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
                AuthTextField(
                  controller: _passwordController,
                  label: 'New password',
                  hintText: 'Create a new password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  errorText: _passwordError,
                  onChanged: (_) => setState(() => _passwordError = null),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AppTheme.navy.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                AuthTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm password',
                  hintText: 'Re-enter your new password',
                  icon: Icons.verified_user_outlined,
                  obscureText: _obscureConfirmPassword,
                  errorText: _confirmPasswordError,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() => _confirmPasswordError = null),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AppTheme.navy.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          AuthPrimaryButton(
            label: 'Reset Password',
            isLoading: _isLoading,
            enabled: _canSubmit,
            onPressed: _handleConfirm,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Your password will update immediately after confirmation',
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
