import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'signup.dart';
import 'signin.dart';

class Welcome extends StatefulWidget {
  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  @override
  Widget build(BuildContext context) {
    final double screenWidth  = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    final bool isWeb = screenWidth > 600;
    final double contentWidth = screenWidth > 430 ? 430 : screenWidth;
    final double shapeScale = isWeb ? 0.75 : 0.80;
    final double topPadding = isWeb ? 90 : 170;

    return Scaffold(
      backgroundColor: const Color(0xFF21222A),
      body: Center(
        child: SizedBox(
          width: contentWidth,
          height: screenHeight,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Shape 1
              Positioned(
                top: -20 * shapeScale,
                left: -50 * shapeScale,
                child: Transform.scale(
                  scale: shapeScale,
                  child: Image.asset(
                    "assets/shapes/helix.png",
                    width: contentWidth * 0.85,
                  ),
                ),
              ),

              // Shape 2
              Positioned(
                top: 80 * shapeScale,
                right: -105 * shapeScale,
                child: Transform.scale(
                  scale: shapeScale,
                  child: Image.asset(
                    "assets/shapes/pyramid_1.png",
                    width: contentWidth * 0.90,
                  ),
                ),
              ),

              // Center content
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: topPadding),
                  _buildGlassCard(contentWidth),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard(double width) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          width: width,
          padding: const EdgeInsets.fromLTRB(26, 34, 26, 34),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(38),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF21222A).withOpacity(0.33),
                const Color(0xFF202128).withOpacity(0.33),
                const Color(0xFF21222A).withOpacity(0.35),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1.4,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo (optional)
              Image.asset(
                'assets/r2v_icon.png',
                width: width * 0.35,
              ),
              const SizedBox(height: 12),

              const Text(
                "Real To Virtual",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 6),
              Text(
                "Scan, generate & explore 3D models\nfrom your real-world ideas.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 28),

              // Sign Up
              _primaryButton(
                label: "Sign Up",
                onTap: () {
                  Navigator.push(
                    context,
                    PageTransition(
                      type: PageTransitionType.fade,
                      child: SignUp(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              // Sign In
              _secondaryButton(
                label: "Sign In",
                onTap: () {
                  Navigator.push(
                    context,
                    PageTransition(
                      type: PageTransitionType.fade,
                      child: SignIn(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8A4FFF), Color(0xFFBC70FF)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.2),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
