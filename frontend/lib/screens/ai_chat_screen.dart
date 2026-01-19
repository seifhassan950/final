import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../api/r2v_api.dart';
import '../api/api_exception.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Enter handling on web
  final FocusNode _keyboardFocus = FocusNode();
  bool _enterHandled = false;

  PlatformFile? uploadedImage;
  bool _isTyping = false;

  // Top nav underline / hover state
  int _activeIndex = 1; // AI Studio
  int? _hoverIndex;

  // Sidebar search
  final TextEditingController _chatSearchController = TextEditingController();
  String _chatSearch = "";

  // Conversations (history)
  final List<_Conversation> _conversations = [
    _Conversation(id: "c1", title: "New chat"),
  ];
  String _activeConversationId = "c1";

  _Conversation get _activeConversation =>
      _conversations.firstWhere((c) => c.id == _activeConversationId);

  List<_Conversation> get _filteredConversations {
    final q = _chatSearch.trim().toLowerCase();
    if (q.isEmpty) return _conversations;
    return _conversations.where((c) => c.title.toLowerCase().contains(q)).toList();
    // (Optional: you can also search inside messages)
  }

  void _newChat() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _conversations.insert(0, _Conversation(id: id, title: "New chat"));
      _activeConversationId = id;
      _isTyping = false;
      uploadedImage = null;
      _controller.clear();
    });
    _scrollToBottom();
  }

  void _selectChat(String id) {
    setState(() {
      _activeConversationId = id;
      _isTyping = false;
      uploadedImage = null;
      _controller.clear();
    });
    _scrollToBottom();
  }

  void _deleteChat(String id) {
    if (_conversations.length <= 1) {
      // always keep at least 1 chat
      setState(() {
        _conversations[0]
          ..title = "New chat"
          ..messages.clear();
        _activeConversationId = _conversations[0].id;
        _isTyping = false;
        uploadedImage = null;
        _controller.clear();
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      final wasActive = id == _activeConversationId;
      _conversations.removeWhere((c) => c.id == id);

      if (wasActive) {
        _activeConversationId = _conversations.first.id;
        _isTyping = false;
        uploadedImage = null;
        _controller.clear();
      }
    });
    _scrollToBottom();
  }

  Future<void> _renameChat(String id) async {
    final conv = _conversations.firstWhere((c) => c.id == id);
    final tc = TextEditingController(text: conv.title == "New chat" ? "" : conv.title);

    final newTitle = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0B0D14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Rename chat", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: tc,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Enter a title",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFBC70FF)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel", style: TextStyle(color: Colors.white.withOpacity(0.8))),
            ),
            ElevatedButton(
              onPressed: () {
                final v = tc.text.trim();
                Navigator.pop(ctx, v.isEmpty ? null : v);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8A4FFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (newTitle == null) return;

    setState(() {
      conv.title = newTitle;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 220,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty && uploadedImage == null) return;

    final image = uploadedImage;
    setState(() {
      _activeConversation.messages.add(
        _ChatMessage(text.isEmpty ? "[Image Uploaded]" : text, uploadedImage, true),
      );

      // Set title from first user prompt (ChatGPT-like)
      final conv = _activeConversation;
      if (conv.title == "New chat" && text.isNotEmpty) {
        conv.title = text.length > 28 ? "${text.substring(0, 28)}…" : text;
      }

      _controller.clear();
      uploadedImage = null;
      _isTyping = true;
    });

    _scrollToBottom();

    final prompt = text.isEmpty ? "Image upload" : text;
    final settings = <String, dynamic>{};
    final bytes = image?.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      settings['image_filename'] = image?.name ?? 'upload.png';
      settings['image_base64'] = base64Encode(bytes);
    }

    try {
      final job = await r2vAiJobs.createJob(prompt: prompt, settings: settings);
      await _animateTyping(
        "Job queued: ${job.id}\nStatus: ${job.status}\nWe'll notify you when it's ready.",
      );
    } on ApiException catch (e) {
      await _animateTyping("Failed to create job: ${e.message}");
    } catch (_) {
      await _animateTyping("Failed to create job. Please try again.");
    }
  }

  Future<void> _animateTyping(String text) async {
    String current = "";
    setState(() => _activeConversation.messages.add(_ChatMessage("", null, false)));

    for (int i = 0; i < text.length; i++) {
      await Future.delayed(const Duration(milliseconds: 7));
      if (!mounted) return;
      setState(() {
        current += text[i];
        _activeConversation.messages.last.text = current;
      });
      _scrollToBottom();
    }

    if (mounted) setState(() => _isTyping = false);
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null) {
      setState(() => uploadedImage = result.files.first);
      _sendMessage();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _keyboardFocus.dispose();
    _chatSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Stack(
      children: [
        const Positioned.fill(child: ParticleMeshBackground()),
        Positioned.fill(
          child: isWide ? _buildWide(context) : _buildMobile(context),
        ),
      ],
    );
  }

  // =============================================================================
  // WIDE (WEB/DESKTOP)
  // =============================================================================
  Widget _buildWide(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final double rightMaxWidth = w > 1500 ? 1500 : w;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // TOP BAR FULL WIDTH
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: _GlassTopBar(
                activeIndex: _activeIndex,
                hoverIndex: _hoverIndex,
                onHover: (v) => setState(() => _hoverIndex = v),
                onLeave: () => setState(() => _hoverIndex = null),
                onNavTap: (idx) {
                  setState(() => _activeIndex = idx);
                  switch (idx) {
                    case 0:
                      Navigator.pushNamed(context, '/home'); // ✅ FIX: go to real home route
                      break;
                    case 1:
                      break; // already AI Studio
                    case 2:
                      Navigator.pushNamed(context, '/explore');
                      break;
                    case 3:
                      Navigator.pushNamed(context, '/settings');
                      break;
                  }
                },
                onProfile: () => Navigator.pushNamed(context, '/profile'),
              ),
            ),

            // BELOW TOP BAR
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 310,
                      child: _LeftChatSidebar(
                        conversations: _filteredConversations,
                        activeId: _activeConversationId,
                        onNewChat: _newChat,
                        onSelect: _selectChat,
                        // NEW:
                        searchController: _chatSearchController,
                        onSearchChanged: (v) => setState(() => _chatSearch = v),
                        onRename: _renameChat,
                        onDelete: _deleteChat,
                        onUserMenu: (action) {
                          switch (action) {
                            case _UserMenuAction.profile:
                              Navigator.pushNamed(context, '/profile');
                              break;
                            case _UserMenuAction.settings:
                              Navigator.pushNamed(context, '/settings');
                              break;
                            case _UserMenuAction.newChat:
                              _newChat();
                              break;
                          }
                        },
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: rightMaxWidth),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: _ChatPanel(
                                        messages: _activeConversation.messages,
                                        controller: _scrollController,
                                        isTyping: _isTyping,
                                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 96),
                                      ),
                                    ),
                                    Positioned(
                                      left: 14,
                                      right: 14,
                                      bottom: 14,
                                      child: _inputBar(),
                                    ),
                                  ],
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
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================================
  // MOBILE
  // =============================================================================
  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          _activeConversation.title == "New chat" ? "AI Studio" : _activeConversation.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.black.withOpacity(0.15),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "New chat",
            onPressed: _newChat,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _ChatPanel(
              messages: _activeConversation.messages,
              controller: _scrollController,
              isTyping: _isTyping,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: _inputBar(),
          ),
        ],
      ),
    );
  }

  // =============================================================================
  // INPUT BAR
  // =============================================================================
  Widget _inputBar() {
    return RawKeyboardListener(
      focusNode: _keyboardFocus,
      onKey: (event) {
        if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
          if (_enterHandled) return;
          _enterHandled = true;

          if (event.isShiftPressed) {
            final text = _controller.text;
            final newText = "$text\n";
            _controller.text = newText;
            _controller.selection = TextSelection.fromPosition(TextPosition(offset: newText.length));
          } else {
            _sendMessage();
          }
        }

        if (event is RawKeyUpEvent && event.logicalKey == LogicalKeyboardKey.enter) {
          _enterHandled = false;
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.22),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: const Icon(Icons.image_rounded, color: Color(0xFFBC70FF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Type a prompt or upload an image...",
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF8A4FFF), Color(0xFFBC70FF)],
                      ),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MODELS
// ============================================================================
class _Conversation {
  final String id;
  String title;
  final List<_ChatMessage> messages;

  _Conversation({required this.id, required this.title, List<_ChatMessage>? messages})
      : messages = messages ?? [];
}

class _ChatMessage {
  String text;
  final PlatformFile? image;
  final bool isUser;

  _ChatMessage(this.text, this.image, this.isUser);
}

// ============================================================================
// TOP BAR
// ============================================================================
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

// ============================================================================
// LEFT SIDEBAR (Search + tiles + menus)
// ============================================================================
enum _ChatMenuAction { rename, delete }
enum _UserMenuAction { profile, settings, newChat }

class _LeftChatSidebar extends StatelessWidget {
  final List<_Conversation> conversations;
  final String activeId;
  final VoidCallback onNewChat;
  final void Function(String id) onSelect;

  final TextEditingController searchController;
  final void Function(String text) onSearchChanged;

  final Future<void> Function(String id) onRename;
  final void Function(String id) onDelete;

  final void Function(_UserMenuAction action) onUserMenu;

  const _LeftChatSidebar({
    required this.conversations,
    required this.activeId,
    required this.onNewChat,
    required this.onSelect,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRename,
    required this.onDelete,
    required this.onUserMenu,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B0D14).withOpacity(0.55),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 14),

              // New chat
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: onNewChat,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text("New chat"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8A4FFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ✅ SEARCH (WORKING)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.6), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          onChanged: onSearchChanged,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: "Search chats",
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13),
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                        ),
                      ),
                      if (searchController.text.trim().isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            searchController.clear();
                            onSearchChanged("");
                            FocusScope.of(context).unfocus();
                          },
                          child: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.7), size: 18),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),
              Divider(color: Colors.white.withOpacity(0.10), height: 1),

              // History list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  itemCount: conversations.length,
                  itemBuilder: (context, i) {
                    final c = conversations[i];
                    final active = c.id == activeId;

                    return _ChatHistoryTile(
                      title: c.title,
                      active: active,
                      onTap: () => onSelect(c.id),
                      // ✅ 3-dots per chat (WORKING)
                      onMenu: (action) async {
                        switch (action) {
                          case _ChatMenuAction.rename:
                            await onRename(c.id);
                            break;
                          case _ChatMenuAction.delete:
                            onDelete(c.id);
                            break;
                        }
                      },
                    );
                  },
                ),
              ),

              Divider(color: Colors.white.withOpacity(0.10), height: 1),

              // Bottom user area + ✅ 3-dots user menu (WORKING)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.10)),
                      ),
                      child: const Icon(Icons.person, color: Colors.white70, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "R2V User",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    PopupMenuButton<_UserMenuAction>(
                      tooltip: "More",
                      color: const Color(0xFF0B0D14),
                      icon: Icon(Icons.more_horiz_rounded, color: Colors.white.withOpacity(0.75)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      onSelected: onUserMenu,
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: _UserMenuAction.profile,
                          child: _MenuRow(icon: Icons.person_outline_rounded, label: "Profile"),
                        ),
                        PopupMenuItem(
                          value: _UserMenuAction.settings,
                          child: _MenuRow(icon: Icons.settings_outlined, label: "Settings"),
                        ),
                        PopupMenuDivider(),
                        PopupMenuItem(
                          value: _UserMenuAction.newChat,
                          child: _MenuRow(icon: Icons.add_rounded, label: "New chat"),
                        ),
                      ],
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

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.85), size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}

class _ChatHistoryTile extends StatelessWidget {
  final String title;
  final bool active;
  final VoidCallback onTap;
  final void Function(_ChatMenuAction action) onMenu;

  const _ChatHistoryTile({
    required this.title,
    required this.active,
    required this.onTap,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? Colors.white.withOpacity(0.14) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.white.withOpacity(active ? 0.85 : 0.55),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(active ? 0.92 : 0.70),
                  fontSize: 13.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 6),
            PopupMenuButton<_ChatMenuAction>(
              tooltip: "Chat options",
              color: const Color(0xFF0B0D14),
              icon: Icon(Icons.more_vert_rounded, color: Colors.white.withOpacity(0.70), size: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: onMenu,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _ChatMenuAction.rename,
                  child: _MenuRow(icon: Icons.edit_rounded, label: "Rename"),
                ),
                PopupMenuItem(
                  value: _ChatMenuAction.delete,
                  child: _MenuRow(icon: Icons.delete_outline_rounded, label: "Delete"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CHAT PANEL + BUBBLES
// ============================================================================
class _ChatPanel extends StatelessWidget {
  final List<_ChatMessage> messages;
  final ScrollController controller;
  final bool isTyping;
  final EdgeInsets? padding;

  const _ChatPanel({
    required this.messages,
    required this.controller,
    required this.isTyping,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: padding ?? const EdgeInsets.fromLTRB(20, 18, 20, 18),
      itemCount: messages.length + (isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (isTyping && index == messages.length) {
          return const Align(alignment: Alignment.centerLeft, child: _TypingBubble());
        }

        final msg = messages[index];
        return Align(
          alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: _ChatBubble(message: msg),
        );
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(maxWidth: 560),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: isUser
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8A4FFF), Color(0xFFBC70FF)],
              )
            : null,
        color: isUser ? null : Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(isUser ? 0.14 : 0.10)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            color: Colors.black.withOpacity(0.25),
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.image != null && (message.image!.bytes?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  message.image!.bytes!,
                  height: 170,
                  width: 320,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Text(
            message.text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.96),
              fontSize: 14.5,
              height: 1.35,
              fontWeight: isUser ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final a = (sin(t * pi * 2) * 0.5 + 0.5);
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dot(opacity: 0.25 + 0.55 * a),
              const SizedBox(width: 6),
              _dot(opacity: 0.25 + 0.55 * (1 - a)),
              const SizedBox(width: 6),
              _dot(opacity: 0.25 + 0.55 * a),
              const SizedBox(width: 10),
              Text("Typing...", style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13)),
            ],
          ),
        );
      },
    );
  }

  Widget _dot({required double opacity}) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: Colors.white.withOpacity(opacity), shape: BoxShape.circle),
    );
  }
}

// ============================================================================
// BACKGROUND (mesh particles)
// ============================================================================
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
