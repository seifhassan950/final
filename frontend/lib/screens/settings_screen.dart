import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/r2v_api.dart';
import '../api/api_exception.dart';

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

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final bool isWeb = w >= 900;

    // ⭐ The new floating button wrapper
    return Scaffold(
      backgroundColor: const Color(0xFF21222A),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF8A4FFF),
        splashColor: const Color(0xFFBC70FF),
        onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
        child: const Icon(Icons.home_rounded, color: Colors.white),
      ),

      body: isWeb ? _buildWebLayout() : _buildMobileLayout(),
    );
  }

  // ---------------------------------------------------------------------------
  // 🖥 WEB SETTINGS LAYOUT
  // ---------------------------------------------------------------------------
  Widget _buildWebLayout() {
    return Row(
      children: [
        _buildSidebar(), // LEFT
        Expanded(child: _buildRightPanel()), // RIGHT
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 📱 MOBILE SETTINGS LAYOUT
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: _buildRightPanel(),
    );
  }

  // ---------------------------------------------------------------------------
  // LEFT SIDEBAR (WEB ONLY)
  // ---------------------------------------------------------------------------
  Widget _buildSidebar() {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF191A21).withOpacity(0.6),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
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
          const SizedBox(height: 30),

          _sideTab("Account", Icons.person, 0),
          const SizedBox(height: 18),
          _sideTab("Privacy", Icons.lock, 1),
          const SizedBox(height: 18),
          _sideTab("Notifications", Icons.notifications, 2),
          const SizedBox(height: 18),
          _sideTab("Appearance", Icons.color_lens, 3),
          const SizedBox(height: 18),
          _sideTab("Subscription & Billing", Icons.credit_card, 4),

          const Spacer(),

          // ALWAYS VISIBLE BUTTONS
          _staticAction(
            label: "Logout",
            icon: Icons.logout_rounded,
            color: Colors.orange,
            onTap: _logout,
          ),
          const SizedBox(height: 14),
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
      children: [
        _glassField("Change Username", enabled: true),
        const SizedBox(height: 16),
        _glassField("Change Email (Disabled)", enabled: false),
        const SizedBox(height: 16),
        _glassField("Change Phone (Disabled)", enabled: false),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return _sectionWrapper(
      title: "Privacy Settings",
      children: [
        _glassField("Password Reset", enabled: true),
        const SizedBox(height: 16),
        _glassField("Two-Factor Authentication (coming soon)", enabled: false),
      ],
    );
  }

  Widget _buildNotificationSection() {
    return _sectionWrapper(
      title: "Notifications",
      children: [
        _switchTile("AI Model Ready", notifyAI, (v) {
          setState(() => notifyAI = v);
        }),
        _switchTile("App Updates", notifyUpdates, (v) {
          setState(() => notifyUpdates = v);
        }),
      ],
    );
  }

  Widget _buildAppearanceSection() {
    return _sectionWrapper(
      title: "Appearance",
      children: [
        _switchTile("Dark Mode", darkMode, (v) {
          setState(() => darkMode = v);
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 💳 SUBSCRIPTION & BILLING SECTION
  // ---------------------------------------------------------------------------
  Widget _buildSubscriptionSection() {
    return _sectionWrapper(
      title: "Subscription & Billing",
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
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8A4FFF),
            const Color(0xFFBC70FF),
          ],
        ),
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
    required List<Widget> children,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 60),
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
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );
  }

  Widget _glassField(String label, {bool enabled = true}) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
          color: Colors.white.withOpacity(0.06),
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.white)),
            const Spacer(),
            Icon(
              enabled ? Icons.edit : Icons.lock,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchTile(String label, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFFBC70FF),
        ),
      ],
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
}
