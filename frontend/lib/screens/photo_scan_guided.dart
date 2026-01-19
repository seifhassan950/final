import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/r2v_api.dart';
import '../api/api_exception.dart';
import '../api/scan_jobs_service.dart';

class PhotoScanGuidedScreen extends StatefulWidget {
  const PhotoScanGuidedScreen({Key? key}) : super(key: key);

  @override
  State<PhotoScanGuidedScreen> createState() => _PhotoScanGuidedScreenState();
}

class _PhotoScanGuidedScreenState extends State<PhotoScanGuidedScreen>
    with SingleTickerProviderStateMixin {
  // ---------- theme ----------
  static const accent = Color(0xFFBC70FF);
  static const accent2 = Color(0xFF8A4FFF);
  static const green = Color(0xFF22C55E);

  // ---------- animation ----------
  late final AnimationController _intro;

  // ---------- capture state ----------
  CameraController? _cam;
  bool _ready = false;
  bool _capturing = false;

  int _photoCount = 0;
  final int _target = 40;

  // ---------- upload state ----------
  Uint8List? _webPickedBytes;
  String? _webPickedName;
  final List<ScanUpload> _pendingUploads = [];
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();

    // ✅ only init camera on mobile
    if (!kIsWeb) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final cam = cams.first;

      final controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _cam = controller;
        _ready = true;
      });
    } catch (e) {
      // ignore (you can show dialog)
      debugPrint("Camera init error: $e");
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _cam?.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // MOBILE: camera capture (safe)
  // ------------------------------------------------------------
  Future<void> _capture() async {
    if (kIsWeb) return;
    if (_capturing) return;
    if (_cam == null || !_cam!.value.isInitialized) return;

    setState(() => _capturing = true);
    try {
      final file = await _cam!.takePicture();
      final bytes = await file.readAsBytes();
      _addUpload(file.name, bytes);
      if (!mounted) return;
      setState(() => _photoCount = _pendingUploads.length);
    } catch (e) {
      debugPrint("Capture error: $e");
    } finally {
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) setState(() => _capturing = false);
    }
  }

  // ------------------------------------------------------------
  // MOBILE: upload from gallery (optional)
  // ------------------------------------------------------------
  Future<void> _pickFromGalleryMobile() async {
    if (kIsWeb) return;
    final picker = ImagePicker();
    try {
      final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (x == null) return;

      final bytes = await x.readAsBytes();
      _addUpload(x.name, bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Selected: ${x.name}"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _photoCount = _pendingUploads.length);
    } catch (e) {
      debugPrint("Gallery pick error: $e");
    }
  }

  // ------------------------------------------------------------
  // WEB: upload only
  // ------------------------------------------------------------
  Future<void> _pickOnWeb() async {
    if (!kIsWeb) return;

    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const ["png", "jpg", "jpeg", "webp"],
      withData: true,
    );

    if (res == null || res.files.isEmpty) return;

    final f = res.files.first;
    setState(() {
      _webPickedBytes = f.bytes;
      _webPickedName = f.name;
      if (f.bytes != null) {
        _pendingUploads.clear();
        _addUpload(f.name, f.bytes!);
      }
    });
  }

  void _addUpload(String filename, Uint8List bytes) {
    final type = _contentTypeForFilename(filename);
    _pendingUploads.add(ScanUpload(filename: filename, bytes: bytes, contentType: type));
  }

  String _contentTypeForFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _finish() async {
    if (_pendingUploads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Upload at least one image first."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      final job = await r2vScanJobs.createJob(kind: 'photos');
      for (final upload in _pendingUploads) {
        final url = await r2vScanJobs.presignUpload(
          jobId: job.id,
          filename: upload.filename,
          contentType: upload.contentType,
        );
        await r2vScanJobs.uploadToPresignedUrl(url, upload.bytes, upload.contentType);
      }
      final started = await r2vScanJobs.startJob(job.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Scan started (status: ${started.status})"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _pendingUploads.clear();
        _photoCount = 0;
        _webPickedBytes = null;
        _webPickedName = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Upload failed")),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWebWide = MediaQuery.of(context).size.width >= 900;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        const Positioned.fill(child: NebulaMeshBackground()),

        Scaffold(
          backgroundColor: Colors.transparent,

          // ✅ Web = upload only
          body: kIsWeb
              ? Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isWebWide ? 980 : 560),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, safeTop + 18, 16, safeBottom + 18),
                      child: Column(
                        children: [
                          _TopGlassBar(
                            title: "Photo Scan",
                            subtitle: "Web Upload",
                            onBack: () => Navigator.pop(context),
                          ),
                          const SizedBox(height: 16),

                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(26),
                                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _TipsRow(),
                                      const SizedBox(height: 14),

                                      Expanded(
                                        child: GestureDetector(
                                          onTap: _pickOnWeb,
                                          child: Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.06),
                                              borderRadius: BorderRadius.circular(22),
                                              border: Border.all(color: Colors.white.withOpacity(0.14)),
                                            ),
                                            child: Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.cloud_upload_rounded,
                                                      size: 44, color: Colors.white.withOpacity(0.8)),
                                                  const SizedBox(height: 10),
                                                  Text(
                                                    _webPickedBytes == null
                                                        ? "Click to upload images"
                                                        : "Selected: $_webPickedName",
                                                    style: TextStyle(
                                                      color: Colors.white.withOpacity(0.9),
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    "PNG / JPG / JPEG / WEBP",
                                                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: _pickOnWeb,
                                              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                                              label: const Text("Upload"),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                side: BorderSide(color: Colors.white.withOpacity(0.18)),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: _uploading ? null : _finish,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: accent2,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                              ),
                                              child: const Text("Finish & Continue",
                                                  style: TextStyle(fontWeight: FontWeight.w900)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )

              // ✅ Mobile = camera + upload
              : Stack(
                  children: [
                    // FULLSCREEN camera area
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(14, safeTop + 14, 14, safeBottom + 14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.20),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(color: Colors.white.withOpacity(0.12)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(26),
                                child: _ready && _cam != null
                                    ? Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          CameraPreview(_cam!),

                                          // Guide overlay (frame + grid)
                                          const _GuideOverlay(),

                                          // top glass bar
                                          Positioned(
                                            left: 12,
                                            right: 12,
                                            top: 12,
                                            child: _TopGlassBar(
                                              title: "Photo Scan",
                                              subtitle: "Mobile Camera",
                                              onBack: () => Navigator.pop(context),
                                              trailing: _CounterChip(count: _photoCount, target: _target),
                                            ),
                                          ),

                                          // tips chips
                                          Positioned(
                                            left: 12,
                                            right: 12,
                                            top: 78,
                                            child: _TipsRow(compact: true),
                                          ),

                                          // bottom controls (glass)
                                          Positioned(
                                            left: 12,
                                            right: 12,
                                            bottom: 12,
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(24),
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                                child: Container(
                                                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.22),
                                                    borderRadius: BorderRadius.circular(24),
                                                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      // Upload (gallery)
                                                      _SmallGlassButton(
                                                        icon: Icons.photo_library_rounded,
                                                        label: "Upload",
                                                        onTap: () {
                                                          _pickFromGalleryMobile();
                                                        },
                                                      ),
                                                      const Spacer(),

                                                      // Capture
                                                      GestureDetector(
                                                        onTap: () {
                                                          _capture();
                                                        },
                                                        child: _CaptureButton(active: !_capturing),
                                                      ),

                                                      const Spacer(),

                                                      // Finish
                                                      _SmallGlassButton(
                                                        icon: Icons.check_rounded,
                                                        label: "Finish",
                                                        onTap: _uploading
                                                            ? null
                                                            : () {
                                                                _finish();
                                                              },
                                                        accent: green,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Center(
                                        child: _LoadingGlass(),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ============================================================
// UI pieces
// ============================================================

class _TopGlassBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Widget? trailing;

  const _TopGlassBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.sensors_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 11)),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CounterChip extends StatelessWidget {
  final int count;
  final int target;

  const _CounterChip({required this.count, required this.target});

  @override
  Widget build(BuildContext context) {
    final done = count >= target;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: (done ? const Color(0xFF22C55E) : const Color(0xFFBC70FF)).withOpacity(0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (done ? const Color(0xFF22C55E) : const Color(0xFFBC70FF)).withOpacity(0.45),
        ),
      ),
      child: Text(
        "$count/$target",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _TipsRow extends StatelessWidget {
  final bool compact;
  const _TipsRow({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final items = const [
      ("A", "Center object"),
      ("B", "Move around"),
      ("C", "40 photos"),
      ("D", "Good light"),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((e) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 6 : 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFBC70FF).withOpacity(0.22),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBC70FF).withOpacity(0.5)),
                ),
                child: Text(e.$1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              Text(
                e.$2,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 12 : 13,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SmallGlassButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? accent;

  const _SmallGlassButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final a = accent ?? const Color(0xFFBC70FF);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: a.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: a.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final bool active;
  const _CaptureButton({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: active ? 1 : 0.6,
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: Colors.white.withOpacity(0.18),
          border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.20), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFBC70FF), size: 38),
      ),
    );
  }
}

class _LoadingGlass extends StatelessWidget {
  const _LoadingGlass();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.20),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text("Preparing camera...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Guide overlay: frame + grid to help user center object
// ============================================================

class _GuideOverlay extends StatelessWidget {
  const _GuideOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GuidePainter(),
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // frame
    final frameW = w * 0.72;
    final frameH = h * 0.52;
    final left = (w - frameW) / 2;
    final top = (h - frameH) / 2;

    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, frameW, frameH),
      const Radius.circular(18),
    );

    // subtle dark outside
    final outside = Path()..addRect(Rect.fromLTWH(0, 0, w, h));
    final inside = Path()..addRRect(r);
    final overlay = Path.combine(PathOperation.difference, outside, inside);

    final dimPaint = Paint()..color = Colors.black.withOpacity(0.25);
    canvas.drawPath(overlay, dimPaint);

    // frame border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFBC70FF).withOpacity(0.65);
    canvas.drawRRect(r, borderPaint);

    // grid inside frame
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(0.18);

    // vertical lines (rule of thirds)
    canvas.drawLine(
      Offset(left + frameW / 3, top),
      Offset(left + frameW / 3, top + frameH),
      gridPaint,
    );
    canvas.drawLine(
      Offset(left + (frameW * 2) / 3, top),
      Offset(left + (frameW * 2) / 3, top + frameH),
      gridPaint,
    );

    // horizontal lines
    canvas.drawLine(
      Offset(left, top + frameH / 3),
      Offset(left + frameW, top + frameH / 3),
      gridPaint,
    );
    canvas.drawLine(
      Offset(left, top + (frameH * 2) / 3),
      Offset(left + frameW, top + (frameH * 2) / 3),
      gridPaint,
    );

    // center dot
    final dot = Paint()..color = Colors.white.withOpacity(0.5);
    canvas.drawCircle(Offset(w / 2, h / 2), 3, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// Nebula background (same style as your Explore screen)
// ============================================================

class NebulaMeshBackground extends StatefulWidget {
  const NebulaMeshBackground({super.key});

  @override
  State<NebulaMeshBackground> createState() => _NebulaMeshBackgroundState();
}

class _NebulaMeshBackgroundState extends State<NebulaMeshBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final Random _rng = Random(42);

  Size _size = Size.zero;
  Offset _mouse = Offset.zero;
  bool _hasMouse = false;

  late List<_NebulaParticle> _ps;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ps = <_NebulaParticle>[];
    _ticker = createTicker((elapsed) {
      _t = elapsed.inMilliseconds / 1000.0;
      if (!mounted) return;
      if (_size == Size.zero) return;

      const dt = 1 / 60;
      for (final p in _ps) {
        p.pos = p.pos + p.vel * dt;
        if (p.pos.dx < 0 || p.pos.dx > _size.width) p.vel = Offset(-p.vel.dx, p.vel.dy);
        if (p.pos.dy < 0 || p.pos.dy > _size.height) p.vel = Offset(p.vel.dx, -p.vel.dy);
        p.pos = Offset(p.pos.dx.clamp(0.0, _size.width), p.pos.dy.clamp(0.0, _size.height));
      }
      setState(() {});
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _ensureParticles(Size s) {
    if (s == Size.zero) return;

    final area = s.width * s.height;
    int target = (area / 18000).round();
    target = target.clamp(35, 95);

    if (_ps.length == target) return;

    _ps = List.generate(target, (i) {
      final pos = Offset(_rng.nextDouble() * s.width, _rng.nextDouble() * s.height);
      final speed = 8 + _rng.nextDouble() * 18;
      final ang = _rng.nextDouble() * pi * 2;
      final vel = Offset(cos(ang), sin(ang)) * speed;
      final r = 1.2 + _rng.nextDouble() * 1.9;
      return _NebulaParticle(pos: pos, vel: vel, radius: r);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final s = Size(c.maxWidth, c.maxHeight);
      if (_size != s) {
        _size = s;
        _ensureParticles(s);
      }

      return MouseRegion(
        onHover: (e) {
          _hasMouse = true;
          _mouse = e.localPosition;
        },
        onExit: (_) => _hasMouse = false,
        child: CustomPaint(
          painter: _NebulaPainter(
            particles: _ps,
            time: _t,
            size: s,
            mouse: _mouse,
            hasMouse: _hasMouse,
          ),
        ),
      );
    });
  }
}

class _NebulaParticle {
  Offset pos;
  Offset vel;
  final double radius;

  _NebulaParticle({required this.pos, required this.vel, required this.radius});
}

class _NebulaPainter extends CustomPainter {
  final List<_NebulaParticle> particles;
  final double time;
  final Size size;
  final Offset mouse;
  final bool hasMouse;

  _NebulaPainter({
    required this.particles,
    required this.time,
    required this.size,
    required this.mouse,
    required this.hasMouse,
  });

  @override
  void paint(Canvas canvas, Size _) {
    final rect = Offset.zero & size;

    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F1118), Color(0xFF141625), Color(0xFF0B0D14)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    void glowBlob(Offset c, double r, Color col, double a) {
      final p = Paint()
        ..color = col.withOpacity(a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90);
      canvas.drawCircle(c, r, p);
    }

    final center = Offset(size.width * 0.55, size.height * 0.35);
    final wobble = Offset(sin(time * 0.5) * 40, cos(time * 0.45) * 30);

    glowBlob(center + wobble, 280, const Color(0xFF8A4FFF), 0.18);
    glowBlob(
      Offset(size.width * 0.25, size.height * 0.70) + Offset(cos(time * 0.35) * 35, sin(time * 0.32) * 28),
      240,
      const Color(0xFF4895EF),
      0.14,
    );

    Offset parallax = Offset.zero;
    if (hasMouse) {
      final dx = (mouse.dx / max(1.0, size.width) - 0.5) * 18;
      final dy = (mouse.dy / max(1.0, size.height) - 0.5) * 18;
      parallax = Offset(dx, dy);
    }

    final connectDist = min(size.width, size.height) * 0.15;
    final connectDist2 = connectDist * connectDist;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < particles.length; i++) {
      final a = particles[i];
      final ap = a.pos + parallax * 0.25;

      for (int j = i + 1; j < particles.length; j++) {
        final b = particles[j];
        final bp = b.pos + parallax * 0.25;

        final dx = ap.dx - bp.dx;
        final dy = ap.dy - bp.dy;
        final d2 = dx * dx + dy * dy;

        if (d2 < connectDist2) {
          final t = 1.0 - (sqrt(d2) / connectDist);
          linePaint.color = Colors.white.withOpacity(0.06 * t);
          canvas.drawLine(ap, bp, linePaint);
        }
      }
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final pos = p.pos + parallax * 0.6;
      dotPaint.color = Colors.white.withOpacity(0.12);
      canvas.drawCircle(pos, p.radius, dotPaint);
    }

    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.15,
        colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
        stops: const [0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter oldDelegate) => true;
}
