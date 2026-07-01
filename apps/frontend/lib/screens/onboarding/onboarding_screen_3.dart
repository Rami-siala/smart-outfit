import 'package:flutter/material.dart';
import '../auth/auth_choice_screen.dart';

class OnboardingScreen3 extends StatelessWidget {
  const OnboardingScreen3({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryPink = Color(0xFFC2185B);
    const Color bgColor = Color(0xFFF4F1F2);
    const Color textDark = Color(0xFF111111);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  SizedBox(
                    width: 330,
                    height: 390,
                    child: Image.asset(
                      'assets/images/onboarding3.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 20),

                  RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins',
                      ),
                      children: [
                        TextSpan(
                          text: 'Wardrobe',
                          style: TextStyle(color: primaryPink),
                        ),
                        TextSpan(
                          text: '\nSuggestions!',
                          style: TextStyle(color: textDark),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: 90,
                    height: 90,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AuthChoiceScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPink,
                        elevation: 0,
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        'Next',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _dot(false),
                      const SizedBox(width: 6),
                      _dot(false),
                      const SizedBox(width: 6),
                      _dot(true),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _dot(bool isActive) {
    return Container(
      width: isActive ? 22 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFC2185B) : const Color(0xFFE1A9BF),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}