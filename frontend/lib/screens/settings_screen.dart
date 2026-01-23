import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/r2v_api.dart';
import '../api/api_exception.dart';
import 'widgets/web_top_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Selected setting panel
  // 0 = Account, 1 = Privacy, 2 = Notifications, 3 = Appearance, 4 = Subscription
  int selectedSection = 0;

  bool darkMode = false;
  bool notifyAI = true;
  bool notifyUpdates = true;

  bool _loadingProfile = false;
  bool _savingProfile = false;
  String? _profileError;
  Map<String, dynamic> _profileMeta = {};

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final bool isWeb = w >= 900;

    return Stack(
      children: [
        const Positioned.fill(child: _SettingsBackground()),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: isWeb ? _buildWebLayout() : _buildMobileLayout(),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 🖥 WEB SETTINGS LAYOUT
  // ---------------------------------------------------------------------------
  Widget _buildWebLayout() {
    final double w = MediaQuery.of(context).size.width;
    final double contentWidth = w > 1200 ? 1200 : w;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentWidth),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const WebTopBar(activeIndex: 3),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSidebar(),
                  const SizedBox(width: 24),
                  Expanded(child: _buildRightPanelCard()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 📱 MOBILE SETTINGS LAYOUT
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _mobileHeader(),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: _buildRightPanelCard(),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // LEFT SIDEBAR (WEB ONLY)
  // ---------------------------------------------------------------------------
  Widget _buildSidebar() {
    return _glassPanel(
      width: 270,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Settings",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Manage your account preferences",
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 26),
          _sideTab("Account", Icons.person, 0),
          const SizedBox(height: 16),
          _sideTab("Privacy", Icons.lock, 1),
          const SizedBox(height: 16),
          _sideTab("Notifications", Icons.notifications, 2),
          const SizedBox(height: 16),
          _sideTab("Appearance", Icons.color_lens, 3),
          const SizedBox(height: 16),
          _sideTab("Subscription & Billing", Icons.credit_card, 4),
          const Spacer(),
          _staticAction(
            label: "Logout",
            icon: Icons.logout_rounded,
            color: Colors.orange,
            onTap: _logout,
          ),
          const SizedBox(height: 12),
          _staticAction(
            label: "Delete Account",
            icon: Icons.delete_forever,
            color: Colors.red,
            onTap: _showDeleteDialog,
          ),
        ],
      ),
    );
  }

  Widget _sideTab(String text, IconData icon, int index) {
    final bool active = selectedSection == index;

    return GestureDetector(
      onTap: () => setState(() => selectedSection = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? Colors.white.withOpacity(0.18) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: active ? const Color(0xFFBC70FF) : Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                color: active ? Colors.white : Colors.white70,
                fontSize: 14.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _staticAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.15),
          border: Border.all(color: color.withOpacity(0.7)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RIGHT PANEL
  // ---------------------------------------------------------------------------
  Widget _buildRightPanel() {
    switch (selectedSection) {
      case 0:
        return _buildAccountSection();
      case 1:
        return _buildPrivacySection();
      case 2:
        return _buildNotificationSection();
      case 3:
        return _buildAppearanceSection();
      case 4:
        return _buildSubscriptionSection();
      default:
        return _buildAccountSection();
    }
  }

  // ---------------------------------------------------------------------------
  // SECTIONS
  // ---------------------------------------------------------------------------
  Widget _buildAccountSection() {
    return _sectionWrapper(
      title: "Account Settings",
      subtitle: "Update your profile information and contact details.",
      children: [
        if (_loadingProfile)
          _infoBanner(
            icon: Icons.hourglass_bottom,
            message: "Loading profile details...",
          ),
        if (_profileError != null)
          _infoBanner(
            icon: Icons.info_outline,
            message: _profileError!,
          ),
        _glassTextField(
          controller: _usernameController,
          label: "Display name",
          hint: "Your public profile name",
          icon: Icons.person_outline,
          enabled: !_savingProfile && !_loadingProfile,
        ),
        const SizedBox(height: 16),
        _glassTextField(
          controller: _emailController,
          label: "Email",
          hint: "Email address",
          icon: Icons.email_outlined,
          enabled: false,
        ),
        const SizedBox(height: 16),
        _glassTextField(
          controller: _phoneController,
          label: "Phone",
          hint: "Add a phone for recovery",
          icon: Icons.phone_outlined,
          enabled: !_savingProfile && !_loadingProfile,
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _savingProfile ? null : _saveProfile,
            icon: _savingProfile
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_savingProfile ? "Saving..." : "Save changes"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBC70FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return _sectionWrapper(
      title: "Privacy Settings",
      subtitle: "Keep your account secure with quick actions.",
      children: [
        _actionTile(
          icon: Icons.lock_reset,
          title: "Reset password",
          subtitle: "Send a reset email to secure your account.",
          actionLabel: "Send email",
          onTap: () => Navigator.pushNamed(context, '/forgot'),
        ),
        const SizedBox(height: 16),
        _actionTile(
          icon: Icons.shield_outlined,
          title: "Two-factor authentication",
          subtitle: "Add an extra layer of protection to your login.",
          actionLabel: "Coming soon",
          onTap: null,
        ),
      ],
    );
  }

  Widget _buildNotificationSection() {
    return _sectionWrapper(
      title: "Notifications",
      subtitle: "Pick what you want to hear about.",
      children: [
        _switchTile(
          label: "AI model ready",
          description: "Get alerted when your generation finishes.",
          value: notifyAI,
          onChanged: (v) => setState(() => notifyAI = v),
        ),
        const SizedBox(height: 12),
        _switchTile(
          label: "App updates",
          description: "Product news and new feature highlights.",
          value: notifyUpdates,
          onChanged: (v) => setState(() => notifyUpdates = v),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection() {
    return _sectionWrapper(
      title: "Appearance",
      subtitle: "Tune the look and feel to your taste.",
      children: [
        _switchTile(
          label: "Dark mode",
          description: "Switch between light and dark ambiance.",
          value: darkMode,
          onChanged: (v) => setState(() => darkMode = v),
        ),
        const SizedBox(height: 16),
        _actionTile(
          icon: Icons.palette_outlined,
          title: "Theme accent",
          subtitle: "Customize your highlight color.",
          actionLabel: "Default",
          onTap: null,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 💳 SUBSCRIPTION & BILLING SECTION
  // ---------------------------------------------------------------------------
  Widget _buildSubscriptionSection() {
    return _sectionWrapper(
      title: "Subscription & Billing",
      subtitle: "Manage your plan and payment preferences.",
      children: [
        _subscriptionSummaryCard(),
        const SizedBox(height: 18),
        _paymentMethodCard(),
        const SizedBox(height: 18),
        _billingNoteCard(),
      ],
    );
  }

  Widget _subscriptionSummaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF8A4FFF),
            Color(0xFFBC70FF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A4FFF).withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Current Plan",
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                SizedBox(height: 4),
                Text(
                  "R2V Pro – Monthly",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "\$14.99 / month · Renews on Jan 20, 2026",
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final url = await r2vBilling.checkoutSubscription();
                if (url.isEmpty) {
                  throw Exception('Missing checkout url');
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
                  const SnackBar(content: Text('Unable to open checkout')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF8A4FFF),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text("Manage Plan"),
          ),
        ],
      ),
    );
  }

  Widget _paymentMethodCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFF4895EF), Color(0xFF4CC9F0)],
              ),
            ),
            child: const Icon(Icons.credit_card, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Payment Method",
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                SizedBox(height: 4),
                Text("Visa •••• 4821",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                final url = await r2vBilling.checkoutSubscription();
                if (url.isEmpty) {
                  throw Exception('Missing checkout url');
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
                  const SnackBar(content: Text('Unable to open checkout')),
                );
              }
            },
            child: const Text(
              "Change",
              style: TextStyle(
                color: Color(0xFF4CC9F0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _billingNoteCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline, color: Colors.white70),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Billing history and invoices will appear here in a future update.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED COMPONENTS
  // ---------------------------------------------------------------------------
  Widget _sectionWrapper({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );
  }

  Widget _glassTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        filled: true,
        fillColor: Colors.white.withOpacity(enabled ? 0.06 : 0.04),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFBC70FF), width: 1.4),
        ),
      ),
    );
  }

  Widget _switchTile({
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        color: Colors.white.withOpacity(0.05),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12.5),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFBC70FF),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        color: Colors.white.withOpacity(0.05),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.12),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14.5)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12.5),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(
              actionLabel,
              style: TextStyle(
                color: onTap == null ? Colors.white38 : const Color(0xFFBC70FF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBanner({required IconData icon, required String message}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanelCard() {
    return _glassPanel(
      padding: EdgeInsets.zero,
      child: _buildRightPanel(),
    );
  }

  Widget _glassPanel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(24),
    double? width,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.42),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _mobileHeader() {
    return _glassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          const Icon(Icons.settings, color: Color(0xFFBC70FF)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Settings",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            icon: const Icon(Icons.home_outlined, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await r2vAuth.logout();
    } catch (_) {
      // ignore logout errors; we'll still navigate away
    }
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/signin');
  }

  // DELETE ACCOUNT POPUP
  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1B20),
        title: const Text(
          "Delete Account",
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          "This action is permanent and cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              try {
                await r2vProfile.deleteAccount();
                await r2vAuth.logout();
              } on ApiException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message)),
                );
                return;
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to delete account')),
                );
                return;
              }
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/signin');
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });

    try {
      final data = await r2vProfile.me();
      if (!mounted) return;
      setState(() {
        _usernameController.text = data.username;
        _emailController.text = data.email;
        _profileMeta = Map<String, dynamic>.from(data.meta);
        _phoneController.text = _profileMeta['phone']?.toString() ?? '';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _profileError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _profileError = 'Unable to load profile settings');
    } finally {
      if (mounted) {
        setState(() => _loadingProfile = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _savingProfile = true;
      _profileError = null;
    });

    try {
      final username = _usernameController.text.trim();
      final phone = _phoneController.text.trim();
      final updatedMeta = Map<String, dynamic>.from(_profileMeta);
      if (phone.isEmpty) {
        updatedMeta.remove('phone');
      } else {
        updatedMeta['phone'] = phone;
      }

      final data = await r2vProfile.update(
        username: username.isEmpty ? null : username,
        meta: updatedMeta,
      );
      if (!mounted) return;
      setState(() {
        _profileMeta = Map<String, dynamic>.from(data.meta);
        _usernameController.text = data.username;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings updated successfully')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _profileError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _profileError = 'Unable to save settings');
    } finally {
      if (mounted) {
        setState(() => _savingProfile = false);
      }
    }
  }
}

class _SettingsBackground extends StatelessWidget {
  const _SettingsBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF090A0F),
            Color(0xFF1A1031),
            Color(0xFF120B1E),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -60,
            child: _GlowOrb(color: Color(0xFF8A4FFF), size: 260),
          ),
          Positioned(
            bottom: -140,
            left: -40,
            child: _GlowOrb(color: Color(0xFF4CC9F0), size: 280),
          ),
          Positioned(
            top: 140,
            left: 80,
            child: _GlowOrb(color: Color(0xFFF72585), size: 180),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.55),
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}
