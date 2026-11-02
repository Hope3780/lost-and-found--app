import 'package:flutter/material.dart';
import '../widgets/campus_background.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/feature_slideshow.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _indigo = Color(0xFF3B2FE0);
  static const _linkBlue = Color(0xFF5B5BFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CampusBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                // Top tagline
                const Text(
                  'Thinking Beyond',
                  style: TextStyle(
                    color: Color(0xFFB8C4D4),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 1.5,
                  ),
                ),

                const Spacer(flex: 3),

                // Logo + title (drops in first)
                FadeSlideIn(
                  duration: const Duration(milliseconds: 1000),
                  slideY: -40,
                  scaleFrom: 0.8,
                  curve: Curves.easeOutBack,
                  child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.asset(
                        'assets/images/CUT_medium.jpg',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.school, color: Color(0xFF17396A)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CUT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'Lost & Found',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                  ),
                ),

                const Spacer(flex: 2),

                // Feature slideshow (fades up after the logo lands)
                const FadeSlideIn(
                  delay: Duration(milliseconds: 700),
                  duration: Duration(milliseconds: 900),
                  slideY: 50,
                  child: FeatureSlideshow(),
                ),

                const Spacer(flex: 2),

                // Get Started + login link (fade in last)
                FadeSlideIn(
                  delay: const Duration(milliseconds: 1400),
                  child: Column(children: [
                SizedBox(
                  width: 240,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const LoginScreen(startInSignUp: true),
                        ),
                      );
                    },
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Already have an account?
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: _linkBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                  ]),
                ),

                const Spacer(flex: 3),

                // Footer
                const Text(
                  'CUT  •  LOST & FOUND',
                  style: TextStyle(
                    color: Color(0xFFB8C4D4),
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}