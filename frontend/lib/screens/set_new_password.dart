import 'dart:ui';
import 'package:flutter/material.dart';
import '../api/r2v_api.dart';
import '../api/api_exception.dart';

class SetNewPasswordPage extends StatefulWidget {
  final String? resetToken;

  const SetNewPasswordPage({super.key, this.resetToken});

  @override
  State<SetNewPasswordPage> createState() => _SetNewPasswordPageState();
}

class _SetNewPasswordPageState extends State<SetNewPasswordPage> {
  final TextEditingController pass1 = TextEditingController();
  final TextEditingController pass2 = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  @override
  void dispose() {
    pass1.dispose();
    pass2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset:
          false, // ⭐ FIX A — background no longer shifts upward
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
              // ============================================================
              // BACKGROUND SHAPES (fixed; won’t move on keyboard)
              // ============================================================
              Positioned(
                bottom: 100 * shapeScale,
                left: -40 * shapeScale,
                child: Transform.scale(
                  scale: shapeScale,
                  child: Image.asset(
                    "assets/shapes/spheres_2.png",
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
                    "assets/shapes/thorus_1.png",
                    width: contentWidth * 0.95,
                  ),
                ),
              ),

              // ============================================================
              // CENTER GLASS CARD
              // ============================================================
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

  // ============================================================
  // GLASS CARD WRAPPER
  // ============================================================
  Widget _glassCard(double width, bool isWeb) {
    final card = Container(
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
      child: _content(),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),

        // ⭐ Phone scrolls only inside the card
        child: isWeb ? card : SingleChildScrollView(child: card),
      ),
    );
  }

  // ============================================================
  // CARD CONTENT
  // ============================================================
  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -------------------------------------------------------
        // TITLE
        // -------------------------------------------------------
        const Text(
          "Set New Password",
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 6),
        Text(
          "Enter your new password below",
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 15,
          ),
        ),

        const SizedBox(height: 26),

        // -------------------------------------------------------
        // PASSWORD FIELD 1
        // -------------------------------------------------------
        _label("Password"),
        _inputField(
          controller: pass1,
          hint: "Enter your new password",
          obscure: _obscure1,
          toggle: () => setState(() => _obscure1 = !_obscure1),
        ),

        const SizedBox(height: 22),

        // -------------------------------------------------------
        // PASSWORD FIELD 2
        // -------------------------------------------------------
        _label("Confirm Password"),
        _inputField(
          controller: pass2,
          hint: "Re-enter your password",
          obscure: _obscure2,
          toggle: () => setState(() => _obscure2 = !_obscure2),
        ),

        const SizedBox(height: 35),

        // -------------------------------------------------------
        // UPDATE BUTTON
        // -------------------------------------------------------
        GestureDetector(
          onTap: _loading
              ? null
              : () async {
            if (pass1.text.isEmpty || pass2.text.isEmpty) {
              _error("Please fill all fields");
              return;
            }
            if (pass1.text != pass2.text) {
              _error("Passwords do not match");
              return;
            }

            if (widget.resetToken == null || widget.resetToken!.isEmpty) {
              _error("Missing reset token");
              return;
            }

            setState(() => _loading = true);
            try {
              await r2vPasswordReset.resetPassword(widget.resetToken!, pass1.text);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password updated')),
              );
              Navigator.pushNamed(context, '/signin');
            } on ApiException catch (e) {
              if (!mounted) return;
              _error(e.message);
            } catch (_) {
              if (!mounted) return;
              _error("Password update failed");
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
                "Update Password",
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

  // ============================================================
  // LABEL
  // ============================================================
  Widget _label(String txt) {
    return Text(
      txt,
      style: TextStyle(
        color: Colors.white.withOpacity(0.95),
        fontWeight: FontWeight.w500,
        fontSize: 14.5,
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required Function toggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.white60,
          ),
          onPressed: () => toggle(),
        ),
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

  // ============================================================
  // ERROR SNACKBAR
  // ============================================================
  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text(msg),
      ),
    );
  }
}
