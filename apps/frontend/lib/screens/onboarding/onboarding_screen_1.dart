import 'package:flutter/material.dart';
import 'onboarding_screen_2.dart';

class OnboardingScreen1 extends StatelessWidget {
  const OnboardingScreen1({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryPink = Color(0xFFC2185B);
    const Color bgColor = Color(0xFFF4F1F2);
    const Color textDark = Color(0xFF111111);
    const Color textGrey = Color(0xFF666666);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  Container(
                    width: 280,
                    height: 320,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(140),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/onboarding1.png',
                      fit: BoxFit.cover,
                    ),
                  ),

                  const SizedBox(height: 30),

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
                          text: 'Stay ',
                          style: TextStyle(color: textDark),
                        ),
                        TextSpan(
                          text: 'Stylish',
                          style: TextStyle(color: primaryPink),
                        ),
                        TextSpan(
                          text: ', Stay\n',
                          style: TextStyle(color: textDark),
                        ),
                        TextSpan(
                          text: 'Informed',
                          style: TextStyle(color: primaryPink),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'We combine fashion expertise with real-time weather updates to bring you the perfect outfit suggestions for any weather condition.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textGrey,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: 220,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OnboardingScreen2(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPink,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        "Let’s go",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _dot(isActive: true),
                      const SizedBox(width: 6),
                      _dot(isActive: false),
                      const SizedBox(width: 6),
                      _dot(isActive: false),
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

  static Widget _dot({required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: isActive ? 22 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFC2185B) : const Color(0xFFE1A9BF),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}