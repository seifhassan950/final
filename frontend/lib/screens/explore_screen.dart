import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../api/r2v_api.dart';
import '../api/api_exception.dart';
import '../api/marketplace_service.dart';
import '../utils/web_model_viewer_capture.dart';
import '../utils/web_model_viewer_capture.dart';

// ============================================================
// ✅ Explore Screen (WEB: Centered 3-col grid + RIGHT details panel)
// - Default: centered 3 columns
// - Click card: opens right panel (AssetDetailsPanel)
// - Close panel: back to centered grid
// ============================================================

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  int _webActiveNavIndex = 2;
  int? _webHoverNavIndex;

  String selectedCategory = "All";
  MarketplaceAsset? _selectedAsset;
  List<MarketplaceAsset> _assets = [];
  bool _loadingAssets = false;
  String? _assetsError;
  String _searchQuery = "";

  static const double _creatorCardMinWidth = 220;

  final List<String> _categories = const [
    "All",
    "Characters",
    "Objects",
    "Vehicles",
    "Environments",
    "Stylized",
    "Realistic",
  ];

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() {
      _loadingAssets = true;
      _assetsError = null;
    });
    try {
      final data = await r2vMarketplace.listAssets(limit: 60);
      if (!mounted) return;
      setState(() {
        _assets = data;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _assetsError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _assetsError = 'Failed to load marketplace');
    } finally {
      if (mounted) setState(() => _loadingAssets = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width >= 900;

    return Stack(
      children: [
        const Positioned.fill(child: NebulaMeshBackground()),
        Positioned.fill(
          child: isWeb ? _buildWebMarketplace(context) : _buildMobileMarketplace(context),
        ),
      ],
    );
  }

  // =====================================================================
  // 🖥 WEB (Centered content + right details when selected)
  // =====================================================================

  Widget _buildWebMarketplace(BuildContext context) {
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
              _buildHomeStyleTopBar(context),
              const SizedBox(height: 18),

              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT: marketplace content (always centered)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMarketHeaderWithCgi(context),
                            const SizedBox(height: 18),
                            _buildSearchBar(),
                            if (_searchQuery.trim().isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _buildCreatorResults(isCompact: false),
                            ],
                            const SizedBox(height: 16),
                            _buildWebCategoryChips(),
                            const SizedBox(height: 22),
                            const Text(
                              "Trending Today",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // ✅ Centered 3 columns
                            _buildCenteredGrid3Cols(context),
                          ],
                        ),
                      ),
                    ),

                    // RIGHT: details panel only when selected
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _selectedAsset == null
                          ? const SizedBox.shrink()
                          : Padding(
                              key: const ValueKey("rightPanel"),
                              padding: const EdgeInsets.only(top: 22, right: 16, bottom: 32),
                              child: SizedBox(
                                width: 360,
                                child: AssetDetailsPanel(
                                  asset: _selectedAsset!,
                                  onClose: () => setState(() => _selectedAsset = null),
                                  onFreeDownload: (asset, format) => _startDownload(context, asset, format: format),
                                  onPaidBuy: (asset) => Navigator.pushNamed(
                                    context,
                                    '/payment',
                                    arguments: asset,
                                  ),
                                ),
                              ),
                            ),
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

  Widget _buildCenteredGrid3Cols(BuildContext context) {
    final items = _filteredAssets();
    const gap = 14.0;

    return LayoutBuilder(
      builder: (context, c) {
        final available = c.maxWidth;

        // ✅ Always 3 columns on web
        const cols = 3;

        final cardW = (available - (gap * (cols - 1))) / cols;

        if (_loadingAssets) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (_assetsError != null) {
          return Center(
            child: Column(
              children: [
                Text(
                  _assetsError!,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _loadAssets,
                  child: const Text("Retry", style: TextStyle(color: Color(0xFF4CC9F0))),
                ),
              ],
            ),
          );
        }

        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text("No assets yet", style: TextStyle(color: Colors.white70)),
            ),
          );
        }

        return Center(
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: items.map((item) {
              return SizedBox(
                width: cardW,
                child: AssetCard(
                  name: item.title,
                  author: item.author,
                  creatorId: item.creatorId,
                  likes: item.likes,
                  tag: item.category,
                  styleTag: item.style,
                  posterUrl: item.thumbUrl,
                  priceText: priceLabelEGP(item),
                  width: cardW,
                  onTap: () => setState(() => _selectedAsset = item),
                  onAuthorTap: () => Navigator.pushNamed(
                    context,
                    '/profile',
                    arguments: {'userId': item.creatorId, 'username': item.author},
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // =====================================================================
  // 📱 MOBILE
  // =====================================================================

  Widget _buildMobileMarketplace(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Marketplace", style: TextStyle(fontWeight: FontWeight.w600,color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            if (_searchQuery.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildCreatorResults(isCompact: true),
            ],
            const SizedBox(height: 14),
            _buildMobileCategoryChips(),
            const SizedBox(height: 18),
            const Text(
              "Trending Today",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (_loadingAssets)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            else if (_assetsError != null)
              Center(
                child: Column(
                  children: [
                    Text(_assetsError!, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _loadAssets,
                      child: const Text("Retry", style: TextStyle(color: Color(0xFF4CC9F0))),
                    ),
                  ],
                ),
              )
            else if (_filteredAssets().isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text("No assets yet", style: TextStyle(color: Colors.white70)),
                ),
              )
            else
              Column(
                children: _filteredAssets().map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AssetCard(
                      name: item.title,
                      author: item.author,
                      creatorId: item.creatorId,
                      likes: item.likes,
                      tag: item.category,
                      styleTag: item.style,
                      posterUrl: item.thumbUrl,
                      priceText: priceLabelEGP(item),
                      width: double.infinity,
                      onTap: () => _openMobileDetails(item),
                      onAuthorTap: () => Navigator.pushNamed(
                        context,
                        '/profile',
                        arguments: {'userId': item.creatorId, 'username': item.author},
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  void _openMobileDetails(MarketplaceAsset item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: AssetDetailsPanel(
            asset: item,
            onClose: () => Navigator.pop(context),
            onFreeDownload: (asset, format) => _startDownload(context, asset, format: format),
            onPaidBuy: (asset) => Navigator.pushNamed(
              context,
              '/payment',
              arguments: asset,
            ),
          ),
        ),
      ),
    );
  }

  // =====================================================================
  // UI helpers
  // =====================================================================

  Widget _buildHomeStyleTopBar(BuildContext context) {
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
              SizedBox(width: 380, child: _buildHomeStyleNavTabs(context)),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeStyleNavTabs(BuildContext context) {
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
                            break;
                          case 3:
                            Navigator.pushNamed(context, '/settings');
                            break;
                        }
                      },
                      child: SizedBox(
                        width: segmentWidth,
                        child: Center(
                          child: NavTextButton(label: labels[index], isActive: effectiveActive),
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
                  decoration: BoxDecoration(
                    color: const Color(0xFFBC70FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMarketHeaderWithCgi(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.20),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Marketplace",
                      style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openUploadDialog(context),
                    icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: const Text("Upload"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8A4FFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Browse trending 3D assets and CGI-ready packs. Mix, match, and export fast.",
                style: TextStyle(color: Colors.white70, height: 1.35, fontSize: 14.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebCategoryChips() {
    return Row(
      children: _categories.map((c) {
        final active = c == selectedCategory;
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () => setState(() => selectedCategory = c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: active ? const LinearGradient(colors: [Color(0xFF8A4FFF), Color(0xFFBC70FF)]) : null,
                color: active ? null : Colors.white.withOpacity(0.08),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Text(
                c,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobileCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _categories.map((c) {
          final active = c == selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => selectedCategory = c),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: active ? const LinearGradient(colors: [Color(0xFF8A4FFF), Color(0xFFBC70FF)]) : null,
                  color: active ? null : Colors.white.withOpacity(0.08),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "Search objects or creators...",
                hintStyle: TextStyle(color: Colors.white54),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ],
      ),
    );
  }

  List<MarketplaceAsset> _filteredAssets() {
    final query = _searchQuery.trim().toLowerCase();
    Iterable<MarketplaceAsset> results = _assets;
    if (selectedCategory != "All") {
      results = results.where((a) => a.category == selectedCategory || a.style == selectedCategory);
    }
    if (query.isNotEmpty) {
      results = results.where((a) =>
          a.title.toLowerCase().contains(query) ||
          a.author.toLowerCase().contains(query) ||
          a.tags.any((t) => t.toLowerCase().contains(query)));
    }
    return results.toList();
  }

  List<_CreatorResult> _filteredCreators() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return [];
    }

    final Map<String, _CreatorResult> results = {};
    for (final asset in _assets) {
      if (asset.creatorId.isEmpty) continue;
      final author = asset.author.trim();
      if (author.isEmpty) continue;
      final existing = results[asset.creatorId];
      if (existing == null) {
        results[asset.creatorId] = _CreatorResult(
          id: asset.creatorId,
          name: author,
          assetCount: 1,
        );
      } else {
        results[asset.creatorId] = existing.copyWith(assetCount: existing.assetCount + 1);
      }
    }

    return results.values
        .where((creator) => creator.name.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => b.assetCount.compareTo(a.assetCount));
  }

  Widget _buildCreatorResults({required bool isCompact}) {
    final creators = _filteredCreators();
    if (creators.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Creators",
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final available = constraints.maxWidth;
            final maxPerRow = isCompact ? 1 : max(1, (available / _creatorCardMinWidth).floor());
            final cardWidth = isCompact
                ? available
                : min(_creatorCardMinWidth, (available - 12 * (maxPerRow - 1)) / maxPerRow);
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: creators
                  .map(
                    (creator) => _CreatorResultCard(
                      creator: creator,
                      width: cardWidth,
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/profile',
                        arguments: {'userId': creator.id, 'username': creator.name},
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // ✅ FREE + EGP price formatting
  // ============================================================

  static bool isFree(MarketplaceAsset asset) {
    return !asset.isPaid || asset.price <= 0;
  }

  static String priceLabelEGP(MarketplaceAsset asset) {
    final p = asset.price;
    if (p <= 0) return "FREE";
    return "EGP $p";
  }

  Future<void> _startDownload(BuildContext context, MarketplaceAsset asset, {String? format}) async {
    try {
      final url = await r2vMarketplace.downloadAsset(asset.id, format: format);
      if (url.isEmpty) {
        throw Exception('Missing download url');
      }
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start download')),
      );
    }
  }

  Future<void> _openUploadDialog(BuildContext context) async {
    final didUpload = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (_) => const _MarketplaceUploadDialog(),
    );
    if (didUpload == true && mounted) {
      _loadAssets();
    }
  }
}

class _MarketplaceUploadDialog extends StatefulWidget {
  const _MarketplaceUploadDialog();

  @override
  State<_MarketplaceUploadDialog> createState() => _MarketplaceUploadDialogState();
}

class _MarketplaceUploadDialogState extends State<_MarketplaceUploadDialog> {
  final GlobalKey _viewerKey = GlobalKey();
  final String _viewerDomId = 'marketplace-model-viewer';
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  Uint8List? _modelBytes;
  String? _modelName;
  String? _modelDataUrl;
  Uint8List? _thumbnailBytes;
  String? _thumbnailName;
  bool _thumbnailCaptured = false;
  bool _isUploading = false;

  String _category = "Objects";
  String _style = "Realistic";

  bool get _canCaptureThumbnail {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['glb', 'gltf', 'obj'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    final ext = (file.extension ?? '').toLowerCase();
    final mime = _modelMimeType(ext);
    setState(() {
      _modelBytes = file.bytes;
      _modelName = file.name;
      _modelDataUrl = Uri.dataFromBytes(file.bytes!, mimeType: mime).toString();
      _thumbnailCaptured = false;
    });
  }

  Future<void> _pickThumbnail() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() {
      _thumbnailBytes = file.bytes;
      _thumbnailName = file.name;
      _thumbnailCaptured = true;
    });
  }

  Future<void> _captureThumbnail() async {
    if (!_canCaptureThumbnail) {
      _showSnack('Capture isn\'t supported on this platform. Please upload a thumbnail image.');
      return;
    }
    if (_modelDataUrl == null) {
      _showSnack('Upload a 3D model first.');
      return;
    }
    if (kIsWeb) {
      final bytes = await captureModelViewerPng(_viewerDomId);
      if (bytes == null) {
        _showSnack('Unable to capture thumbnail.');
        return;
      }
      setState(() {
        _thumbnailBytes = bytes;
        _thumbnailName = 'viewer-thumbnail.png';
        _thumbnailCaptured = true;
      });
      _showSnack('Thumbnail captured from viewer.');
      return;
    }
    final boundary = _viewerKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      _showSnack('Preview not ready for capture.');
      return;
    }
    try {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ImageByteFormat.png);
      if (data == null) {
        _showSnack('Unable to capture thumbnail.');
        return;
      }
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      setState(() {
        _thumbnailBytes = bytes;
        _thumbnailName = 'viewer-thumbnail.png';
        _thumbnailCaptured = true;
      });
      _showSnack('Thumbnail captured from viewer.');
    } catch (_) {
      _showSnack('Thumbnail capture isn’t supported on this platform.');
    }
  }

  String _modelMimeType(String ext) {
    switch (ext) {
      case 'gltf':
        return 'model/gltf+json';
      case 'obj':
        return 'model/obj';
      case 'glb':
      default:
        return 'model/gltf-binary';
    }
  }

  String _thumbnailMimeType(String? name) {
    final lower = (name ?? '').toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submitUpload() async {
    if (_isUploading) return;
    if (_titleController.text.trim().isEmpty) {
      _showSnack('Add a title for your asset.');
      return;
    }
    if (_modelDataUrl == null || _modelBytes == null) {
      _showSnack('Upload a 3D model to continue.');
      return;
    }
    if (_thumbnailBytes == null) {
      _showSnack('Choose a thumbnail or capture one from the viewer.');
      return;
    }
    final priceInput = _priceController.text.trim();
    final parsedPrice = priceInput.isEmpty ? 0 : int.tryParse(priceInput);
    if (parsedPrice == null || parsedPrice < 0) {
      _showSnack('Enter a valid price.');
      return;
    }

    setState(() => _isUploading = true);
    try {
      final modelName = _modelName ?? 'model.glb';
      final modelExt = modelName.split('.').last.toLowerCase();
      final modelFormat = '.${modelExt.isEmpty ? 'glb' : modelExt}';
      final modelMime = _modelMimeType(modelExt);
      final modelPresign = await r2vMarketplace.presignAssetUpload(
        filename: modelName,
        contentType: modelMime,
        kind: 'model',
      );
      if (modelPresign['url']!.isEmpty || modelPresign['key']!.isEmpty) {
        throw Exception('Missing upload url');
      }
      await r2vMarketplace.uploadToPresignedUrl(
        modelPresign['url']!,
        _modelBytes!,
      );

      final thumbName = _thumbnailName ?? 'thumbnail.png';
      final thumbMime = _thumbnailMimeType(thumbName);
      final thumbPresign = await r2vMarketplace.presignAssetUpload(
        filename: thumbName,
        contentType: thumbMime,
        kind: 'thumb',
      );
      if (thumbPresign['url']!.isEmpty || thumbPresign['key']!.isEmpty) {
        throw Exception('Missing thumbnail upload url');
      }
      await r2vMarketplace.uploadToPresignedUrl(
        thumbPresign['url']!,
        _thumbnailBytes!,
        contentType: thumbMime,
      );

      final asset = await r2vMarketplace.createAsset(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        tags: const [],
        category: _category,
        style: _style,
        isPaid: parsedPrice > 0,
        price: parsedPrice,
        currency: 'egp',
        modelObjectKey: modelPresign['key']!,
        thumbObjectKey: thumbPresign['key']!,
        previewObjectKeys: [modelPresign['key']!],
        metadata: {
          'formats': [modelFormat],
          'format_keys': {modelFormat: modelPresign['key']!},
        },
      );
      await r2vMarketplace.publishAsset(asset.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      _showSnack('Asset uploaded to marketplace.');
    } on ApiException catch (e) {
      _showSnack(e.message);
    } on Exception catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      _showSnack(message.isEmpty ? 'Unable to upload asset' : message);
    } catch (_) {
      _showSnack('Unable to upload asset');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 640,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Upload to Marketplace",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 34,
                        height: 34,
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
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _titleController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration("Asset title"),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration("Price (EGP)"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _dropdownField(
                                label: "Category",
                                value: _category,
                                options: const [
                                  "Characters",
                                  "Objects",
                                  "Vehicles",
                                  "Environments",
                                  "Stylized",
                                  "Realistic",
                                ],
                                onChanged: (value) => setState(() => _category = value ?? _category),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _dropdownField(
                          label: "Style",
                          value: _style,
                          options: const ["Realistic", "Stylized", "CGI", "Low Poly"],
                          onChanged: (value) => setState(() => _style = value ?? _style),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _descriptionController,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 3,
                          decoration: _inputDecoration("Description"),
                        ),
                        const SizedBox(height: 14),
                        _sectionTitle("Model Upload"),
                        const SizedBox(height: 8),
                        _uploadRow(
                          label: _modelName ?? "Upload a 3D model (.glb, .gltf, .obj)",
                          onPressed: _pickModel,
                        ),
                        const SizedBox(height: 14),
                        _sectionTitle("Thumbnail"),
                        const SizedBox(height: 8),
                        Text(
                          _canCaptureThumbnail
                              ? "Rotate the 3D model and capture the view you want for your marketplace thumbnail."
                              : "Capture isn't available on this platform. Upload an image thumbnail instead.",
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12.5),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _uploadRow(
                                label: _thumbnailName ?? "Upload an image thumbnail",
                                onPressed: _pickThumbnail,
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _canCaptureThumbnail ? _captureThumbnail : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CC9F0),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text("Capture View"),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _previewCard(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.18)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _submitUpload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8A4FFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(_isUploading ? "Uploading..." : "Post Asset"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  const Text(
                    "Preview",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  if (_thumbnailCaptured)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          "Thumbnail set",
                          style: TextStyle(color: Color(0xFF22C55E), fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          color: Colors.black.withOpacity(0.18),
                          child: RepaintBoundary(
                            key: _viewerKey,
                            child: _modelDataUrl == null
                                ? Center(
                                    child: Text(
                                      "Model preview",
                                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                                    ),
                                  )
                                : ModelViewer(
                                    key: ValueKey(_modelDataUrl),
                                    id: _viewerDomId,
                                    src: _modelDataUrl!,
                                    backgroundColor: Colors.transparent,
                                    cameraControls: true,
                                    disableZoom: false,
                                    autoRotate: false,
                                    environmentImage: "neutral",
                                    exposure: 1.0,
                                    shadowIntensity: 0.8,
                                    shadowSoftness: 1,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Thumbnail",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 80,
                            width: 120,
                            color: Colors.black.withOpacity(0.2),
                            child: _thumbnailBytes == null
                                ? Center(
                                    child: Text(
                                      "No image",
                                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                                    ),
                                  )
                                : Image.memory(
                                    _thumbnailBytes!,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF8A4FFF)),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
    );
  }

  Widget _uploadRow({required String label, required VoidCallback onPressed}) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.upload_file_rounded, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withOpacity(0.18)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return InputDecorator(
      decoration: _inputDecoration(label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF1B1F2E),
          iconEnabledColor: Colors.white70,
          style: const TextStyle(color: Colors.white),
          items: options
              .map((option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _CreatorResult {
  final String id;
  final String name;
  final int assetCount;

  const _CreatorResult({
    required this.id,
    required this.name,
    required this.assetCount,
  });

  _CreatorResult copyWith({
    String? id,
    String? name,
    int? assetCount,
  }) {
    return _CreatorResult(
      id: id ?? this.id,
      name: name ?? this.name,
      assetCount: assetCount ?? this.assetCount,
    );
  }
}

class _CreatorResultCard extends StatelessWidget {
  final _CreatorResult creator;
  final double width;
  final VoidCallback onTap;

  const _CreatorResultCard({
    required this.creator,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF8A4FFF).withOpacity(0.4),
                child: Text(
                  creator.name.isNotEmpty ? creator.name.characters.first.toUpperCase() : "?",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      creator.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${creator.assetCount} item${creator.assetCount == 1 ? "" : "s"}",
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// ✅ Card (shows priceText: FREE or EGP xxx)
// =====================================================================

class AssetCard extends StatelessWidget {
  final String name;
  final String author;
  final String creatorId;
  final String likes;
  final String tag;
  final String styleTag;
  final String? posterUrl;
  final String priceText;
  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;

  const AssetCard({
    super.key,
    required this.name,
    required this.author,
    required this.creatorId,
    required this.likes,
    required this.tag,
    required this.styleTag,
    required this.posterUrl,
    required this.priceText,
    required this.width,
    this.onTap,
    this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCgiLike = styleTag == "Realistic" || tag == "Environments";

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.24),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: posterUrl == null || posterUrl!.isEmpty
                    ? Container(
                        color: Colors.white.withOpacity(0.06),
                        child: const Center(
                          child: Icon(Icons.image_not_supported_rounded, color: Colors.white54),
                        ),
                      )
                    : Image.network(
                        posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.white.withOpacity(0.06),
                          child: const Center(
                            child: Icon(Icons.image_not_supported_rounded, color: Colors.white54),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                MiniBadge(
                  text: isCgiLike ? "CGI" : styleTag,
                  accent: isCgiLike ? const Color(0xFF4CC9F0) : const Color(0xFFBC70FF),
                ),
              ],
            ),
            const SizedBox(height: 3),
            MouseRegion(
              cursor: onAuthorTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
              child: GestureDetector(
                onTap: onAuthorTap,
                child: Text(
                  "by $author",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    decoration: onAuthorTap != null ? TextDecoration.underline : TextDecoration.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(tag, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const Spacer(),
                Text(
                  priceText,
                  style: TextStyle(
                    color: priceText == "FREE" ? const Color(0xFF22C55E) : Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.favorite_border_rounded, size: 16, color: Colors.white70),
                const SizedBox(width: 4),
                Text(likes, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// ✅ Details Panel (UNCHANGED logic)
// - Buy -> /payment route
// - Free -> start download
// - Expanded viewer fix (single WebGL)
// =====================================================================

class AssetDetailsPanel extends StatefulWidget {
  final MarketplaceAsset asset;
  final VoidCallback onClose;

  final void Function(MarketplaceAsset asset) onPaidBuy;
  final void Function(MarketplaceAsset asset, String? format) onFreeDownload;

  const AssetDetailsPanel({
    super.key,
    required this.asset,
    required this.onClose,
    required this.onPaidBuy,
    required this.onFreeDownload,
  });

  @override
  State<AssetDetailsPanel> createState() => _AssetDetailsPanelState();
}

class _AssetDetailsPanelState extends State<AssetDetailsPanel> {
  bool _expandedOpen = false;
  bool _liked = false;
  bool _saved = false;
  late int _likesCount;
  bool _liking = false;
  bool _saving = false;
  late final List<String> _formats;
  String? _selectedFormat;

  Future<void> _openExpanded(BuildContext context) async {
    setState(() => _expandedOpen = true);

    final model = widget.asset.previewUrl ?? "";
    final poster = widget.asset.thumbUrl ?? "";
    final title = widget.asset.title.isNotEmpty ? widget.asset.title : "Preview";
    final bool isWebWide = MediaQuery.of(context).size.width >= 900;

    if (isWebWide) {
      await showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.65),
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: _ExpandedViewerShell(title: title, model: model, poster: poster),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.90,
            child: _ExpandedViewerShell(title: title, model: model, poster: poster),
          ),
        ),
      );
    }

    if (mounted) setState(() => _expandedOpen = false);
  }

  bool _isFree() {
    return !widget.asset.isPaid || widget.asset.price <= 0;
  }

  String _priceLabel() {
    final p = widget.asset.price;
    if (p <= 0) return "FREE";
    return "EGP $p";
  }

  @override
  void initState() {
    super.initState();
    _likesCount = int.tryParse(widget.asset.likes) ?? 0;
    _formats = _buildFormats(widget.asset);
    _selectedFormat = _formats.isNotEmpty ? _formats.first : null;
  }

  List<String> _buildFormats(MarketplaceAsset asset) {
    final formats = <String>[];
    final rawFormats = asset.metadata['formats'];
    if (rawFormats is List) {
      for (final entry in rawFormats) {
        final normalized = _normalizeFormat(entry?.toString());
        if (normalized != null && !formats.contains(normalized)) {
          formats.add(normalized);
        }
      }
    }
    final fallbackExt = _formatFromKey(asset.modelObjectKey);
    if (formats.isEmpty && fallbackExt != null) {
      formats.add(fallbackExt);
    }
    return formats;
  }

  String? _normalizeFormat(String? raw) {
    final trimmed = raw?.trim().toLowerCase();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.startsWith('.') ? trimmed : '.$trimmed';
  }

  String? _formatFromKey(String? key) {
    if (key == null || !key.contains('.')) return null;
    final ext = key.split('.').last.trim().toLowerCase();
    if (ext.isEmpty) return null;
    return '.$ext';
  }

  Future<void> _toggleLike() async {
    if (_liking) return;
    final nextLiked = !_liked;
    setState(() {
      _liked = nextLiked;
      _likesCount += nextLiked ? 1 : -1;
      _liking = true;
    });
    try {
      if (nextLiked) {
        await r2vMarketplace.likeAsset(widget.asset.id);
      } else {
        await r2vMarketplace.unlikeAsset(widget.asset.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(nextLiked ? 'Added to likes' : 'Removed from likes')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _liked = !nextLiked;
        _likesCount += nextLiked ? -1 : 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liked = !nextLiked;
        _likesCount += nextLiked ? -1 : 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update like')),
      );
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _toggleSave() async {
    if (_saving) return;
    final nextSaved = !_saved;
    setState(() {
      _saved = nextSaved;
      _saving = true;
    });
    try {
      if (nextSaved) {
        await r2vMarketplace.saveAsset(widget.asset.id);
      } else {
        await r2vMarketplace.unsaveAsset(widget.asset.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(nextSaved ? 'Saved to your profile' : 'Removed from saved')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saved = !nextSaved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saved = !nextSaved);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update saved')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.asset.title;
    final author = widget.asset.author;
    final likes = _likesCount.toString();
    final tag = widget.asset.category;
    final style = widget.asset.style;
    final model = widget.asset.previewUrl ?? "";
    final poster = widget.asset.thumbUrl ?? "";
    final description = widget.asset.description.isNotEmpty
        ? widget.asset.description
        : "No description provided.";

    final free = _isFree();
    final priceText = _priceLabel();

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 34,
                      height: 34,
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
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/profile',
                      arguments: {'userId': widget.asset.creatorId, 'username': author},
                    ),
                    child: Text(
                      "by $author",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          MiniBadge(text: tag, accent: const Color(0xFF4CC9F0)),
                          MiniBadge(text: style, accent: const Color(0xFFBC70FF)),
                          MiniBadge(text: "Likes: $likes", accent: const Color(0xFFF72585)),
                          MiniBadge(
                            text: priceText,
                            accent: free ? const Color(0xFF22C55E) : const Color(0xFF8A4FFF),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Text(
                          description,
                          style: TextStyle(color: Colors.white.withOpacity(0.85), height: 1.35),
                        ),
                      ),
                      const SizedBox(height: 12),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 11,
                              child: Container(
                                color: Colors.black.withOpacity(0.18),
                                child: _expandedOpen
                                    ? (poster.isEmpty
                                        ? Center(
                                            child: Icon(Icons.image, color: Colors.white.withOpacity(0.35)),
                                          )
                                        : Image.network(
                                            poster,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Center(
                                              child: Icon(Icons.image, color: Colors.white.withOpacity(0.35)),
                                            ),
                                          ))
                                    : (model.isEmpty
                                        ? Center(
                                            child: Text(
                                              "Preview unavailable",
                                              style: TextStyle(color: Colors.white.withOpacity(0.7)),
                                            ),
                                          )
                                        : ModelViewer(
                                            key: ValueKey(model),
                                            src: model,
                                            poster: poster,
                                            backgroundColor: Colors.transparent,
                                            cameraControls: true,
                                            disableZoom: true,
                                            autoRotate: true,
                                            environmentImage: "neutral",
                                            exposure: 1.0,
                                            shadowIntensity: 0.8,
                                            shadowSoftness: 1,
                                          )),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: InkWell(
                                onTap: () => _openExpanded(context),
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.45),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                                  ),
                                  child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),
                      Text(
                        "Pack Options",
                        style: TextStyle(color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      _optionRow("Base Model", true),
                      _optionRow("LOD", false),
                      _optionRow("PBR Materials", true),

                      const SizedBox(height: 14),
                      Text(
                        "Formats",
                        style: TextStyle(color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      if (_formats.isEmpty)
                        Text(
                          "Format info unavailable",
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _formats
                              .map((f) => InkWell(
                                    onTap: () => setState(() => _selectedFormat = f),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _selectedFormat == f
                                            ? const Color(0xFF4CC9F0).withOpacity(0.28)
                                            : Colors.white.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: _selectedFormat == f
                                              ? const Color(0xFF4CC9F0)
                                              : Colors.white.withOpacity(0.12),
                                        ),
                                      ),
                                      child: Text(
                                        f,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _toggleLike,
                      icon: Icon(
                        _liked ? Icons.favorite : Icons.favorite_border_rounded,
                        size: 18,
                        color: _liked ? const Color(0xFFF72585) : Colors.white,
                      ),
                      label: Text(_liked ? "Liked" : "Like"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.18)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _toggleSave,
                      icon: Icon(
                        _saved ? Icons.bookmark : Icons.bookmark_border_rounded,
                        size: 18,
                        color: _saved ? const Color(0xFF4CC9F0) : Colors.white,
                      ),
                      label: Text(_saved ? "Saved" : "Save"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.18)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: widget.asset.id));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Asset ID copied')),
                        );
                      },
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text("Send"),
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
                      onPressed: () {
                        if (free) {
                          widget.onFreeDownload(widget.asset, _selectedFormat);
                        } else {
                          widget.onPaidBuy(widget.asset);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: free ? const Color(0xFF22C55E) : const Color(0xFF8A4FFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        free ? "Download" : "Buy $priceText",
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
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

  static Widget _optionRow(String label, bool enabled) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: enabled ? const Color(0xFF4CC9F0) : Colors.white54,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// ✅ Expanded viewer
// =====================================================================

class _ExpandedViewerShell extends StatelessWidget {
  final String title;
  final String model;
  final String poster;

  const _ExpandedViewerShell({
    required this.title,
    required this.model,
    required this.poster,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 34,
                        height: 34,
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
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    color: Colors.black.withOpacity(0.18),
                    child: model.isEmpty
                        ? Center(
                            child: Text(
                              "Preview unavailable",
                              style: TextStyle(color: Colors.white.withOpacity(0.7)),
                            ),
                          )
                        : ModelViewer(
                            key: ValueKey("expanded-$model"),
                            src: model,
                            poster: poster,
                            backgroundColor: Colors.transparent,
                            cameraControls: true,
                            disableZoom: false,
                            autoRotate: true,
                            environmentImage: "neutral",
                            exposure: 1.0,
                            shadowIntensity: 0.8,
                            shadowSoftness: 1,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================

class NavTextButton extends StatelessWidget {
  final String label;
  final bool isActive;

  const NavTextButton({super.key, required this.label, this.isActive = false});

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

class MiniBadge extends StatelessWidget {
  final String text;
  final Color accent;

  const MiniBadge({super.key, required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(0.40)),
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// =====================================================================
// ✅ Background (unchanged)
// =====================================================================

class NebulaMeshBackground extends StatefulWidget {
  const NebulaMeshBackground({super.key});

  @override
  State<NebulaMeshBackground> createState() => _NebulaMeshBackgroundState();
}

class _NebulaMeshBackgroundState extends State<NebulaMeshBackground> with SingleTickerProviderStateMixin {
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
