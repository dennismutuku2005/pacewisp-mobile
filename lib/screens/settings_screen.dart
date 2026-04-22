import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import '../services/lock_service.dart';
import 'webview_screen.dart';
import '../components/otp_modal.dart';
import '../components/badge.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _nameController = TextEditingController(text: settings.accountName);
    _phoneController = TextEditingController(text: settings.activeAccount?.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdateProfile({String? otp}) async {
    setState(() => _isSaving = true);
    try {
      final payload = {
        'name': _nameController.text,
        'phone': _phoneController.text,
      };
      if (otp != null) payload['otp_code'] = otp;

      final res = await _apiService.updateStaff('me', payload); // Assuming API supports 'me' or profile update endpoint

      if (res?['status'] == 'otp_required') {
        _showOtpModal((code) => _handleUpdateProfile(otp: code));
      } else if (res?['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Profile updated'), backgroundColor: PaceColors.emerald));
          // Refresh settings provider if needed
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Update failed'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showOtpModal(Function(String) onVerify) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OtpModal(
        phoneNumber: _phoneController.text,
        onVerify: (code) {
          Navigator.pop(context);
          onVerify(code);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 24),
          _buildProfileCard(settings, isDark),
          const SizedBox(height: 32),
          
          _buildSectionTitle('PROFILE INFORMATION', isDark),
          _buildProfileFields(isDark),
          const SizedBox(height: 16),
          _buildSaveButton(),
          const SizedBox(height: 48),

          _buildSectionTitle('SWITCH INSTANCE', isDark),
          _buildSettingGroup(
            isDark,
            [
              ...settings.accounts.asMap().entries.map((entry) {
                final index = entry.key;
                final acc = entry.value;
                final isActive = settings.activeAccount?.subdomain == acc.subdomain && settings.activeAccount?.domain == acc.domain;
                
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("${acc.subdomain}.${acc.domain}", style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark), letterSpacing: 0.5)),
                  subtitle: Text(acc.accountName.toUpperCase(), style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  trailing: isActive ? const Icon(LucideIcons.checkCircle2, color: PaceColors.purple, size: 22) : null,
                  onTap: () => settings.switchAccount(index),
                );
              }),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.link, color: PaceColors.purple, size: 20),
                title: Text('ADD NEW INSTANCE', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
              ),
            ],
          ),
          
          const Divider(height: 64),
          _buildSectionTitle('HOME WIDGET CONFIGURATION', isDark),
          _buildSettingGroup(
            isDark,
            [
              _buildWidgetAccountTile(context, settings, isDark),
              _buildSwitchTile('WIDGET BLUR', 'HIDE DATA ON WIDGET BY DEFAULT', LucideIcons.eyeOff, settings.isWidgetBlurred, (val) => settings.toggleWidgetBlur(), isDark, Colors.blueGrey),
            ],
          ),
          
          const Divider(height: 64),
          _buildSectionTitle('APPEARANCE & SECURITY', isDark),
          _buildSettingGroup(
            isDark,
            [
              _buildSwitchTile('DARK MODE', 'ADAPTIVE VISUAL INTERFACE', LucideIcons.moon, settings.isDarkMode, (val) => settings.toggleDarkMode(), isDark, Colors.blueGrey),
              _buildSwitchTile('SYSTEM APP LOCK', 'SECURE WITH BIOMETRICS', LucideIcons.fingerprint, settings.isAppLockEnabled, (val) async {
                  final success = await LockService().authenticate();
                  if (success) settings.toggleAppLock(val);
              }, isDark, Colors.blueGrey),
            ],
          ),
          
          const Divider(height: 64),
          _buildSectionTitle('LEGAL & POLICIES', isDark),
          _buildSettingGroup(
            isDark,
            [
              _buildActionTile('TERMS & CONDITIONS', 'User agreements', LucideIcons.gavel, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WebViewScreen(title: 'Terms of Service', url: 'https://pacewisp.co.ke/terms/')));
              }, isDark, Colors.blueGrey),
              _buildActionTile('PRIVACY POLICY', 'Data protection', LucideIcons.shieldCheck, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WebViewScreen(title: 'Privacy Policy', url: 'https://pacewisp.co.ke/privacy/')));
              }, isDark, Colors.blueGrey),
            ],
          ),

          const Divider(height: 64),
          _buildSectionTitle('BUILD INFORMATION', isDark),
          _buildReadOnlyTile('VERSION', '1.2.8 ENTERPRISE STABLE', isDark),
          _buildReadOnlyTile('SYSTEM STATUS', 'CORE API ONLINE', isDark, valueColor: PaceColors.emerald),
          const SizedBox(height: 48),
          
          _buildLogoutButton(settings, isDark),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PREFERENCES', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
        Text('MANAGE CORE ACCOUNTS & SYSTEM BEHAVIOR', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ],
    );
  }

  Widget _buildProfileCard(SettingsProvider settings, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: [PaceColors.purple, PaceColors.purple.withOpacity(0.6)], begin: Alignment.bottomLeft, end: Alignment.topRight),
        boxShadow: [BoxShadow(color: PaceColors.purple.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 30, backgroundColor: Colors.white.withOpacity(0.2), child: Text(settings.accountName?.substring(0, 2).toUpperCase() ?? 'AD', style: GoogleFonts.figtree(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(settings.accountName?.toUpperCase() ?? 'ADMINISTRATOR', style: GoogleFonts.figtree(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                PaceBadge(label: 'VERIFIED ACCOUNT', variant: BadgeVariant.success),
              ])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileFields(bool isDark) {
    return Column(
      children: [
        _buildTextField('FULL NAME', _nameController, LucideIcons.user, isDark),
        const SizedBox(height: 16),
        _buildTextField('PHONE NUMBER', _phoneController, LucideIcons.phone, isDark),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.black, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark))),
          child: TextField(
            controller: controller,
            style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
            decoration: InputDecoration(icon: Icon(icon, size: 16, color: PaceColors.purple), border: InputBorder.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _handleUpdateProfile,
        style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: _isSaving 
          ? const CircularProgressIndicator(color: Colors.white) 
          : Text('SAVE PROFILE CHANGES', style: GoogleFonts.figtree(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white)),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.black, letterSpacing: 2)),
    );
  }

  Widget _buildSettingGroup(bool isDark, List<Widget> children) {
    return Column(children: children);
  }

  Widget _buildSwitchTile(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged, bool isDark, Color iconColor) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: PaceColors.purple, size: 22),
      title: Text(title, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
      subtitle: Text(subtitle, style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.white,
        activeTrackColor: PaceColors.emerald,
      ),
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, VoidCallback onTap, bool isDark, Color iconColor) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: PaceColors.purple, size: 22),
      title: Text(title, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
      subtitle: Text(subtitle, style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
      trailing: const Icon(LucideIcons.chevronRight, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildReadOnlyTile(String label, String value, bool isDark, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
          Text(value, style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900, color: valueColor ?? PaceColors.getPrimaryText(isDark))),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(SettingsProvider settings, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: TextButton.icon(
        onPressed: () => settings.logout(),
        icon: const Icon(LucideIcons.logOut, color: Colors.redAccent, size: 20),
        label: Text('SIGN OUT OF ALL SESSIONS', style: GoogleFonts.figtree(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 11)),
        style: TextButton.styleFrom(
          backgroundColor: Colors.redAccent.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.redAccent.withOpacity(0.2))),
        ),
      ),
    );
  }

  Widget _buildWidgetAccountTile(BuildContext context, SettingsProvider settings, bool isDark) {
    final widgetAcc = settings.widgetAccount;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(LucideIcons.layout, color: PaceColors.purple, size: 22),
      title: Text('WIDGET DATA SOURCE', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
      subtitle: Text(widgetAcc != null ? "${widgetAcc.accountName.toUpperCase()} (${widgetAcc.subdomain})" : 'SELECT SOURCE', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
      onTap: () => _showWidgetAccountPicker(context, settings, isDark),
    );
  }

  void _showWidgetAccountPicker(BuildContext context, SettingsProvider settings, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getBackground(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Text('SELECT WIDGET DATA SOURCE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 2)),
             const SizedBox(height: 24),
             ...settings.accounts.asMap().entries.map((e) {
                final acc = e.value;
                final isSelected = settings.widgetAccountIndex == e.key;
                return ListTile(
                  leading: Icon(LucideIcons.home, color: isSelected ? PaceColors.purple : PaceColors.getDimText(isDark)),
                  title: Text(acc.accountName.toUpperCase(), style: GoogleFonts.figtree(color: isSelected ? PaceColors.purple : PaceColors.getPrimaryText(isDark), fontWeight: FontWeight.bold, fontSize: 13)),
                  trailing: isSelected ? const Icon(LucideIcons.check, color: PaceColors.purple) : null,
                  onTap: () {
                    settings.setWidgetAccount(e.key);
                    Navigator.pop(ctx);
                  },
                );
             }).toList(),
          ],
        ),
      ),
    );
  }
}
