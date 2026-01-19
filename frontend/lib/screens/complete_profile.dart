import 'dart:ui';
import 'package:flutter/material.dart';
import '../api/r2v_api.dart';
import '../api/api_exception.dart';

class CompleteProfile extends StatefulWidget {
  @override
  State<CompleteProfile> createState() => _CompleteProfileState();
}

class _CompleteProfileState extends State<CompleteProfile> {
  final TextEditingController username = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController pass1 = TextEditingController();
  final TextEditingController pass2 = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  @override
  void dispose() {
    username.dispose();
    phone.dispose();
    pass1.dispose();
    pass2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset:
          false, // ⭐ FIX A → keyboard won't move background
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
              // ======================================================
              // BACKGROUND SHAPES (do not move)
              // ======================================================
              Positioned(
                bottom: 100 * shapeScale,
                left: -50 * shapeScale,
                child: Transform.scale(
                  scale: shapeScale,
                  child: Image.asset(
                    "assets/shapes/spheres_1.png",
                    width: contentWidth * 0.85,
                  ),
                ),
              ),
              Positioned(
                top: 70 * shapeScale,
                right: -80 * shapeScale,
                child: Transform.scale(
                  scale: shapeScale,
                  child: Image.asset(
                    "assets/shapes/cone.png",
                    width: contentWidth * 0.90,
                  ),
                ),
              ),

              // ======================================================
              // GLASS CARD CENTERED
              // ======================================================
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: contentWidth,
                    maxHeight: maxHeight - 40,
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

  // ======================================================
  // GLASS CARD CONTAINER
  // ======================================================
  Widget _glassCard(double width, bool isWeb) {
    final inner = Container(
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
            const Color(0xFF21222A).withOpacity(0.36),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1.4,
        ),
      ),
      child: _content(),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),

        // ⭐ On phones: scroll only INSIDE card
        child: isWeb ? inner : SingleChildScrollView(child: inner),
      ),
    );
  }

  // ======================================================
  // MAIN CONTENT INSIDE GLASS CARD
  // ======================================================
  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ------------------------------------------------------
        // TITLE
        // ------------------------------------------------------
        const Text(
          "Complete Profile",
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),

        Text(
          "Finish your profile to continue",
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 15,
          ),
        ),

        const SizedBox(height: 24),

        // ------------------------------------------------------
        _label("Username"),
        _inputField(
          controller: username,
          hint: "Enter your username",
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 20),

        // ------------------------------------------------------
        _label("Phone Number"),
        _inputField(
          controller: phone,
          hint: "01XXXXXXXXX",
          icon: Icons.phone_outlined,
          type: TextInputType.phone,
        ),
        const SizedBox(height: 20),

        // ------------------------------------------------------
        _label("Password"),
        _inputField(
          controller: pass1,
          hint: "Enter your password",
          icon: Icons.lock_outline,
          obscure: _obscure1,
          suffix: IconButton(
            icon: Icon(
              _obscure1 ? Icons.visibility_off : Icons.visibility,
              color: Colors.white60,
            ),
            onPressed: () => setState(() => _obscure1 = !_obscure1),
          ),
        ),
        const SizedBox(height: 20),

        // ------------------------------------------------------
        _label("Confirm Password"),
        _inputField(
          controller: pass2,
          hint: "Re-enter your password",
          icon: Icons.lock_outline,
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

        // ------------------------------------------------------
        // CONTINUE BUTTON
        // ------------------------------------------------------
        GestureDetector(
          onTap: _loading
              ? null
              : () async {
            if (username.text.isEmpty ||
                phone.text.isEmpty ||
                pass1.text.isEmpty ||
                pass2.text.isEmpty) {
              _error("Please fill all fields");
              return;
            }
            if (pass1.text != pass2.text) {
              _error("Passwords do not match");
              return;
            }

            setState(() => _loading = true);
            try {
              final current = await r2vProfile.me();
              final meta = Map<String, dynamic>.from(current.meta);
              meta['phone'] = phone.text.trim();
              await r2vProfile.update(
                username: username.text.trim(),
                meta: meta,
              );
              await r2vAuth.changePassword(pass1.text);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile updated')),
              );
              Navigator.pushNamed(context, '/home');
            } on ApiException catch (e) {
              if (!mounted) return;
              _error(e.message);
            } catch (_) {
              if (!mounted) return;
              _error("Profile update failed");
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF8A4FFF),
                  Color(0xFFBC70FF),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Text(
                "Continue",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ======================================================
  // LABEL WIDGET
  // ======================================================
  Widget _label(String txt) {
    return Text(
      txt,
      style: TextStyle(
        color: Colors.white.withOpacity(0.95),
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // ======================================================
  // TEXT FIELD WIDGET
  // ======================================================
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: suffix,
        hintText: " | $hint",
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.45),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white70),
        ),
      ),
    );
  }

  // ======================================================
  // ERROR POPUP
  // ======================================================
  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text(msg),
      ),
    );
  }
}
