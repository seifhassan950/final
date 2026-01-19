import 'dart:ui';
import 'package:flutter/material.dart';
import '../api/r2v_api.dart';
import '../api/api_exception.dart';

class OTPVerification extends StatefulWidget {
  final String email;

  const OTPVerification({super.key, required this.email});

  @override
  State<OTPVerification> createState() => _OTPVerificationState();
}

class _OTPVerificationState extends State<OTPVerification> {
  final List<TextEditingController> otp =
      List.generate(4, (_) => TextEditingController());
  bool _loading = false;

  @override
  void dispose() {
    for (var c in otp) {
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
          final double maxWidth = constraints.maxWidth;
          final double maxHeight = constraints.maxHeight;

          final bool isWeb = maxWidth > 600;
          final double contentWidth = maxWidth > 430 ? 430 : maxWidth;
          final double shapeScale = isWeb ? 0.55 : 0.80;

          return Stack(
            alignment: Alignment.topCenter,
            children: [
              //----------------------------
              // BACKGROUND SHAPES
              //----------------------------

              Positioned(
                top: 40 * shapeScale,
                left: -80 * shapeScale,
                child: Transform.scale(
                  scale: shapeScale,
                  child: Image.asset(
                    "assets/shapes/helix.png", // A shape
                    width: contentWidth * 0.95,
                  ),
                ),
              ),

              Positioned(
                top: 420 * shapeScale,
                right: -60 * shapeScale,
                child: Transform.scale(
                  scale: shapeScale,
                  child: Image.asset(
                    "assets/shapes/pyramid_1.png", // B shape
                    width: contentWidth * 0.85,
                  ),
                ),
              ),

              //----------------------------
              // GLASS CARD CENTERED
              //----------------------------
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: contentWidth,
                    maxHeight: maxHeight - 30,
                  ),
                  child: _buildGlassCard(isWeb, contentWidth),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGlassCard(bool isWeb, double width) {
    final card = Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 28),
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
      child: _cardContent(width),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: isWeb ? card : SingleChildScrollView(child: card),
      ),
    );
  }

  Widget _cardContent(double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //---------------------------------
        // TITLE
        //---------------------------------
        const Text(
          "Verification",
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),

        Text(
          "Enter the 4-digit code sent to:",
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 15,
          ),
        ),

        Text(
          widget.email,
          style: const TextStyle(
            color: Color(0xFF4CC9F0),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),

        const SizedBox(height: 28),

        //---------------------------------
        // OTP BOXES
        //---------------------------------
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (i) => _otpBox(i, width)),
        ),

        const SizedBox(height: 32),

        //---------------------------------
        // VERIFY BUTTON
        //---------------------------------
        GestureDetector(
          onTap: _loading
              ? null
              : () async {
            String code = otp.map((c) => c.text).join();

            if (code.length != 4) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Enter the full 4-digit code")),
              );
              return;
            }

            setState(() => _loading = true);
            try {
              final resetToken = await r2vPasswordReset.verifyCode(widget.email, code);
              if (!mounted) return;
              Navigator.pushNamed(context, "/setnewpass", arguments: resetToken);
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

        const SizedBox(height: 22),

        //---------------------------------
        // RESEND BUTTON
        //---------------------------------
        Center(
          child: TextButton(
            onPressed: _loading
                ? null
                : () async {
                    setState(() => _loading = true);
                    try {
                      final res = await r2vPasswordReset.requestReset(widget.email);
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
        )
      ],
    );
  }

  Widget _otpBox(int index, double width) {
    return Container(
      width: width * 0.16,
      height: width * 0.16,
      decoration: BoxDecoration(
        color: const Color(0xFF262730),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
      ),
      child: Center(
        child: TextField(
          controller: otp[index],
          textAlign: TextAlign.center,
          maxLength: 1,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          decoration: const InputDecoration(
            counterText: "",
            border: InputBorder.none,
          ),
          onChanged: (value) {
            if (value.isNotEmpty && index < 3) {
              FocusScope.of(context).nextFocus();
            }
          },
        ),
      ),
    );
  }
}
