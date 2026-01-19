// home_screen.dart
// ✅ Removed: Recent projects section
// ✅ Fixed: Stats labels (Models / Downloads) stay on ONE line
// ✅ Fixed: Mobile tabs stay pinned at top for ALL tabs (Home/AI/Scan/Market)

import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../api/r2v_api.dart';
import '../api/api_exception.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      routes: {
        '/': (_) => const HomeScreen(),
        '/home': (_) => const HomeScreen(),
        '/aichat': (_) => const Scaffold(body: Center(child: Text('AI Chat'))),
        '/explore': (_) => const Scaffold(body: Center(child: Text('Explore'))),
        '/settings': (_) => const Scaffold(body: Center(child: Text('Settings'))),
        '/profile': (_) => const Scaffold(body: Center(child: Text('Profile'))),
        '/photo_scan': (_) => const Scaffold(body: Center(child: Text('Photo Scan'))),
      },
    );
  }
}

/// ✅ Mouse drag support for web/desktop (ListView/PageView etc.)
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}

/// =========================
/// ✅ Marketplace-like model data (for popup)
/// =========================
class MarketModel {
  final String name;
  final String author;
  final String description;
  final List<String> tags;
  final String likes;
  final String tagLabel;
  final String glbAssetPath;
  final String posterAssetPath;

  const MarketModel({
    required this.name,
    required this.author,
    required this.description,
    required this.tags,
    required this.likes,
    required this.tagLabel,
    required this.glbAssetPath,
    required this.posterAssetPath,
  });
}

class HomeScreen extends StatefulWidget {
  final String username;

  const HomeScreen({super.key, this.username = 'User'});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Mobile tabs: 0 Home, 1 AI, 2 Scan, 3 Market
  int _selectedTab = 0;

  // Web nav: 0 Home, 1 AI, 2 Market, 3 Settings
  int _webActiveNavIndex = 0;
  int? _webHoverNavIndex;

  late final ScrollController _scrollController;
  bool _collapsed = false;

  // ===== Use cases carousel selection =====
  int _selectedUseCase = 0;
  late final ScrollController _useCaseScrollController;
  Timer? _useCaseAutoTimer;
  bool _pauseUseCaseAutoScroll = false;
  bool _isUserDraggingUseCases = false;

  bool _lastIsWeb = false;

  /// ✅ popup selected model
  MarketModel? _activeMarketModel;
  bool _loadingSummary = false;
  String _displayName = '';

  // ------------------------------------------------------------------
  // ✅ DATA: Continue / Stats
  // ------------------------------------------------------------------
  // (1) Continue section (last items)
  Map<String, dynamic> _continueAI = {
    "title": "Neon sci-fi car in rainy alley",
    "subtitle": "Last prompt • 2 hours ago",
    "route": "/aichat",
    "accent": Color(0xFF8A4FFF),
    "icon": Icons.bolt_rounded,
  };

  Map<String, dynamic> _continueScan = {
    "title": "Vintage Chair Scan",
    "subtitle": "Draft scan • 10 minutes ago",
    "route": "/photo_scan",
    "accent": Color(0xFFF72585),
    "icon": Icons.photo_camera_rounded,
  };

  Map<String, dynamic> _continueMarket = {
    "title": "Porsche 911 Asset",
    "subtitle": "Last viewed • yesterday",
    "route": "/explore",
    "accent": Color(0xFF4895EF),
    "icon": Icons.storefront_rounded,
  };

  // (7) Stats mini cards
  Map<String, int> _stats = {
    "Models": 12,
    "Scans": 5,
    "Downloads": 9,
  };

  // ------------------------------------------------------------------
  // Use cases + details
  // ------------------------------------------------------------------
  final List<Map<String, String>> _useCases = const [
    {"id": "film", "title": "Film Production", "asset": "assets/usecases/film.png"},
    {"id": "product", "title": "Product Design", "asset": "assets/usecases/product.png"},
    {"id": "edu", "title": "Education", "asset": "assets/usecases/education.png"},
    {"id": "game", "title": "Game\nDevelopment", "asset": "assets/usecases/game.png"},
    {"id": "print", "title": "3D Printing", "asset": "assets/usecases/printing.png"},
    {"id": "vr", "title": "VR/AR", "asset": "assets/usecases/vr.png"},
    {"id": "interior", "title": "Interior Design", "asset": "assets/usecases/interior.png"},
  ];

  final List<Map<String, dynamic>> _useCaseDetails = const [
    {
      "id": "film",
      "title": "Film Production",
      "subtitle": "Cut costs and accelerate VFX and previs workflows with R2V AI",
      "bullets": ["Fast Previs & Look Dev", "Streamlined VFX Workflow", "Industry-Standard Quality"],
      "cta": "Explore More",
      "ctaRoute": "/explore",
      "preview": "assets/usecase_previews/film.png",
      "accent": Color(0xFF9CA3AF),
    },
    {
      "id": "product",
      "title": "Product Design",
      "subtitle": "Prototype faster with AI-assisted 3D concepts and ready assets.",
      "bullets": ["Rapid Ideation", "Accurate Scale Mockups", "Export-Ready Models"],
      "cta": "Explore More",
      "ctaRoute": "/explore",
      "preview": "assets/usecase_previews/product.png",
      "accent": Color(0xFF38BDF8),
    },
    {
      "id": "edu",
      "title": "Education",
      "subtitle": "Teach 3D concepts interactively with instant models and scans.",
      "bullets": ["Interactive Lessons", "Visual Learning", "Student Projects"],
      "cta": "Explore More",
      "ctaRoute": "/explore",
      "preview": "assets/usecase_previews/education.png",
      "accent": Color(0xFFFDE68A),
    },
    {
      "id": "game",
      "title": "Game Development",
      "subtitle": "Generate and iterate on assets faster for your next game world.",
      "bullets": ["Concept to Asset", "Style Variations", "Faster Iteration"],
      "cta": "Explore More",
      "ctaRoute": "/explore",
      "preview": "assets/usecase_previews/game.png",
      "accent": Color(0xFF22D3EE),
    },
    {
      "id": "print",
      "title": "3D Printing",
      "subtitle": "Scan real objects and convert ideas into printable 3D models.",
      "bullets": ["Scan to STL", "Repair & Optimize", "Print-Ready Output"],
      "cta": "Start Scan",
      "ctaRoute": "/photo_scan",
      "preview": "assets/usecase_previews/printing.png",
      "accent": Color(0xFFA3E635),
    },
    {
      "id": "vr",
      "title": "VR/AR",
      "subtitle": "Build immersive experiences with quick, clean 3D content.",
      "bullets": ["Lightweight Assets", "Realistic Textures", "GLB/FBX Export"],
      "cta": "Explore More",
      "ctaRoute": "/explore",
      "preview": "assets/usecase_previews/vr.png",
      "accent": Color(0xFFC084FC),
    },
    {
      "id": "interior",
      "title": "Interior Design",
      "subtitle": "Create and visualize spaces with furniture and room assets.",
      "bullets": ["Room Mockups", "Asset Library", "Client Presentations"],
      "cta": "Explore More",
      "ctaRoute": "/explore",
      "preview": "assets/usecase_previews/interior.png",
      "accent": Color(0xFFFCA5A5),
    },
  ];

  /// ✅ A single demo model (used if you open popup)
  final List<MarketModel> _models = const [
    MarketModel(
      name: "Porsche 911",
      author: "McLaughlin Rh",
      description: "911 sports car, clean geometry, studio lighting.",
      tags: ["car", "game-ready", "complex", "edges", "symmetric"],
      likes: "1.2k",
      tagLabel: "Saved",
      glbAssetPath: "assets/models/911.glb",
      posterAssetPath: "assets/posters/911.png",
    ),
  ];

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController()..addListener(_onScroll);
    _useCaseScrollController = ScrollController();

    _startUseCaseAutoSwitch();
    _displayName = widget.username;
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _loadingSummary = true);
    try {
      final profile = await r2vProfile.me();
      final dashboard = await r2vDashboard.me();
      final aiJobs = await r2vAiJobs.listJobs(limit: 1);
      final scanJobs = await r2vScanJobs.listJobs(limit: 1);
      final assets = await r2vMarketplace.listAssets(limit: 1);

      if (!mounted) return;

      setState(() {
        _displayName = profile.username.isNotEmpty ? profile.username : _displayName;
        _stats = {
          "Models": dashboard.assets,
          "Scans": dashboard.scanJobs,
          "Downloads": dashboard.downloads,
        };

        if (aiJobs.isNotEmpty) {
          final job = aiJobs.first;
          _continueAI = {
            "title": job.prompt?.isNotEmpty == true ? job.prompt! : "AI job ${job.id}",
            "subtitle": "Status: ${job.status}",
            "route": "/aichat",
            "accent": const Color(0xFF8A4FFF),
            "icon": Icons.bolt_rounded,
          };
        }

        if (scanJobs.isNotEmpty) {
          final job = scanJobs.first;
          _continueScan = {
            "title": "Scan job ${job.id}",
            "subtitle": "Status: ${job.status}",
            "route": "/photo_scan",
            "accent": const Color(0xFFF72585),
            "icon": Icons.photo_camera_rounded,
          };
        }

        if (assets.isNotEmpty) {
          final asset = assets.first;
          _continueMarket = {
            "title": asset.title,
            "subtitle": asset.category,
            "route": "/explore",
            "accent": const Color(0xFF4895EF),
            "icon": Icons.storefront_rounded,
          };
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load dashboard')),
      );
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final dir = _scrollController.position.userScrollDirection;
    if (dir == ScrollDirection.reverse && !_collapsed) {
      setState(() => _collapsed = true);
    } else if (dir == ScrollDirection.forward && _collapsed) {
      setState(() => _collapsed = false);
    }
  }

  void _startUseCaseAutoSwitch() {
    _useCaseAutoTimer?.cancel();
    _useCaseAutoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_pauseUseCaseAutoScroll) return;
      if (_isUserDraggingUseCases) return;

      if (_lastIsWeb) {
        if (_webActiveNavIndex != 0) return;
      } else {
        if (_selectedTab != 0) return;
      }

      setState(() => _selectedUseCase = (_selectedUseCase + 1) % _useCases.length);
    });
  }

  void _onUseCaseTap(int idx) {
    setState(() => _selectedUseCase = idx);
    setState(() => _pauseUseCaseAutoScroll = true);
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() => _pauseUseCaseAutoScroll = false);
    });
  }

  @override
  void dispose() {
    _useCaseAutoTimer?.cancel();
    _scrollController.dispose();
    _useCaseScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width >= 900;
    _lastIsWeb = isWeb;

    return Stack(
      children: [
        const Positioned.fill(child: MeshyParticleBackground()),
        Positioned.fill(child: isWeb ? _buildWebHome(context) : _buildMobileHome(context)),
        if (_activeMarketModel != null)
          Positioned.fill(
            child: _HomeMarketModelPanel(
              model: _activeMarketModel!,
              onClose: () => setState(() => _activeMarketModel = null),
            ),
          ),
      ],
    );
  }

  // =========================
  // WEB
  // =========================
  Widget _buildWebHome(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final double contentWidth = w > 1180 ? 1180 : w;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentWidth),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildWebTopBar(context),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWebHeroSection(context),
                      const SizedBox(height: 18),

                      // ✅ (7) Stats
                      const _SectionHeader(title: "Your stats", subtitle: "Quick overview"),
                      const SizedBox(height: 12),
                      _StatsRow(stats: _stats),
                      const SizedBox(height: 22),

                      // ✅ (1) Continue
                      const _SectionHeader(title: "Continue", subtitle: "Jump back in"),
                      const SizedBox(height: 12),
                      _ContinueRow(
                        items: [_continueAI, _continueScan, _continueMarket],
                        onTap: (item) => Navigator.pushNamed(context, item["route"] as String),
                      ),
                      const SizedBox(height: 28),

                      const _SectionHeader(title: "Use cases", subtitle: "Pick a category"),
                      const SizedBox(height: 12),

                      MouseRegion(
                        onEnter: (_) => setState(() => _pauseUseCaseAutoScroll = true),
                        onExit: (_) => setState(() => _pauseUseCaseAutoScroll = false),
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n is ScrollStartNotification) _isUserDraggingUseCases = true;
                            if (n is ScrollEndNotification) _isUserDraggingUseCases = false;
                            return false;
                          },
                          child: UseCasesRow(
                            items: _useCases,
                            selectedIndex: _selectedUseCase,
                            controller: _useCaseScrollController,
                            onTap: _onUseCaseTap,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, anim) {
                          return SlideTransition(
                            position: Tween<Offset>(begin: const Offset(-0.06, 0), end: Offset.zero).animate(anim),
                            child: FadeTransition(opacity: anim, child: child),
                          );
                        },
                        child: UseCaseDetailsSection(
                          key: ValueKey(_useCaseDetails[_selectedUseCase]["id"]),
                          data: _useCaseDetails[_selectedUseCase],
                          onCta: () => Navigator.pushNamed(
                            context,
                            _useCaseDetails[_selectedUseCase]["ctaRoute"],
                          ),
                        ),
                      ),

                      const SizedBox(height: 26),

                      // ✅ Quick actions
                      const _SectionHeader(title: "Quick actions", subtitle: "Start instantly"),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _HomeActionCard(
                              title: "AI Studio",
                              subtitle: "Text → 3D concepts & variations",
                              icon: Icons.bolt_rounded,
                              accent: const Color(0xFF8A4FFF),
                              onTap: () => Navigator.pushNamed(context, '/aichat'),
                              primaryLabel: "Open",
                              secondaryLabel: "Templates",
                              onSecondaryTap: () => _toast(context, "Templates coming soon"),
                              bullets: const ["Prompt", "Variants", "Export"],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _HomeActionCard(
                              title: "Scan",
                              subtitle: "Photo → 3D model (photogrammetry)",
                              icon: Icons.photo_camera_rounded,
                              accent: const Color(0xFFF72585),
                              onTap: () => Navigator.pushNamed(context, '/photo_scan'),
                              primaryLabel: "Start scan",
                              secondaryLabel: "Tips",
                              onSecondaryTap: () => _openTips(context),
                              bullets: const ["Capture", "Rebuild", "STL/GLB"],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _HomeActionCard(
                              title: "Marketplace",
                              subtitle: "Browse assets & packs",
                              icon: Icons.storefront_rounded,
                              accent: const Color(0xFF4895EF),
                              onTap: () => Navigator.pushNamed(context, '/explore'),
                              primaryLabel: "Browse",
                              secondaryLabel: "Saved",
                              onSecondaryTap: () => Navigator.pushNamed(
                                context,
                                '/profile',
                                arguments: const {'tab': 'saved'},
                              ),
                              bullets: const ["Preview", "Free/Paid", "Creators"],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebTopBar(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 26, color: Color(0xFFBC70FF)),
              const SizedBox(width: 8),
              const Text(
                "R2V Studio",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              SizedBox(width: 380, child: _buildWebNavTabs(context)),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebNavTabs(BuildContext context) {
    final labels = ["Home", "AI Studio", "Marketplace", "Settings"];
    final navCount = labels.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final segmentWidth = totalWidth / navCount;
        const indicatorWidth = 48.0;
        final underlineIndex = (_webHoverNavIndex ?? _webActiveNavIndex).clamp(0, navCount - 1);
        final underlineLeft = underlineIndex * segmentWidth + (segmentWidth - indicatorWidth) / 2;

        return SizedBox(
          height: 34,
          child: Stack(
            children: [
              Row(
                children: List.generate(navCount, (index) {
                  final isActive = _webActiveNavIndex == index;
                  final isHover = _webHoverNavIndex == index;
                  final effectiveActive = isActive || isHover;

                  return MouseRegion(
                    onEnter: (_) => setState(() => _webHoverNavIndex = index),
                    onExit: (_) => setState(() => _webHoverNavIndex = null),
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _webActiveNavIndex = index);
                        switch (index) {
                          case 0:
                            Navigator.pushNamed(context, '/home');
                            break;
                          case 1:
                            Navigator.pushNamed(context, '/aichat');
                            break;
                          case 2:
                            Navigator.pushNamed(context, '/explore');
                            break;
                          case 3:
                            Navigator.pushNamed(context, '/settings');
                            break;
                        }
                      },
                      child: SizedBox(
                        width: segmentWidth,
                        child: Center(
                          child: _NavTextButton(label: labels[index], isActive: effectiveActive),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                left: underlineLeft,
                bottom: 0,
                child: Container(
                  width: indicatorWidth,
                  height: 2,
                  decoration: BoxDecoration(color: const Color(0xFFBC70FF), borderRadius: BorderRadius.circular(999)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWebHeroSection(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.18),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome back, @$_displayName",
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Turn your ideas\ninto 3D in seconds.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Use AI prompts, scan objects, or browse ready-made 3D assets.",
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/aichat'),
                      icon: const Icon(Icons.bolt_rounded),
                      label: const Text("Open AI Studio"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8A4FFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/photo_scan'),
                      icon: const Icon(Icons.photo_camera_rounded),
                      label: const Text("Start Scan"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF72585),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/explore'),
                      icon: const Icon(Icons.storefront_rounded),
                      label: const Text("Marketplace"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.18)),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF282A36).withOpacity(0.85),
                  const Color(0xFF161620).withOpacity(0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: const Text(
              "“A neon-lit sci-fi car parked in a rainy alley, cinematic lighting.”\n\nPrompt → 3D preview in under 60s.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  // =========================
  // MOBILE (tabs pinned at top)
  // =========================
  Widget _buildMobileHome(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final double contentWidth = w > 520 ? 520.0 : w;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(_collapsed ? 58 : 74),
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            right: 14,
          ),
          child: _buildMobileTopPill(context),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, (_collapsed ? 92 : 110), 16, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Tabs always visible (pinned)
                _buildMobileTabs(),
                const SizedBox(height: 14),

                // ✅ Only the content scrolls
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedTab == 0) _buildHomeTabMobile(context),
                        if (_selectedTab == 1) _buildAiTabMobile(context),
                        if (_selectedTab == 2) _buildScanTabMobile(context),
                        if (_selectedTab == 3) _buildMarketTabMobile(context),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileTopPill(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: _collapsed ? 10 : 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: const Color(0xFFBC70FF), size: _collapsed ? 20 : 24),
              const SizedBox(width: 8),
              Text(
                "R2V Studio",
                style: TextStyle(color: Colors.white, fontSize: _collapsed ? 16 : 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: Container(
                  width: _collapsed ? 34 : 38,
                  height: _collapsed ? 34 : 38,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileTabs() {
    final labels = ["Home", "AI", "Scan", "Market"];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final bool selected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: selected
                      ? const LinearGradient(
                          colors: [Color(0xFFF72585), Color(0xFFBC70FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                ),
                child: Center(
                  child: Text(
                    labels[index],
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white.withOpacity(0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // -------------------------
  // Mobile: Home tab content
  // -------------------------
  Widget _buildHomeTabMobile(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMobileHeroStack(context),
        const SizedBox(height: 16),

        // ✅ (7) Stats
        const _SectionHeader(title: "Your stats", subtitle: "Quick overview"),
        const SizedBox(height: 12),
        _StatsRow(stats: _stats),
        const SizedBox(height: 18),

        // ✅ (1) Continue
        const _SectionHeader(title: "Continue", subtitle: "Jump back in"),
        const SizedBox(height: 12),
        _ContinueRow(
          items: [_continueAI, _continueScan, _continueMarket],
          onTap: (item) => Navigator.pushNamed(context, item["route"] as String),
          forceVerticalOnMobile: true,
        ),
        const SizedBox(height: 22),

        const _SectionHeader(title: "Use Cases", subtitle: "Pick a category"),
        const SizedBox(height: 12),
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollStartNotification) _isUserDraggingUseCases = true;
            if (n is ScrollEndNotification) _isUserDraggingUseCases = false;
            return false;
          },
          child: UseCasesRow(
            items: _useCases,
            selectedIndex: _selectedUseCase,
            controller: _useCaseScrollController,
            onTap: _onUseCaseTap,
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) {
            return SlideTransition(
              position: Tween<Offset>(begin: const Offset(-0.06, 0), end: Offset.zero).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            );
          },
          child: UseCaseDetailsSectionMobile(
            key: ValueKey(_useCaseDetails[_selectedUseCase]["id"]),
            data: _useCaseDetails[_selectedUseCase],
            onCta: () => Navigator.pushNamed(context, _useCaseDetails[_selectedUseCase]["ctaRoute"]),
          ),
        ),
        const SizedBox(height: 22),

        // ✅ Quick actions
        const _SectionHeader(title: "Quick actions", subtitle: "Start instantly"),
        const SizedBox(height: 12),

        _HomeActionCard(
          title: "AI Studio",
          subtitle: "Text → 3D concepts & variations",
          icon: Icons.bolt_rounded,
          accent: const Color(0xFF8A4FFF),
          onTap: () => Navigator.pushNamed(context, '/aichat'),
          primaryLabel: "Open",
          secondaryLabel: "Templates",
          onSecondaryTap: () => _toast(context, "Templates coming soon"),
          bullets: const ["Prompt", "Variants", "Export"],
        ),
        const SizedBox(height: 12),
        _HomeActionCard(
          title: "Scan",
          subtitle: "Photo → 3D model (photogrammetry)",
          icon: Icons.photo_camera_rounded,
          accent: const Color(0xFFF72585),
          onTap: () => Navigator.pushNamed(context, '/photo_scan'),
          primaryLabel: "Start scan",
          secondaryLabel: "Tips",
          onSecondaryTap: () => _openTips(context),
          bullets: const ["Capture", "Rebuild", "STL/GLB"],
        ),
        const SizedBox(height: 12),
        _HomeActionCard(
          title: "Marketplace",
          subtitle: "Browse assets & packs",
          icon: Icons.storefront_rounded,
          accent: const Color(0xFF4895EF),
          onTap: () => Navigator.pushNamed(context, '/explore'),
          primaryLabel: "Browse",
          secondaryLabel: "Saved",
          onSecondaryTap: () => setState(() => _activeMarketModel = _models.first),
          bullets: const ["Preview", "Free/Paid", "Creators"],
        ),
      ],
    );
  }

  Widget _buildMobileHeroStack(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome back, @$_displayName",
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                "Turn your ideas\ninto 3D in seconds.",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Use AI prompts, scan objects, or browse ready-made 3D assets.",
                style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/aichat'),
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: const Text("AI Studio"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8A4FFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/photo_scan'),
                      icon: const Icon(Icons.photo_camera_rounded, size: 18),
                      label: const Text("Scan"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF72585),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/explore'),
                  icon: const Icon(Icons.storefront_rounded, size: 18),
                  label: const Text("Marketplace"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.18)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF282A36).withOpacity(0.85),
                const Color(0xFF161620).withOpacity(0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          child: const Text(
            "“A neon-lit sci-fi car parked in a rainy alley, cinematic lighting.”\n\nPrompt → 3D preview in under 60s.",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // -------------------------
  // Mobile: AI tab
  // -------------------------
  Widget _buildAiTabMobile(BuildContext context) {
    return _HomeActionCard(
      title: "AI Studio",
      subtitle: "Text → 3D concepts & variations",
      icon: Icons.bolt_rounded,
      accent: const Color(0xFF8A4FFF),
      onTap: () => Navigator.pushNamed(context, '/aichat'),
      primaryLabel: "Open AI Studio",
      secondaryLabel: "Templates",
      onSecondaryTap: () => _toast(context, "Templates coming soon"),
      bullets: const ["Prompt", "Variants", "Export"],
    );
  }

  // -------------------------
  // Mobile: Scan tab
  // -------------------------
  Widget _buildScanTabMobile(BuildContext context) {
    return _HomeActionCard(
      title: "Scan",
      subtitle: "Photo → 3D model (photogrammetry)",
      icon: Icons.photo_camera_rounded,
      accent: const Color(0xFFF72585),
      onTap: () => Navigator.pushNamed(context, '/photo_scan'),
      primaryLabel: "Start Scan",
      secondaryLabel: "Tips",
      onSecondaryTap: () => _openTips(context),
      bullets: const ["Capture", "Rebuild", "STL/GLB"],
    );
  }

  // -------------------------
  // Mobile: Market tab
  // -------------------------
  Widget _buildMarketTabMobile(BuildContext context) {
    return _HomeActionCard(
      title: "Marketplace",
      subtitle: "Browse assets & packs",
      icon: Icons.storefront_rounded,
      accent: const Color(0xFF4895EF),
      onTap: () => Navigator.pushNamed(context, '/explore'),
      primaryLabel: "Open Marketplace",
      secondaryLabel: "Saved",
      onSecondaryTap: () => setState(() => _activeMarketModel = _models.first),
      bullets: const ["Preview", "Free/Paid", "Creators"],
    );
  }

  // -------------------------
  // Helpers
  // -------------------------
  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _openTips(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.all(12),
        child: _TipsSheet(),
      ),
    );
  }
}

// =========================
// ✅ Particle Mesh Background
// =========================
class MeshyParticleBackground extends StatelessWidget {
  const MeshyParticleBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MeshyBgCore();
  }
}

class _MeshyBgCore extends StatefulWidget {
  const _MeshyBgCore();

  @override
  State<_MeshyBgCore> createState() => _MeshyBgCoreState();
}

class _MeshyBgCoreState extends State<_MeshyBgCore> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final Random _rng = Random(42);

  Size _size = Size.zero;
  Offset _mouse = Offset.zero;
  bool _hasMouse = false;

  late List<_Particle> _ps;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ps = <_Particle>[];
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
      return _Particle(pos: pos, vel: vel, radius: r);
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
          painter: _MeshPainter(
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

class _Particle {
  Offset pos;
  Offset vel;
  final double radius;

  _Particle({required this.pos, required this.vel, required this.radius});
}

class _MeshPainter extends CustomPainter {
  final List<_Particle> particles;
  final double time;
  final Size size;
  final Offset mouse;
  final bool hasMouse;

  _MeshPainter({
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
  bool shouldRepaint(covariant _MeshPainter oldDelegate) => true;
}

// =========================
// SECTION HEADER
// =========================
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13)),
      ],
    );
  }
}

// =========================
// ✅ (7) Stats row
// =========================
class _StatsRow extends StatelessWidget {
  final Map<String, int> stats;

  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final isWeb = c.maxWidth >= 900;
      final items = stats.entries.toList();

      return Row(
        children: items.map((e) {
          final idx = items.indexOf(e);
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: idx == items.length - 1 ? 0 : (isWeb ? 14 : 10)),
              child: _MiniStatCard(label: e.key, value: e.value),
            ),
          );
        }).toList(),
      );
    });
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final int value;

  const _MiniStatCard({required this.label, required this.value});

  Color _accentFor(String label) {
    switch (label.toLowerCase()) {
      case "models":
        return const Color(0xFF8A4FFF);
      case "scans":
        return const Color(0xFFF72585);
      case "downloads":
        return const Color(0xFF4895EF);
      default:
        return const Color(0xFFBC70FF);
    }
  }

  IconData _iconFor(String label) {
    switch (label.toLowerCase()) {
      case "models":
        return Icons.view_in_ar_rounded;
      case "scans":
        return Icons.photo_camera_rounded;
      case "downloads":
        return Icons.download_rounded;
      default:
        return Icons.insights_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(label);
    final icon = _iconFor(label);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withOpacity(0.55)),
                ),
                child: Icon(icon, color: Colors.white.withOpacity(0.95), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Always one line even if long
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$value",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================
// ✅ (1) Continue row
// =========================
class _ContinueRow extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> item) onTap;
  final bool forceVerticalOnMobile;

  const _ContinueRow({
    required this.items,
    required this.onTap,
    this.forceVerticalOnMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isNarrow = w < 520;

    if (forceVerticalOnMobile && isNarrow) {
      return Column(
        children: items
            .map((it) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ContinueCard(item: it, onTap: () => onTap(it)),
                ))
            .toList(),
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final isWeb = c.maxWidth >= 900;

      if (isWeb) {
        return Row(
          children: items.map((it) {
            final idx = items.indexOf(it);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: idx == items.length - 1 ? 0 : 14),
                child: _ContinueCard(item: it, onTap: () => onTap(it)),
              ),
            );
          }).toList(),
        );
      }

      return SizedBox(
        height: 100,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            return SizedBox(
              width: 290,
              child: _ContinueCard(item: items[i], onTap: () => onTap(items[i])),
            );
          },
        ),
      );
    });
  }
}

class _ContinueCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _ContinueCard({required this.item, required this.onTap});

  @override
  State<_ContinueCard> createState() => _ContinueCardState();
}

class _ContinueCardState extends State<_ContinueCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 900;
    final Color accent = widget.item["accent"] as Color;
    final IconData icon = widget.item["icon"] as IconData;
    final String title = widget.item["title"] as String;
    final String subtitle = widget.item["subtitle"] as String;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..translate(0.0, (_hover && isWeb) ? -5.0 : 0.0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _hover ? Colors.white.withOpacity(0.20) : Colors.white.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                blurRadius: _hover ? 24 : 18,
                color: Colors.black.withOpacity(_hover ? 0.45 : 0.30),
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withOpacity(0.55)),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================
// ✅ Use Cases Row
// =========================
class UseCasesRow extends StatelessWidget {
  final List<Map<String, String>> items;
  final int selectedIndex;
  final ScrollController controller;
  final void Function(int index) onTap;

  const UseCasesRow({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth >= 900;
        final cardWidth = isWide ? 190.0 : 170.0;
        final spacing = isWide ? 16.0 : 12.0;
        final side = isWide ? 30.0 : 10.0;

        return SizedBox(
          height: isWide ? 178 : 165,
          child: ListView.separated(
            controller: controller,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: side),
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(width: spacing),
            itemBuilder: (context, i) {
              final m = items[i];
              final title = m["title"] ?? "";
              final asset = m["asset"];
              final active = i == selectedIndex;

              return _UseCaseTile(
                title: title,
                asset: asset,
                isActive: active,
                width: cardWidth,
                onTap: () => onTap(i),
              );
            },
          ),
        );
      },
    );
  }
}

class _UseCaseTile extends StatefulWidget {
  final String title;
  final String? asset;
  final bool isActive;
  final double width;
  final VoidCallback onTap;

  const _UseCaseTile({
    required this.title,
    required this.asset,
    required this.isActive,
    required this.width,
    required this.onTap,
  });

  @override
  State<_UseCaseTile> createState() => _UseCaseTileState();
}

class _UseCaseTileState extends State<_UseCaseTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final baseColors = _gradientFor(widget.title);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: widget.width,
          padding: const EdgeInsets.only(top: 8),
          transform: Matrix4.identity()..translate(0.0, (_hover || widget.isActive) ? -5.0 : 0.0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      height: 105,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: baseColors),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: widget.isActive ? Colors.white.withOpacity(0.28) : Colors.white.withOpacity(0.12),
                          width: widget.isActive ? 1.4 : 1,
                        ),
                        boxShadow: [
                          if (widget.isActive)
                            BoxShadow(
                              blurRadius: 28,
                              color: Colors.white.withOpacity(0.10),
                              offset: const Offset(0, 10),
                            ),
                          BoxShadow(
                            blurRadius: 18,
                            color: Colors.black.withOpacity((_hover || widget.isActive) ? 0.40 : 0.25),
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: widget.isActive ? Colors.white : Colors.white.withOpacity(0.92),
                              fontWeight: FontWeight.w800,
                              fontSize: 16.5,
                              height: 1.1,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 72,
                child: SizedBox(
                  height: 92,
                  child: (widget.asset == null)
                      ? const Icon(Icons.category, color: Colors.white70, size: 54)
                      : Image.asset(
                          widget.asset!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.category, color: Colors.white70, size: 54),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _gradientFor(String title) {
    final t = title.replaceAll('\n', ' ').toLowerCase();
    switch (t) {
      case 'film production':
        return [const Color(0xFF9CA3AF).withOpacity(.62), const Color(0xFF111827).withOpacity(.28)];
      case 'product design':
        return [const Color(0xFF38BDF8).withOpacity(.78), const Color(0xFF2563EB).withOpacity(.34)];
      case 'education':
        return [const Color(0xFFFDE68A).withOpacity(.70), const Color(0xFFB45309).withOpacity(.28)];
      case 'game development':
        return [const Color(0xFF22D3EE).withOpacity(.74), const Color(0xFF0EA5E9).withOpacity(.30)];
      case '3d printing':
        return [const Color(0xFFA3E635).withOpacity(.70), const Color(0xFF16A34A).withOpacity(.28)];
      case 'vr/ar':
        return [const Color(0xFFC084FC).withOpacity(.72), const Color(0xFFFB7185).withOpacity(.28)];
      case 'interior design':
        return [const Color(0xFFFCA5A5).withOpacity(.68), const Color(0xFFF59E0B).withOpacity(.24)];
      default:
        return [Colors.white.withOpacity(.18), Colors.white.withOpacity(.06)];
    }
  }
}

// =========================
// Use Case Details (WEB)
// =========================
class UseCaseDetailsSection extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onCta;

  const UseCaseDetailsSection({
    super.key,
    required this.data,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = (data["accent"] as Color?) ?? const Color(0xFFBC70FF);
    final bullets = (data["bullets"] as List?)?.cast<String>() ?? const <String>[];

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data["title"] ?? "",
                  style: const TextStyle(color: Colors.white, fontSize: 44, height: 1.05, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                Text(
                  data["subtitle"] ?? "",
                  style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 22),
                for (final b in bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.20),
                            shape: BoxShape.circle,
                            border: Border.all(color: accent.withOpacity(0.60), width: 1),
                          ),
                          child: Icon(Icons.check, size: 14, color: accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            b,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: onCta,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(data["cta"] ?? "Explore More"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent.withOpacity(0.18),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    side: BorderSide(color: accent.withOpacity(0.55), width: 1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 360,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        data["preview"] ?? "",
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Center(child: Icon(Icons.image_outlined, color: Colors.white.withOpacity(0.5), size: 48)),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                            colors: [Colors.black.withOpacity(0.30), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================
// Use Case Details (MOBILE)
// =========================
class UseCaseDetailsSectionMobile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onCta;

  const UseCaseDetailsSectionMobile({
    super.key,
    required this.data,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = (data["accent"] as Color?) ?? const Color(0xFFBC70FF);
    final bullets = (data["bullets"] as List?)?.cast<String>() ?? const <String>[];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.20),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data["title"] ?? "",
            style: const TextStyle(color: Colors.white, fontSize: 26, height: 1.1, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            data["subtitle"] ?? "",
            style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          for (final b in bullets.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withOpacity(0.55), width: 1),
                    ),
                    child: Icon(Icons.check, size: 12, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      data["preview"] ?? "",
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Center(child: Icon(Icons.image_outlined, color: Colors.white.withOpacity(0.5), size: 42)),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                          colors: [Colors.black.withOpacity(0.28), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onCta,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(data["cta"] ?? "Explore More"),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent.withOpacity(0.18),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              side: BorderSide(color: accent.withOpacity(0.55), width: 1),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================
// Small UI pieces
// =========================
class _NavTextButton extends StatelessWidget {
  final String label;
  final bool isActive;

  const _NavTextButton({required this.label, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 120),
      style: TextStyle(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.7),
        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
        fontSize: 13.5,
      ),
      child: Text(label),
    );
  }
}

// =========================
// ✅ Home Action Card (glass + popout)
// =========================
class _HomeActionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback? onSecondaryTap;

  final List<String> bullets;

  const _HomeActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onSecondaryTap,
    required this.bullets,
  });

  @override
  State<_HomeActionCard> createState() => _HomeActionCardState();
}

class _HomeActionCardState extends State<_HomeActionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 900;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..translate(0.0, (_hover && isWeb) ? -6.0 : 0.0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.22),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _hover ? Colors.white.withOpacity(0.22) : Colors.white.withOpacity(0.12),
              width: _hover ? 1.3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: _hover ? 28 : 18,
                color: Colors.black.withOpacity(_hover ? 0.45 : 0.30),
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.accent.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.accent.withOpacity(0.55), width: 1),
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withOpacity(0.72), height: 1.25),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.bullets
                    .map((b) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white.withOpacity(0.10)),
                          ),
                          child: Text(
                            b,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.88),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accent.withOpacity(0.22),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: widget.accent.withOpacity(0.55), width: 1),
                      ),
                      child: Text(widget.primaryLabel, style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onSecondaryTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.18)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(widget.secondaryLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipsSheet extends StatelessWidget {
  const _TipsSheet();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Scan Tips", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 10),
              _tip("Use bright, even lighting (no harsh shadows)."),
              _tip("Capture 20–40 photos from all angles."),
              _tip("Keep the object centered, move around it."),
              _tip("Avoid reflective/transparent objects if possible."),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF72585).withOpacity(0.22),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: const Color(0xFFF72585).withOpacity(0.55), width: 1),
                  ),
                  child: const Text("Got it", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.85), height: 1.25))),
        ],
      ),
    );
  }
}

// =====================================================================
// ✅ Popup panel (kept same as before)
// =====================================================================
class _HomeMarketModelPanel extends StatelessWidget {
  final MarketModel model;
  final VoidCallback onClose;

  const _HomeMarketModelPanel({required this.model, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width >= 900;

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withOpacity(0.60),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWeb ? 1100 : size.width - 18,
                maxHeight: isWeb ? 680 : size.height * 0.86,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                model.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ),
                            InkWell(
                              onTap: onClose,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.10),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                                ),
                                child: const Icon(Icons.close, size: 18, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              color: Colors.black.withOpacity(0.18),
                              child: ModelViewer(
                                key: ValueKey(model.glbAssetPath),
                                src: model.glbAssetPath,
                                poster: model.posterAssetPath,
                                backgroundColor: Colors.transparent,
                                cameraControls: true,
                                autoRotate: true,
                                environmentImage: "neutral",
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
