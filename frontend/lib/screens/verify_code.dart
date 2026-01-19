import 'dart:ui';
import 'package:flutter/material.dart';
import '../api/r2v_api.dart';
import '../api/api_exception.dart';

class VerifyCode extends StatefulWidget {
  final String email;

  const VerifyCode({super.key, required this.email});

  @override
  State<VerifyCode> createState() => _VerifyCodeState();
}

class _VerifyCodeState extends State<VerifyCode> {
  final List<TextEditingController> _otp =
      List.generate(4, (_) => TextEditingController());
  bool _loading = false;

  @override
  void dispose() {
    for (var c in _otp) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF21222A),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;

          final bool isWeb = maxWidth > 600;
          final double contentWidth = maxWidth > 430 ? 430 : maxWidth;
          final double shapeScale = isWeb ? 0.55 : 0.80;

          return Stack(
            alignment: Alignment.topCenter,
            children: [
              // SHAPE A
              Positioned(
                top: -30 * shapeScale,
                left: -50 * shapeScale,
                child: Transform.scale(
                  scale: shapeScale,
                  child: Image.asset(
                    "assets/shapes/thorus_1.png",
                    width: contentWidth * 0.85,
                  ),
                ),
              ),

              // SHAPE B
              Positioned(
                bottom: 50 * shapeScale,
                right: -105 * shapeScale,
                child: Transform.scale(
                  scale: shapeScale,
                  child: Image.asset(
                    "assets/shapes/icosahedron.png",
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

  // =====================================================
  // GLASS CARD
  // =====================================================
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
        child: isWeb ? card : SingleChildScrollView(child: card),
      ),
    );
  }

  // =====================================================
  // PAGE CONTENT
  // =====================================================
  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Verify Your Account",
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),

        Text(
          "We’ve sent a code to:",
          style: TextStyle(color: Colors.white.withOpacity(0.85)),
        ),
        Text(
          widget.email,
          style: const TextStyle(
            color: Color(0xFF4CC9F0),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 28),

        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) => _otpBox(i)),
          ),
        ),

        const SizedBox(height: 32),

        // VERIFY BUTTON
        GestureDetector(
          onTap: _loading
              ? null
              : () async {
            String code = _otp.map((e) => e.text).join();
            if (code.length == 4) {
              setState(() => _loading = true);
              try {
                await r2vEmailVerification.verifyCode(widget.email, code);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email verified')),
                );
                Navigator.pushNamed(context, '/home');
              } on ApiException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message)),
                );
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Verification failed')),
                );
              } finally {
                if (mounted) setState(() => _loading = false);
              }
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
                "Verify Code",
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

        Center(
          child: TextButton(
            onPressed: _loading
                ? null
                : () async {
                    setState(() => _loading = true);
                    try {
                      final res = await r2vEmailVerification.requestCode(widget.email);
                      if (!mounted) return;
                      if (res.devCode != null && res.devCode!.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Verification code: ${res.devCode}')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Verification code resent')),
                        );
                      }
                    } on ApiException catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message)),
                      );
                    } catch (_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to resend code')),
                      );
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
            child: const Text(
              "Resend Code",
              style: TextStyle(
                color: Color(0xFF4CC9F0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // OTP BOX
  // =====================================================
  Widget _otpBox(int index) {
    return Container(
      width: 60,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1.5,
        ),
        color: Colors.white.withOpacity(0.1),
      ),
      child: TextField(
        controller: _otp[index],
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 3) {
            FocusScope.of(context).nextFocus();
          }
        },
      ),
    );
  }
}
