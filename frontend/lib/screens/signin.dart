import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../api/r2v_api.dart';
import '../api/api_exception.dart';

class SignIn extends StatefulWidget {
  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _loading = false;

  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // FIX A
      backgroundColor: const Color(0xFF21222A),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double maxWidth = constraints.maxWidth;
          final double maxHeight = constraints.maxHeight;

          final bool isWeb = maxWidth > 600;
          final double contentWidth = maxWidth > 430 ? 430 : maxWidth;
          final double shapeScale = isWeb ? 0.55 : 0.80;

          return Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: -30 * shapeScale,
                left: -50 * shapeScale,
                child: Transform.scale(
                  scale: shapeScale,
                  child: Image.asset(
                    "assets/shapes/helix.png",
                    width: contentWidth * 0.85,
                  ),
                ),
              ),
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
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: contentWidth,
                    maxHeight: maxHeight - 30,
                  ),
                  child: _glassCard(contentWidth, isWeb),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _glassCard(double width, bool isWeb) {
    final card = Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 34),
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
      child: _content(width),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: isWeb ? card : SingleChildScrollView(child: card),
      ),
    );
  }

  Widget _content(double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Welcome Back!",
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "welcome back we missed you",
          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15),
        ),
        const SizedBox(height: 32),

        _label("Email"),
        _input(
          controller: _email,
          icon: Icons.person_outline,
          hint: "you@example.com",
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: 22),

        _label("Password"),
        _input(
          controller: _password, // ✅ FIX: was missing
          icon: Icons.lock_outline,
          hint: "enter your password",
          obscure: _obscurePassword,
          suffix: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white60,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  activeColor: const Color(0xFFB197FC),
                  checkColor: Colors.white,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                ),
                Text(
                  "Remember Me",
                  style: TextStyle(color: Colors.white.withOpacity(0.65)),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/forgot'),
              child: Text(
                "Forgot Password?",
                style: TextStyle(color: Colors.white.withOpacity(0.85)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        GestureDetector(
          onTap: _loading
              ? null
              : () async {
                  setState(() => _loading = true);
                  final email = _email.text.trim();
                  final pass = _password.text;
                  try {
                    await r2vAuth.login(
                      email: email,
                      password: pass,
                      persist: _rememberMe,
                    );
                    if (!mounted) return;
                    Navigator.pushNamed(context, '/home');
                  } on ApiException catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message)),
                    );
                  } catch (_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sign in failed')),
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
                "Sign In",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don’t have an Account ? ",
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/signup'),
              child: const Text(
                "Sign up",
                style: TextStyle(
                  color: Color(0xFF4CC9F0),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

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
            _social(FontAwesomeIcons.google, () {
              Navigator.pushNamed(context, '/completeprofile');
            }),
            const SizedBox(width: 16),
            _social(FontAwesomeIcons.apple, () {
              Navigator.pushNamed(context, '/completeprofile');
            }),
            const SizedBox(width: 16),
            _social(FontAwesomeIcons.microsoft, () {
              Navigator.pushNamed(context, '/completeprofile');
            }),
          ],
        ),
      ],
    );
  }

  Widget _label(String txt) {
    return Text(
      txt,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w500,
        fontSize: 14.5,
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      autofillHints: keyboard == TextInputType.emailAddress
          ? const [AutofillHints.email]
          : (obscure ? const [AutofillHints.password] : null),
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: suffix,
        hintText: " | $hint",
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white70),
        ),
      ),
    );
  }

  Widget _social(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFF262730),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
