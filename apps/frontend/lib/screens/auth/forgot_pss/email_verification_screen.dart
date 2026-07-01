import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/app/app_theme.dart';
import 'package:frontend/screens/auth/forgot_pss/reset_password_screen.dart';
import 'package:frontend/screens/auth/widgets/auth_ui.dart';
import 'package:frontend/services/api_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(4, (_) => FocusNode());

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
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

  String get _code => _controllers.map((e) => e.text).join();
  bool get _canSubmit => _code.length == 4;

  Future<void> _handleVerify() async {
    FocusScope.of(context).unfocus();

    if (_code.length != 4) {
      _showMessage('Please enter the 4-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.verifyResetCode(
        email: widget.email,
        code: _code,
      );

      if (!mounted) return;

      _showMessage(
        'Code verified successfully',
        color: Colors.green,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            email: widget.email,
            code: _code,
          ),
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

  void _onChanged(String value, int index) {
    if (value.length > 1) {
      _controllers[index].text = value.substring(value.length - 1);
      _controllers[index].selection = TextSelection.fromPosition(
        const TextPosition(offset: 1),
      );
    }

    if (value.isNotEmpty && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }

    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    setState(() {});
  }

  Widget _otpBox(int index) {
    final isActive =
        _focusNodes[index].hasFocus || _controllers[index].text.isNotEmpty;
    final isFilled = _controllers[index].text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 64,
      height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isFilled
              ? [
                  const Color(0xFFFFFBFD),
                  Colors.white,
                ]
              : [
                  Colors.white,
                  const Color(0xFFFCFDFF),
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isActive
              ? AppTheme.pink
              : AppTheme.navy.withValues(alpha: 0.08),
          width: isActive ? 1.4 : 1,
        ),
        boxShadow: isActive || isFilled
            ? [
                BoxShadow(
                  color: (isFilled ? AppTheme.navy : AppTheme.pink)
                      .withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        textInputAction:
            index == 3 ? TextInputAction.done : TextInputAction.next,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: isFilled ? AppTheme.navy : AppTheme.navySoft,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          filled: false,
        ),
        onChanged: (value) => _onChanged(value, index),
        onSubmitted: (_) {
          if (index == 3 && !_isLoading) {
            _handleVerify();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Email Verification',
      subtitle: 'Enter the 4-digit code we sent to ${widget.email}',
      onBack: () => Navigator.pop(context),
      child: Column(
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
                    Icons.mark_email_read_outlined,
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
                        'Verification code',
                        style: TextStyle(
                          color: AppTheme.navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Type the code exactly as received in your inbox to continue securely.',
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
                  Icons.timer_outlined,
                  size: 18,
                  color: AppTheme.pink,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Enter all 4 digits in order. The field advances automatically as you type.',
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
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFBFCFF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.navy.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Enter code',
                  style: TextStyle(
                    color: AppTheme.navy.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, _otpBox),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          AuthPrimaryButton(
            label: 'Verify Code',
            isLoading: _isLoading,
            enabled: _canSubmit,
            onPressed: _handleVerify,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Secure verification before password reset',
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
