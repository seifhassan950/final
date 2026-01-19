import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../api/r2v_api.dart';
import '../api/api_exception.dart';

class SignUp extends StatefulWidget {
  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  // Controllers
  final TextEditingController username = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController pass1 = TextEditingController();
  final TextEditingController pass2 = TextEditingController();

  @override
  void dispose() {
    username.dispose();
    email.dispose();
    phone.dispose();
    pass1.dispose();
    pass2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final double contentWidth = w > 430 ? 430 : w;
    final bool isWeb = w > 600;
    final double shapeScale = isWeb ? 0.55 : 0.80;

    return Scaffold(
      backgroundColor: const Color(0xFF21222A),
      body: Stack(
        children: [
          // -----------------------
          // FIXED BACKGROUND SHAPES (DO NOT MOVE)
          // -----------------------
          Positioned(
            top: 550 * shapeScale,
            left: 0,
            child: Transform.scale(
              scale: shapeScale,
              child: Image.asset(
                "assets/shapes/cone.png",
                width: contentWidth,
              ),
            ),
          ),

          Positioned(
            top: 80 * shapeScale,
            right: -60 * shapeScale,
            child: Transform.scale(
              scale: shapeScale,
              child: Image.asset(
                "assets/shapes/spheres_1.png",
                width: contentWidth * 0.90,
              ),
            ),
          ),

          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: contentWidth,
                // ❗ IMPORTANT: let height grow, don't limit it → prevents overflow on web
                maxHeight: double.infinity,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: _glassCard(contentWidth),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------
  // GLASS CARD
  // -----------------------
  Widget _glassCard(double width) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(38),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF21222A).withOpacity(0.33),
                const Color(0xFF202128).withOpacity(0.33),
                const Color(0xFF21222A).withOpacity(0.35),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.4),
          ),
          child: _content(),
        ),
      ),
    );
  }

  // -----------------------
  // CARD CONTENT
  // -----------------------
  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Create Account",
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Join R2V and start creating 3D models.",
          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15),
        ),

        const SizedBox(height: 24),

        _label("Username"),
        _input(controller: username, icon: Icons.person_outline, hint: "John123"),
        const SizedBox(height: 16),

        _label("Email"),
        _input(controller: email, icon: Icons.email_outlined, hint: "example@gmail.com"),
        const SizedBox(height: 16),

        _label("Phone Number"),
        _input(controller: phone, icon: Icons.phone_outlined, hint: "01XXXXXXXXX"),
        const SizedBox(height: 16),

        _label("Password"),
        _input(
          controller: pass1,
          icon: Icons.lock_outline,
          hint: "Enter your password",
          obscure: _obscure1,
          suffix: IconButton(
            icon: Icon(
              _obscure1 ? Icons.visibility_off : Icons.visibility,
              color: Colors.white60,
            ),
            onPressed: () => setState(() => _obscure1 = !_obscure1),
          ),
        ),
        const SizedBox(height: 16),

        _label("Confirm Password"),
        _input(
          controller: pass2,
          icon: Icons.lock_outline,
          hint: "Confirm your password",
          obscure: _obscure2,
          suffix: IconButton(
            icon: Icon(
              _obscure2 ? Icons.visibility_off : Icons.visibility,
              color: Colors.white60,
            ),
            onPressed: () => setState(() => _obscure2 = !_obscure2),
          ),
        ),

        const SizedBox(height: 30),

        // SIGN UP
        GestureDetector(
          onTap: _loading ? null : () async {
            final e = email.text.trim();
            final u = username.text.trim();
            final p1 = pass1.text;
            final p2 = pass2.text;

            if (e.isEmpty || u.isEmpty || p1.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please fill all required fields')),
              );
              return;
            }
            if (p1 != p2) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Passwords do not match')),
              );
              return;
            }

            setState(() => _loading = true);
            try {
              await r2vAuth.signup(email: e, password: p1, username: u);
              final verification = await r2vEmailVerification.requestCode(e);
              if (!mounted) return;
              if (verification.devCode != null &&
                  verification.devCode!.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Verification code: ${verification.devCode}')),
                );
              }
              Navigator.pushNamed(context, '/verifycode', arguments: e);
            } on ApiException catch (ex) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ex.message)),
              );
            } catch (_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sign up failed')),
              );
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8A4FFF), Color(0xFFBC70FF)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Text(
                "Sign Up",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 22),

        Center(
          child: Text(
            "Or continue with",
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
        ),

        const SizedBox(height: 14),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _social(FontAwesomeIcons.apple),
            const SizedBox(width: 16),
            _social(FontAwesomeIcons.google),
            const SizedBox(width: 16),
            _social(FontAwesomeIcons.microsoft),
          ],
        ),

        const SizedBox(height: 22),

        Center(
          child: RichText(
            text: TextSpan(
              text: "Already have an account? ",
              style:
                  TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13.5),
              children: [
                TextSpan(
                  text: "Sign In",
                  style: const TextStyle(
                    color: Color(0xFF4CC9F0),
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => Navigator.pushNamed(context, '/signin'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // -----------------------
  // REUSABLE WIDGETS
  // -----------------------
  Widget _label(String txt) {
    return Text(
      txt,
      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: suffix,
        hintText: " | $hint",
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
        enabledBorder:
            const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder:
            const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
      ),
    );
  }

  Widget _social(IconData icon) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/completeprofile'),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF262730),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
