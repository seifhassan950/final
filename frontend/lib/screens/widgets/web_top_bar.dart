import 'dart:ui';
import 'package:flutter/material.dart';

class WebTopBar extends StatefulWidget {
  /// activeIndex:
  /// 0 = Home, 1 = AI Studio, 2 = Marketplace, 3 = Settings
  final int activeIndex;

  /// Optional avatar image
  final ImageProvider? avatar;

  const WebTopBar({
    super.key,
    required this.activeIndex,
    this.avatar,
  });

  @override
  State<WebTopBar> createState() => _WebTopBarState();
}

class _WebTopBarState extends State<WebTopBar> {
  int? hoverIndex;
  bool showProfileMenu = false;

  @override
  Widget build(BuildContext context) {
    final tabs = ["Home", "AI Studio", "Marketplace", "Settings"];

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              // LOGO
              const Icon(Icons.auto_awesome_rounded,
                  size: 26, color: Color(0xFFBC70FF)),
              const SizedBox(width: 8),

              const Text(
                "R2V Studio",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const Spacer(),

              // NAVIGATION TABS WITH UNDERLINE
              SizedBox(
                width: 400,
                height: 38,
                child: _navTabs(tabs),
              ),

              const SizedBox(width: 20),

              // Notifications icon
              _notificationButton(),

              const SizedBox(width: 16),

              // Profile Avatar
              _profileAvatar(context),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // NAVIGATION TABS
  // ──────────────────────────────────────────────────────────────

  Widget _navTabs(List<String> tabs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = constraints.maxWidth / tabs.length;
        const underlineWidth = 48.0;

        final active = hoverIndex ?? widget.activeIndex;

        final underlineLeft =
            active * segmentWidth + (segmentWidth - underlineWidth) / 2;

        return Stack(
          children: [
            // Tab labels
            Row(
              children: List.generate(tabs.length, (i) {
                final bool highlight =
                    (hoverIndex == i) || (widget.activeIndex == i);

                return MouseRegion(
                  onEnter: (_) => setState(() => hoverIndex = i),
                  onExit: (_) => setState(() => hoverIndex = null),
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _navigate(i),
                    child: SizedBox(
                      width: segmentWidth,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 130),
                          style: TextStyle(
                            color: highlight
                                ? Colors.white
                                : Colors.white.withOpacity(0.7),
                            fontWeight:
                                highlight ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 13.5,
                          ),
                          child: Text(tabs[i]),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),

            // Underline animation
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              left: underlineLeft,
              bottom: 0,
              child: Container(
                width: underlineWidth,
                height: 2,
                decoration: BoxDecoration(
                  color: const Color(0xFFBC70FF),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  // NOTIFICATION ICON
  // ──────────────────────────────────────────────────────────────

  Widget _notificationButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.notifications_none_rounded,
            color: Colors.white, size: 20),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // PROFILE AVATAR + POPUP MENU
  // ──────────────────────────────────────────────────────────────

  Widget _profileAvatar(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => showProfileMenu = !showProfileMenu),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.4)),
              image: DecorationImage(
                fit: BoxFit.cover,
                image: widget.avatar ??
                    const AssetImage("assets/R2Vlogo.png"),
              ),
            ),
          ),
        ),

        if (showProfileMenu)
          Positioned(
            right: 0,
            top: 48,
            child: _profileMenu(context),
          ),
      ],
    );
  }

  Widget _profileMenu(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: 170,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _menuItem(Icons.person, "View Profile", () {
                Navigator.pushNamed(context, "/profile");
              }),
              _menuItem(Icons.settings, "Settings", () {
                Navigator.pushNamed(context, "/settings");
              }),
              _menuItem(Icons.logout_rounded, "Logout", () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.white.withOpacity(0.05),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white70),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // ROUTING
  // ──────────────────────────────────────────────────────────────

  void _navigate(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, "/home");
        break;
      case 1:
        Navigator.pushReplacementNamed(context, "/aichat");
        break;
      case 2:
        Navigator.pushReplacementNamed(context, "/explore");
        break;
      case 3:
        Navigator.pushReplacementNamed(context, "/settings");
        break;
    }
  }
}
