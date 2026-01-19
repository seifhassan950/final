import 'dart:ui';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/scheduler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/r2v_api.dart';
import '../api/api_exception.dart';
import '../api/marketplace_service.dart';
import '../api/social_service.dart';
import 'explore_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String username;
  final String? userId;
  final String? initialTab;

  const ProfileScreen({super.key, this.username = 'User', this.userId, this.initialTab});

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width >= 900;

    return Stack(
      children: [
        const Positioned.fill(child: ParticleMeshBackground()),
        Positioned.fill(
          child: isWeb
              ? _WebProfile(username: username, userId: userId, initialTab: initialTab)
              : _MobileProfile(username: username, userId: userId, initialTab: initialTab),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────
// WEB VERSION
// ──────────────────────────────────────────────────────────
class _WebProfile extends StatefulWidget {
  final String username;
  final String? userId;
  final String? initialTab;
  const _WebProfile({required this.username, this.userId, this.initialTab});

  @override
  State<_WebProfile> createState() => _WebProfileState();
}

class _WebProfileState extends State<_WebProfile> {
  int _activeIndex = 0; // Home is 0 for top tabs, but we keep highlight on Profile separately
  int? _hoverIndex;
  ProfileTab _activeTab = ProfileTab.posts;

  late String displayName;
  String displayRole = "Designer · 3D Artist";
  String displayBio = "I create 3D content using AI & real-world photogrammetry tools.";
  Uint8List? avatarBytes;
  String? avatarUrl;
  Map<String, dynamic> _meta = {};
  bool _loadingProfile = false;
  bool _loadingFollow = false;
  String? _profileUserId;
  bool _isSelf = true;
  bool _isFollowing = false;
  int _postsCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;
  bool _loadingPosts = false;
  String? _postsError;
  List<MarketplaceAsset> _posts = [];
  bool _loadingSaved = false;
  bool _loadingLiked = false;
  String? _savedError;
  String? _likedError;
  List<MarketplaceAsset> _savedAssets = [];
  List<MarketplaceAsset> _likedAssets = [];

  Future<void> _openAssetPreview(MarketplaceAsset asset) async {
    await _showAssetPreview(context, asset);
  }

  void _applyInitialTab(String? tab) {
    final parsed = _parseProfileTab(tab);
    if (!_isSelf || parsed == null) return;
    _activeTab = parsed;
  }

  Future<void> _loadInitialTabAssets() async {
    if (!_isSelf) return;
    if (_activeTab == ProfileTab.saved) {
      await _loadSaved();
    } else if (_activeTab == ProfileTab.liked) {
      await _loadLiked();
    }
  }

  @override
  void initState() {
    super.initState();
    displayName = widget.username;
    _profileUserId = _normalizeUserId(widget.userId);
    _isSelf = _profileUserId == null;
    _applyInitialTab(widget.initialTab);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadProfile();
    await _loadPosts();
    await _loadInitialTabAssets();
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);
    try {
      final profile = await r2vProfile.me();
      final targetUserId = _normalizeUserId(widget.userId) ?? profile.id;
      SocialProfile? socialProfile;
      try {
        socialProfile = await r2vSocial.getProfile(targetUserId);
      } on ApiException catch (e) {
        if (e.statusCode != 404) rethrow;
      }
      if (!mounted) return;
      setState(() {
        _profileUserId = targetUserId;
        _isSelf = (socialProfile?.isSelf ?? false) || profile.id == targetUserId;
        _isFollowing = socialProfile?.isFollowing ?? false;
        _postsCount = socialProfile?.posts ?? _postsCount;
        _followersCount = socialProfile?.followers ?? _followersCount;
        _followingCount = socialProfile?.following ?? _followingCount;
        displayName = (socialProfile?.username.isNotEmpty ?? false) ? socialProfile!.username : displayName;
        displayBio = socialProfile?.bio ?? displayBio;
        avatarUrl = socialProfile?.avatarUrl ?? avatarUrl;
        avatarBytes = _decodeAvatar(socialProfile?.avatarUrl) ?? avatarBytes;
        if (_isSelf) {
          displayName = profile.username.isNotEmpty ? profile.username : displayName;
          displayBio = profile.bio ?? displayBio;
          _meta = profile.meta;
          displayRole = profile.meta['role']?.toString() ?? displayRole;
          avatarUrl = profile.avatarUrl ?? avatarUrl;
          avatarBytes = _decodeAvatar(profile.avatarUrl) ?? avatarBytes;
        }
        if (!_isSelf) {
          _activeTab = ProfileTab.posts;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode != 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load profile')),
      );
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadPosts() async {
    if (!_isSelf && (_profileUserId == null || _profileUserId!.isEmpty)) return;
    setState(() {
      _loadingPosts = true;
      _postsError = null;
    });
    try {
      final assets = _isSelf
          ? await r2vMarketplace.listMyAssets()
          : await r2vMarketplace.listUserAssets(_profileUserId!);
      if (!mounted) return;
      setState(() {
        _posts = assets;
        _postsCount = assets.length;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _postsError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _postsError = _isSelf ? 'Failed to load your posts' : 'Failed to load posts');
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _openFollowList({required bool showFollowers}) async {
    final targetUserId = _profileUserId;
    if (targetUserId == null || targetUserId.isEmpty) return;
    final title = showFollowers ? 'Followers' : 'Following';
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 360,
            child: FutureBuilder<List<SocialUser>>(
              future: showFollowers ? r2vSocial.getFollowers(targetUserId) : r2vSocial.getFollowing(targetUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return SizedBox(
                    height: 220,
                    child: Center(child: Text('Failed to load $title')),
                  );
                }
                final users = snapshot.data ?? [];
                if (users.isEmpty) {
                  return SizedBox(
                    height: 220,
                    child: Center(child: Text('No ${title.toLowerCase()} yet')),
                  );
                }
                return SizedBox(
                  height: 320,
                  child: ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, __) => Divider(color: Colors.grey.shade300, height: 1),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: _followAvatar(user),
                        title: Text(user.username),
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(username: user.username, userId: user.userId),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close')),
          ],
        );
      },
    );
  }

  Widget _followAvatar(SocialUser user) {
    final bytes = _decodeAvatar(user.avatarUrl);
    if (bytes != null) {
      return CircleAvatar(backgroundImage: MemoryImage(bytes));
    }
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(user.avatarUrl!));
    }
    return CircleAvatar(
      backgroundColor: Colors.white.withOpacity(0.12),
      child: const Icon(Icons.person, color: Colors.white70),
    );
  }

  Future<void> _loadSaved() async {
    if (!_isSelf) return;
    setState(() {
      _loadingSaved = true;
      _savedError = null;
    });
    try {
      final assets = await r2vMarketplace.listSavedAssets();
      if (!mounted) return;
      setState(() => _savedAssets = assets);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _savedError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _savedError = 'Failed to load saved assets');
    } finally {
      if (mounted) setState(() => _loadingSaved = false);
    }
  }

  Future<void> _loadLiked() async {
    if (!_isSelf) return;
    setState(() {
      _loadingLiked = true;
      _likedError = null;
    });
    try {
      final assets = await r2vMarketplace.listLikedAssets();
      if (!mounted) return;
      setState(() => _likedAssets = assets);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _likedError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _likedError = 'Failed to load liked assets');
    } finally {
      if (mounted) setState(() => _loadingLiked = false);
    }
  }

  Future<void> _confirmDeleteAsset(MarketplaceAsset asset) async {
    if (!_isSelf) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete asset?'),
        content: const Text('This will remove the asset from your profile and marketplace.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (shouldDelete != true) return;
    try {
      await r2vMarketplace.deleteAsset(asset.id);
      if (!mounted) return;
      setState(() {
        _posts.removeWhere((item) => item.id == asset.id);
        _postsCount = _posts.length;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asset deleted')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete asset')),
      );
    }
  }

  Uint8List? _decodeAvatar(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (!raw.startsWith('data:image')) return null;
    final parts = raw.split(',');
    if (parts.length < 2) return null;
    try {
      return base64Decode(parts.last);
    } catch (_) {
      return null;
    }
  }

  String? _normalizeUserId(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == 'null') return null;
    return trimmed;
  }

  Future<void> _openEditProfileDialog() async {
    if (!_isSelf) return;
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return _EditProfileDialog(
          initialName: displayName,
          initialRole: displayRole,
          initialBio: displayBio,
          initialAvatar: avatarBytes,
          onSave: _saveProfile,
        );
      },
    );
  }

  Future<void> _saveProfile(String name, String role, String bio, Uint8List? bytes) async {
    if (!_isSelf) return;
    final nextMeta = Map<String, dynamic>.from(_meta);
    nextMeta['role'] = role;
    final avatarDataUrl = bytes == null ? avatarUrl : _toDataUrl(bytes);
    setState(() => _loadingProfile = true);
    try {
      final updated = await r2vProfile.update(
        username: name,
        bio: bio,
        avatarUrl: avatarDataUrl,
        meta: nextMeta,
      );
      if (!mounted) return;
      setState(() {
        displayName = updated.username;
        displayBio = updated.bio ?? displayBio;
        displayRole = updated.meta['role']?.toString() ?? displayRole;
        _meta = updated.meta;
        avatarUrl = updated.avatarUrl;
        avatarBytes = _decodeAvatar(updated.avatarUrl) ?? bytes;
      });
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile')),
      );
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  String _toDataUrl(Uint8List bytes) {
    final encoded = base64Encode(bytes);
    return 'data:image/png;base64,$encoded';
  }

  // Follow/unfollow handler (web profile)
  Future<void> _toggleFollow() async {
    if (_loadingFollow || _isSelf || _profileUserId == null) return;
    setState(() => _loadingFollow = true);
    try {
      if (_isFollowing) {
        await r2vSocial.unfollow(_profileUserId!);
      } else {
        await r2vSocial.follow(_profileUserId!);
      }
      if (!mounted) return;
      setState(() {
        _isFollowing = !_isFollowing;
        _followersCount += _isFollowing ? 1 : -1;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isFollowing ? 'Unable to unfollow user' : 'Unable to follow user')),
      );
    } finally {
      if (mounted) setState(() => _loadingFollow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final double contentWidth = w > 1180 ? 1180 : w;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: Column(
              children: [
                const SizedBox(height: 14),

                // ✅ Same glass top bar style
                _GlassTopBar(
                  activeIndex: 0, // keep tabs consistent; profile icon is the "active" feel here
                  hoverIndex: _hoverIndex,
                  onHover: (v) => setState(() => _hoverIndex = v),
                  onLeave: () => setState(() => _hoverIndex = null),
                  onNavTap: (idx) {
                    setState(() => _activeIndex = idx);
                    switch (idx) {
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
                  onProfile: () {}, // already on profile
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _glassProfileHeader(context),
                        const SizedBox(height: 16),
                        _glassTabsRow(),
                        const SizedBox(height: 14),
                        _glassGrid(),
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

  Widget _glassProfileHeader(BuildContext context) {
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _avatar(90),
              const SizedBox(width: 20),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(displayRole, style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 14.5)),
                    const SizedBox(height: 6),
                    Text(displayBio, style: TextStyle(color: Colors.white.withOpacity(0.62), fontSize: 13)),
                    const SizedBox(height: 14),

                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: const [
                        _PillTag(icon: Icons.auto_awesome_rounded, label: "AI Creator"),
                        _PillTag(icon: Icons.photo_camera_back_rounded, label: "Photogrammetry"),
                        _PillTag(icon: Icons.view_in_ar_rounded, label: "AR/VR"),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 18),

              _stat('$_postsCount', "Posts"),
              const SizedBox(width: 26),
              _stat('$_followersCount', "Followers", onTap: () => _openFollowList(showFollowers: true)),
              const SizedBox(width: 26),
              _stat('$_followingCount', "Following", onTap: () => _openFollowList(showFollowers: false)),
              const SizedBox(width: 18),

              _isSelf
                  ? ElevatedButton.icon(
                      onPressed: _openEditProfileDialog,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text("Edit Profile"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8A4FFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _loadingFollow ? null : _toggleFollow,
                      icon: Icon(_isFollowing ? Icons.check_rounded : Icons.person_add_alt_1_rounded, size: 18),
                      label: Text(_isFollowing ? "Following" : "Follow"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing ? Colors.white.withOpacity(0.12) : const Color(0xFF8A4FFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassTabsRow() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.16),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Row(
            children: [
              _TabChip(
                label: "Posts",
                active: _activeTab == ProfileTab.posts,
                onTap: () => setState(() => _activeTab = ProfileTab.posts),
              ),
              if (_isSelf) ...[
                const SizedBox(width: 10),
                _TabChip(
                  label: "Saved",
                  active: _activeTab == ProfileTab.saved,
                  onTap: () {
                    setState(() => _activeTab = ProfileTab.saved);
                    if (_savedAssets.isEmpty && !_loadingSaved) {
                      _loadSaved();
                    }
                  },
                ),
                const SizedBox(width: 10),
                _TabChip(
                  label: "Liked",
                  active: _activeTab == ProfileTab.liked,
                  onTap: () {
                    setState(() => _activeTab = ProfileTab.liked);
                    if (_likedAssets.isEmpty && !_loadingLiked) {
                      _loadLiked();
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassGrid() {
    if (_activeTab == ProfileTab.posts) {
      if (_loadingPosts) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      }
      if (_postsError != null) {
        return Center(
          child: Column(
            children: [
              Text(_postsError!, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _loadPosts,
                child: const Text("Retry", style: TextStyle(color: Color(0xFF4CC9F0))),
              ),
            ],
          ),
        );
      }
      if (_posts.isEmpty) {
        return _emptyTabState(
          title: "No posts yet.",
          onAction: () => Navigator.pushNamed(context, '/explore'),
        );
      }
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: _posts.map((asset) => _postTile(asset, showDelete: _isSelf)).toList(),
      );
    }
    if (_activeTab == ProfileTab.saved) {
      return _assetTabGrid(
        assets: _savedAssets,
        loading: _loadingSaved,
        error: _savedError,
        emptyTitle: "No saved assets yet.",
      );
    }
    return _assetTabGrid(
      assets: _likedAssets,
      loading: _loadingLiked,
      error: _likedError,
      emptyTitle: "No liked assets yet.",
    );
  }

  Widget _assetTabGrid({
    required List<MarketplaceAsset> assets,
    required bool loading,
    required String? error,
    required String emptyTitle,
  }) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    if (error != null) {
      return Center(
        child: Column(
          children: [
            Text(error, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _activeTab == ProfileTab.saved ? _loadSaved : _loadLiked,
              child: const Text("Retry", style: TextStyle(color: Color(0xFF4CC9F0))),
            ),
          ],
        ),
      );
    }
    if (assets.isEmpty) {
      return _emptyTabState(
        title: emptyTitle,
        onAction: () => Navigator.pushNamed(context, '/explore'),
      );
    }
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: assets.map((asset) => _postTile(asset)).toList(),
    );
  }

  Widget _postTile(MarketplaceAsset asset, {bool showDelete = false}) {
    final thumb = asset.thumbUrl ?? '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openAssetPreview(asset),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Positioned.fill(
                  child: thumb.isEmpty
                      ? Container(
                          color: Colors.black.withOpacity(0.12),
                          child: const Center(
                            child: Icon(Icons.image_rounded, color: Colors.white30, size: 60),
                          ),
                        )
                      : Image.network(
                          thumb,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.black.withOpacity(0.12),
                            child: const Center(
                              child: Icon(Icons.image_rounded, color: Colors.white30, size: 60),
                            ),
                          ),
                        ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      asset.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ),
                if (showDelete)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: InkWell(
                      onTap: () => _confirmDeleteAsset(asset),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.white, size: 16),
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

  Widget _stat(String value, String label, {VoidCallback? onTap}) {
    final content = Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 12)),
      ],
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: content,
      ),
    );
  }

  Widget _avatar(double size) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.10),
        border: Border.all(color: Colors.white.withOpacity(0.22), width: 1.2),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipOval(
              child: avatarBytes != null
                  ? Image.memory(avatarBytes!, fit: BoxFit.cover)
                  : (avatarUrl != null && avatarUrl!.isNotEmpty && !avatarUrl!.startsWith('data:image')
                      ? Image.network(avatarUrl!, fit: BoxFit.cover)
                      : const Icon(Icons.person, size: 42, color: Colors.white54)),
            ),
          ),
          if (_isSelf)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: size * 0.26,
                height: size * 0.26,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                ),
                child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: size * 0.14),
              ),
            ),
        ],
      ),
    );
    if (!_isSelf) return avatar;
    return GestureDetector(onTap: _openEditProfileDialog, child: avatar);
  }

  Widget _emptyTabState({
    required String title,
    required VoidCallback onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          Icon(Icons.bookmark_border_rounded, color: Colors.white.withOpacity(0.5), size: 40),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onAction,
            child: const Text("Browse Marketplace", style: TextStyle(color: Color(0xFF4CC9F0))),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// MOBILE VERSION
// ──────────────────────────────────────────────────────────
class _MobileProfile extends StatefulWidget {
  final String username;
  final String? userId;
  final String? initialTab;
  const _MobileProfile({required this.username, this.userId, this.initialTab});

  @override
  State<_MobileProfile> createState() => _MobileProfileState();
}

class _MobileProfileState extends State<_MobileProfile> {
  late String displayName;
  String displayRole = "3D Artist · Designer";
  String displayBio = "Building the future of AR/VR assets using AI + photogrammetry.";
  Uint8List? avatarBytes;
  String? avatarUrl;
  Map<String, dynamic> _meta = {};
  bool _loadingProfile = false;
  bool _loadingFollow = false;
  String? _profileUserId;
  bool _isSelf = true;
  bool _isFollowing = false;
  int _postsCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;
  ProfileTab _activeTab = ProfileTab.posts;
  bool _loadingPosts = false;
  String? _postsError;
  List<MarketplaceAsset> _posts = [];
  bool _loadingSaved = false;
  bool _loadingLiked = false;
  String? _savedError;
  String? _likedError;
  List<MarketplaceAsset> _savedAssets = [];
  List<MarketplaceAsset> _likedAssets = [];

  Future<void> _openAssetPreview(MarketplaceAsset asset) async {
    await _showAssetPreview(context, asset);
  }

  void _applyInitialTab(String? tab) {
    final parsed = _parseProfileTab(tab);
    if (!_isSelf || parsed == null) return;
    _activeTab = parsed;
  }

  Future<void> _loadInitialTabAssets() async {
    if (!_isSelf) return;
    if (_activeTab == ProfileTab.saved) {
      await _loadSaved();
    } else if (_activeTab == ProfileTab.liked) {
      await _loadLiked();
    }
  }

  @override
  void initState() {
    super.initState();
    displayName = widget.username;
    _profileUserId = _normalizeUserId(widget.userId);
    _isSelf = _profileUserId == null;
    _applyInitialTab(widget.initialTab);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadProfile();
    await _loadPosts();
    await _loadInitialTabAssets();
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);
    try {
      final profile = await r2vProfile.me();
      final targetUserId = _normalizeUserId(widget.userId) ?? profile.id;
      SocialProfile? socialProfile;
      try {
        socialProfile = await r2vSocial.getProfile(targetUserId);
      } on ApiException catch (e) {
        if (e.statusCode != 404) rethrow;
      }
      if (!mounted) return;
      setState(() {
        _profileUserId = targetUserId;
        _isSelf = (socialProfile?.isSelf ?? false) || profile.id == targetUserId;
        _isFollowing = socialProfile?.isFollowing ?? false;
        _postsCount = socialProfile?.posts ?? _postsCount;
        _followersCount = socialProfile?.followers ?? _followersCount;
        _followingCount = socialProfile?.following ?? _followingCount;
        displayName = (socialProfile?.username.isNotEmpty ?? false) ? socialProfile!.username : displayName;
        displayBio = socialProfile?.bio ?? displayBio;
        avatarUrl = socialProfile?.avatarUrl ?? avatarUrl;
        avatarBytes = _decodeAvatar(socialProfile?.avatarUrl) ?? avatarBytes;
        if (_isSelf) {
          displayName = profile.username.isNotEmpty ? profile.username : displayName;
          displayBio = profile.bio ?? displayBio;
          _meta = profile.meta;
          displayRole = profile.meta['role']?.toString() ?? displayRole;
          avatarUrl = profile.avatarUrl ?? avatarUrl;
          avatarBytes = _decodeAvatar(profile.avatarUrl) ?? avatarBytes;
        }
        if (!_isSelf) {
          _activeTab = ProfileTab.posts;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode != 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load profile')),
      );
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadPosts() async {
    if (!_isSelf && (_profileUserId == null || _profileUserId!.isEmpty)) return;
    setState(() {
      _loadingPosts = true;
      _postsError = null;
    });
    try {
      final assets = _isSelf
          ? await r2vMarketplace.listMyAssets()
          : await r2vMarketplace.listUserAssets(_profileUserId!);
      if (!mounted) return;
      setState(() {
        _posts = assets;
        _postsCount = assets.length;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _postsError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _postsError = _isSelf ? 'Failed to load your posts' : 'Failed to load posts');
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _openFollowSheet({required bool showFollowers}) async {
    final targetUserId = _profileUserId;
    if (targetUserId == null || targetUserId.isEmpty) return;
    final title = showFollowers ? 'Followers' : 'Following';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black.withOpacity(0.85),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 16),
                FutureBuilder<List<SocialUser>>(
                  future: showFollowers ? r2vSocial.getFollowers(targetUserId) : r2vSocial.getFollowing(targetUserId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text('Failed to load $title', style: const TextStyle(color: Colors.white70)),
                        ),
                      );
                    }
                    final users = snapshot.data ?? [];
                    if (users.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text('No ${title.toLowerCase()} yet', style: const TextStyle(color: Colors.white70)),
                      );
                    }
                    return SizedBox(
                      height: 360,
                      child: ListView.separated(
                        itemCount: users.length,
                        separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.1), height: 1),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return ListTile(
                            leading: _followAvatar(user),
                            title: Text(user.username, style: const TextStyle(color: Colors.white)),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProfileScreen(username: user.username, userId: user.userId),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _followAvatar(SocialUser user) {
    final bytes = _decodeAvatar(user.avatarUrl);
    if (bytes != null) {
      return CircleAvatar(backgroundImage: MemoryImage(bytes));
    }
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(user.avatarUrl!));
    }
    return CircleAvatar(
      backgroundColor: Colors.white.withOpacity(0.12),
      child: const Icon(Icons.person, color: Colors.white70),
    );
  }

  Future<void> _loadSaved() async {
    if (!_isSelf) return;
    setState(() {
      _loadingSaved = true;
      _savedError = null;
    });
    try {
      final assets = await r2vMarketplace.listSavedAssets();
      if (!mounted) return;
      setState(() => _savedAssets = assets);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _savedError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _savedError = 'Failed to load saved assets');
    } finally {
      if (mounted) setState(() => _loadingSaved = false);
    }
  }

  Future<void> _loadLiked() async {
    if (!_isSelf) return;
    setState(() {
      _loadingLiked = true;
      _likedError = null;
    });
    try {
      final assets = await r2vMarketplace.listLikedAssets();
      if (!mounted) return;
      setState(() => _likedAssets = assets);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _likedError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _likedError = 'Failed to load liked assets');
    } finally {
      if (mounted) setState(() => _loadingLiked = false);
    }
  }

  Future<void> _confirmDeleteAsset(MarketplaceAsset asset) async {
    if (!_isSelf) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete asset?'),
        content: const Text('This will remove the asset from your profile and marketplace.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (shouldDelete != true) return;
    try {
      await r2vMarketplace.deleteAsset(asset.id);
      if (!mounted) return;
      setState(() {
        _posts.removeWhere((item) => item.id == asset.id);
        _postsCount = _posts.length;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asset deleted')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete asset')),
      );
    }
  }

  Uint8List? _decodeAvatar(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (!raw.startsWith('data:image')) return null;
    final parts = raw.split(',');
    if (parts.length < 2) return null;
    try {
      return base64Decode(parts.last);
    } catch (_) {
      return null;
    }
  }

  String? _normalizeUserId(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == 'null') return null;
    return trimmed;
  }

  Future<void> _openEditProfileDialog() async {
    if (!_isSelf) return;
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return _EditProfileDialog(
          initialName: displayName,
          initialRole: displayRole,
          initialBio: displayBio,
          initialAvatar: avatarBytes,
          onSave: _saveProfile,
        );
      },
    );
  }

  Future<void> _saveProfile(String name, String role, String bio, Uint8List? bytes) async {
    if (!_isSelf) return;
    final nextMeta = Map<String, dynamic>.from(_meta);
    nextMeta['role'] = role;
    final avatarDataUrl = bytes == null ? avatarUrl : _toDataUrl(bytes);
    setState(() => _loadingProfile = true);
    try {
      final updated = await r2vProfile.update(
        username: name,
        bio: bio,
        avatarUrl: avatarDataUrl,
        meta: nextMeta,
      );
      if (!mounted) return;
      setState(() {
        displayName = updated.username;
        displayBio = updated.bio ?? displayBio;
        displayRole = updated.meta['role']?.toString() ?? displayRole;
        _meta = updated.meta;
        avatarUrl = updated.avatarUrl;
        avatarBytes = _decodeAvatar(updated.avatarUrl) ?? bytes;
      });
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile')),
      );
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  String _toDataUrl(Uint8List bytes) {
    final encoded = base64Encode(bytes);
    return 'data:image/png;base64,$encoded';
  }

  // Follow/unfollow handler (mobile profile)
  Future<void> _toggleFollow() async {
    if (_loadingFollow || _isSelf || _profileUserId == null) return;
    setState(() => _loadingFollow = true);
    try {
      if (_isFollowing) {
        await r2vSocial.unfollow(_profileUserId!);
      } else {
        await r2vSocial.follow(_profileUserId!);
      }
      if (!mounted) return;
      setState(() {
        _isFollowing = !_isFollowing;
        _followersCount += _isFollowing ? 1 : -1;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isFollowing ? 'Unable to unfollow user' : 'Unable to follow user')),
      );
    } finally {
      if (mounted) setState(() => _loadingFollow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,

      // ✅ Glass app bar
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.16),
        elevation: 0,
        title: const Text("Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          if (_isSelf)
            IconButton(
              onPressed: _openEditProfileDialog,
              icon: const Icon(Icons.edit_rounded, color: Color(0xFFBC70FF)),
              tooltip: "Edit",
            ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _glassMobileHeader(),
            const SizedBox(height: 14),
            _glassMobileTabs(),
            const SizedBox(height: 14),
            _mobileGrid(),
          ],
        ),
      ),
    );
  }

  Widget _glassMobileHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            children: [
              _avatar(110),
              const SizedBox(height: 12),
              Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(displayRole, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                displayBio,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.62), fontSize: 12.5, height: 1.35),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MStat(value: '$_postsCount', label: "Posts"),
                  _MStat(
                    value: '$_followersCount',
                    label: "Followers",
                    onTap: () => _openFollowSheet(showFollowers: true),
                  ),
                  _MStat(
                    value: '$_followingCount',
                    label: "Following",
                    onTap: () => _openFollowSheet(showFollowers: false),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: _isSelf
                    ? ElevatedButton(
                        onPressed: _openEditProfileDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8A4FFF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.w700)),
                      )
                    : ElevatedButton.icon(
                        onPressed: _loadingFollow ? null : _toggleFollow,
                        icon: Icon(
                          _isFollowing ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
                          size: 18,
                        ),
                        label: Text(_isFollowing ? "Following" : "Follow"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing ? Colors.white.withOpacity(0.12) : const Color(0xFF8A4FFF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassMobileTabs() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Row(
            children: [
              _TabChip(
                label: "Posts",
                active: _activeTab == ProfileTab.posts,
                onTap: () => setState(() => _activeTab = ProfileTab.posts),
              ),
              if (_isSelf) ...[
                const SizedBox(width: 10),
                _TabChip(
                  label: "Saved",
                  active: _activeTab == ProfileTab.saved,
                  onTap: () {
                    setState(() => _activeTab = ProfileTab.saved);
                    if (_savedAssets.isEmpty && !_loadingSaved) {
                      _loadSaved();
                    }
                  },
                ),
                const SizedBox(width: 10),
                _TabChip(
                  label: "Liked",
                  active: _activeTab == ProfileTab.liked,
                  onTap: () {
                    setState(() => _activeTab = ProfileTab.liked);
                    if (_likedAssets.isEmpty && !_loadingLiked) {
                      _loadLiked();
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileGrid() {
    if (_activeTab == ProfileTab.posts) {
      if (_loadingPosts) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        );
      }
      if (_postsError != null) {
        return Center(
          child: Column(
            children: [
              Text(_postsError!, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _loadPosts,
                child: const Text("Retry", style: TextStyle(color: Color(0xFF4CC9F0))),
              ),
            ],
          ),
        );
      }
      if (_posts.isEmpty) {
        return _mobileEmptyState(
          title: "No posts yet.",
          onAction: () => Navigator.pushNamed(context, '/explore'),
        );
      }
      return _mobileAssetGrid(_posts, showDelete: _isSelf);
    }
    if (_activeTab == ProfileTab.saved) {
      return _mobileAssetTabGrid(
        assets: _savedAssets,
        loading: _loadingSaved,
        error: _savedError,
        emptyTitle: "No saved assets yet.",
      );
    }
    return _mobileAssetTabGrid(
      assets: _likedAssets,
      loading: _loadingLiked,
      error: _likedError,
      emptyTitle: "No liked assets yet.",
    );
  }

  Widget _mobileAssetTabGrid({
    required List<MarketplaceAsset> assets,
    required bool loading,
    required String? error,
    required String emptyTitle,
  }) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (error != null) {
      return Center(
        child: Column(
          children: [
            Text(error, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _activeTab == ProfileTab.saved ? _loadSaved : _loadLiked,
              child: const Text("Retry", style: TextStyle(color: Color(0xFF4CC9F0))),
            ),
          ],
        ),
      );
    }
    if (assets.isEmpty) {
      return _mobileEmptyState(
        title: emptyTitle,
        onAction: () => Navigator.pushNamed(context, '/explore'),
      );
    }
    return _mobileAssetGrid(assets);
  }

  Widget _mobileAssetGrid(List<MarketplaceAsset> assets, {bool showDelete = false}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: assets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, i) {
        final asset = assets[i];
        final thumb = asset.thumbUrl ?? '';
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openAssetPreview(asset),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: thumb.isEmpty
                          ? const Icon(Icons.image_rounded, color: Colors.white30)
                          : Image.network(
                              thumb,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded, color: Colors.white30),
                            ),
                    ),
                    if (showDelete)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: InkWell(
                          onTap: () => _confirmDeleteAsset(asset),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _mobileEmptyState({
    required String title,
    required VoidCallback onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          Icon(Icons.bookmark_border_rounded, color: Colors.white.withOpacity(0.5), size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onAction,
            child: const Text("Browse Marketplace", style: TextStyle(color: Color(0xFF4CC9F0))),
          ),
        ],
      ),
    );
  }

  Widget _avatar(double size) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.10),
        border: Border.all(color: Colors.white.withOpacity(0.22), width: 1.2),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipOval(
              child: avatarBytes != null
                  ? Image.memory(avatarBytes!, fit: BoxFit.cover)
                  : (avatarUrl != null && avatarUrl!.isNotEmpty && !avatarUrl!.startsWith('data:image')
                      ? Image.network(avatarUrl!, fit: BoxFit.cover)
                      : const Icon(Icons.person, size: 52, color: Colors.white54)),
            ),
          ),
          if (_isSelf)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: size * 0.26,
                height: size * 0.26,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                ),
                child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: size * 0.14),
              ),
            ),
        ],
      ),
    );
    if (!_isSelf) return avatar;
    return GestureDetector(onTap: _openEditProfileDialog, child: avatar);
  }
}

// ──────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS (tabs, stats)
// ──────────────────────────────────────────────────────────
class _TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _TabChip({required this.label, this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: active ? const LinearGradient(colors: [Color(0xFF8A4FFF), Color(0xFFBC70FF)]) : null,
          color: active ? null : Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

enum ProfileTab { posts, saved, liked }

ProfileTab? _parseProfileTab(String? value) {
  switch (value?.toLowerCase()) {
    case 'posts':
      return ProfileTab.posts;
    case 'saved':
      return ProfileTab.saved;
    case 'liked':
      return ProfileTab.liked;
    default:
      return null;
  }
}

class _MStat extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;
  const _MStat({required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12)),
      ],
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: content,
      ),
    );
  }
}

class _PillTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PillTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(0.85)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

Future<void> _showAssetPreview(BuildContext context, MarketplaceAsset asset) async {
  final bool isWebWide = MediaQuery.of(context).size.width >= 900;

  Future<void> startDownload({String? format}) async {
    try {
      final url = await r2vMarketplace.downloadAsset(asset.id, format: format);
      if (url.isEmpty) {
        throw Exception('Missing download url');
      }
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start download')),
      );
    }
  }

  if (isWebWide) {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 360,
            child: AssetDetailsPanel(
              asset: asset,
              onClose: () => Navigator.pop(context),
              onFreeDownload: (_, format) => startDownload(format: format),
              onPaidBuy: (selected) => Navigator.pushNamed(
                context,
                '/payment',
              arguments: selected,
            ),
          ),
        ),
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
          height: MediaQuery.of(context).size.height * 0.72,
          child: AssetDetailsPanel(
            asset: asset,
            onClose: () => Navigator.pop(context),
            onFreeDownload: (_, format) => startDownload(format: format),
            onPaidBuy: (selected) => Navigator.pushNamed(
              context,
              '/payment',
              arguments: selected,
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// TOP BAR (same as AI chat style)
// ──────────────────────────────────────────────────────────
class _GlassTopBar extends StatelessWidget {
  final int activeIndex;
  final int? hoverIndex;
  final void Function(int? idx) onHover;
  final VoidCallback onLeave;
  final void Function(int idx) onNavTap;
  final VoidCallback onProfile;

  const _GlassTopBar({
    required this.activeIndex,
    required this.hoverIndex,
    required this.onHover,
    required this.onLeave,
    required this.onNavTap,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
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
              SizedBox(
                width: 380,
                child: _TopTabs(
                  activeIndex: activeIndex,
                  hoverIndex: hoverIndex,
                  onHover: onHover,
                  onLeave: onLeave,
                  onTap: onNavTap,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: onProfile,
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
}

class _TopTabs extends StatelessWidget {
  final int activeIndex;
  final int? hoverIndex;
  final void Function(int? idx) onHover;
  final VoidCallback onLeave;
  final void Function(int idx) onTap;

  const _TopTabs({
    required this.activeIndex,
    required this.hoverIndex,
    required this.onHover,
    required this.onLeave,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labels = ["Home", "AI Studio", "Marketplace", "Settings"];
    final navCount = labels.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final segmentWidth = totalWidth / navCount;
        const indicatorWidth = 48.0;

        final underlineIndex = (hoverIndex ?? activeIndex).clamp(0, navCount - 1);
        final underlineLeft = underlineIndex * segmentWidth + (segmentWidth - indicatorWidth) / 2;

        return SizedBox(
          height: 34,
          child: Stack(
            children: [
              Row(
                children: List.generate(navCount, (index) {
                  final isActive = activeIndex == index;
                  final isHover = hoverIndex == index;
                  final effective = isActive || isHover;

                  return MouseRegion(
                    onEnter: (_) => onHover(index),
                    onExit: (_) => onHover(null),
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => onTap(index),
                      child: SizedBox(
                        width: segmentWidth,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 120),
                            style: TextStyle(
                              color: effective ? Colors.white : Colors.white.withOpacity(0.7),
                              fontWeight: effective ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 13.5,
                            ),
                            child: Text(labels[index]),
                          ),
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
}

// ──────────────────────────────────────────────────────────
// EDIT PROFILE POPUP (kept, just works with new background)
// ──────────────────────────────────────────────────────────
class _EditProfileDialog extends StatefulWidget {
  final String initialName;
  final String initialRole;
  final String initialBio;
  final Uint8List? initialAvatar;
  final Future<void> Function(String name, String role, String bio, Uint8List? avatarBytes) onSave;

  const _EditProfileDialog({
    required this.initialName,
    required this.initialRole,
    required this.initialBio,
    required this.initialAvatar,
    required this.onSave,
  });

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late TextEditingController _nameController;
  late TextEditingController _roleController;
  late TextEditingController _bioController;

  Uint8List? _avatarBytes;
  final ImagePicker _imagePicker = ImagePicker();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _roleController = TextEditingController(text: widget.initialRole);
    _bioController = TextEditingController(text: widget.initialBio);
    _avatarBytes = widget.initialAvatar;
  }

  Future<void> _pickAvatar() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false, type: FileType.image);
      if (result != null && result.files.single.bytes != null) {
        setState(() => _avatarBytes = result.files.single.bytes);
      }
    } else {
      final XFile? picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() => _avatarBytes = bytes);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width >= 900;
    final dialogWidth = isWeb ? 480.0 : MediaQuery.of(context).size.width - 40;

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Material(
            color: Colors.black.withOpacity(0.65),
            child: Container(
              width: dialogWidth,
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        "Edit Profile",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Column(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.10),
                            border: Border.all(color: Colors.white.withOpacity(0.22), width: 1.2),
                          ),
                          child: ClipOval(
                            child: _avatarBytes != null
                                ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                                : const Icon(Icons.person, size: 40, color: Colors.white54),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Tap to change profile picture",
                          style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  _fieldLabel("Display Name"),
                  const SizedBox(height: 6),
                  _glassTextField(_nameController, hint: "Your name"),

                  const SizedBox(height: 12),

                  _fieldLabel("Role / Title"),
                  const SizedBox(height: 6),
                  _glassTextField(_roleController, hint: "e.g. 3D Artist · Designer"),

                  const SizedBox(height: 12),

                  _fieldLabel("Bio"),
                  const SizedBox(height: 6),
                  _glassTextField(_bioController, hint: "Tell others about your work…", maxLines: 3),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                setState(() => _saving = true);
                                await widget.onSave(
                                  _nameController.text.trim().isEmpty ? widget.initialName : _nameController.text.trim(),
                                  _roleController.text.trim().isEmpty ? widget.initialRole : _roleController.text.trim(),
                                  _bioController.text.trim().isEmpty ? widget.initialBio : _bioController.text.trim(),
                                  _avatarBytes,
                                );
                                if (mounted) setState(() => _saving = false);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8A4FFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text("Save", style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _glassTextField(TextEditingController controller, {String? hint, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white54, fontSize: 12.5),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// BACKGROUND (same style as AI chat / explore)
// ──────────────────────────────────────────────────────────
class ParticleMeshBackground extends StatelessWidget {
  const ParticleMeshBackground({super.key});

  @override
  Widget build(BuildContext context) => const RepaintBoundary(child: _ParticleMeshCore());
}

class _ParticleMeshCore extends StatefulWidget {
  const _ParticleMeshCore();

  @override
  State<_ParticleMeshCore> createState() => _ParticleMeshCoreState();
}

class _ParticleMeshCoreState extends State<_ParticleMeshCore> with SingleTickerProviderStateMixin {
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

    _ps = List.generate(target, (_) {
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
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFF0F1118),
          Color(0xFF141625),
          Color(0xFF0B0D14),
        ],
        stops: const [0.0, 0.55, 1.0],
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
  bool shouldRepaint(covariant _MeshPainter old) {
    return old.time != time ||
        old.size != size ||
        old.mouse != mouse ||
        old.hasMouse != hasMouse ||
        old.particles.length != particles.length;
  }
}
