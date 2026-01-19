import 'dart:ui';
import 'package:flutter/material.dart';
import '../api/r2v_api.dart';
import '../api/api_exception.dart';

class ForgotPassword extends StatefulWidget {
  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final TextEditingController emailController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset:
          false, // ⭐ FIX A — prevents shapes from moving with keyboard
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
              // ------------------------------------------------------------------
              // BACKGROUND SHAPES (fixed, no movement on keyboard open)
              // ------------------------------------------------------------------
              Positioned(
                bottom: 140 * shapeScale,
                left: -50 * shapeScale,
                child: Transform.scale(
                  scale: shapeScale,
                  child: Image.asset(
                    "assets/shapes/spheres_2.png",
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
                    "assets/shapes/thorus_1.png",
                    width: contentWidth * 0.90,
                  ),
                ),
              ),

              // ------------------------------------------------------------------
              // CENTER GLASS CARD (no movement)
              // ------------------------------------------------------------------
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: contentWidth,
                    maxHeight: maxHeight - 40,
                  ),
                  child: _buildGlassCard(contentWidth, isWeb),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ========================================================================
  // GLASS CARD WRAPPER
  // ========================================================================
  Widget _buildGlassCard(double width, bool isWeb) {
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

        // ⭐ On phone: scroll inner content if keyboard overlaps (card stays fixed)
        child: isWeb ? card : SingleChildScrollView(child: card),
      ),
    );
  }

  // ========================================================================
  // CARD CONTENT
  // ========================================================================
  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Forgot Password",
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),

        Text(
          "Enter your email to receive a verification code",
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 15,
          ),
        ),

        const SizedBox(height: 30),

        _label("Email"),
        const SizedBox(height: 6),

        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon:
                const Icon(Icons.email_outlined, color: Colors.white70),
            hintText: " | example@gmail.com",
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white70),
            ),
          ),
        ),

        const SizedBox(height: 35),

        GestureDetector(
          onTap: _loading
              ? null
              : () async {
                  final email = emailController.text.trim();
                  if (email.isEmpty) return;

                  setState(() => _loading = true);
                  try {
                    final res = await r2vPasswordReset.requestReset(email);
                    if (!mounted) return;
                    if (res.devCode != null && res.devCode!.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Verification code: ${res.devCode}')),
                      );
                    }
                    Navigator.pushNamed(
                      context,
                      '/verifyotp',
                      arguments: email,
                    );
                  } on ApiException catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message)),
                    );
                  } catch (_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to request reset')),
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
                colors: [
                  Color(0xFF8A4FFF),
                  Color(0xFFBC70FF),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Text(
                "Send Verification Code",
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

  // ========================================================================
  // LABEL TEXT
  // ========================================================================
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
}
