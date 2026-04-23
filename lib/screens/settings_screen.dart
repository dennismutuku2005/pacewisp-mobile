import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'login_screen.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/otp_modal.dart';
import '../components/overlay_loader.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> _user = {};
  Map<String, dynamic> _systemSettings = {};

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  
  bool _isEditingProfile = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final profile = await _apiService.fetchData(slug: 'profile');
    if (profile?['success'] == true) {
      _user = profile?['data'] ?? {};
      _nameCtrl.text = _user['name'] ?? '';
      _phoneCtrl.text = _user['phone'] ?? '';
      
      if (['admin', 'superadmin'].contains(_user['type'])) {
        final sys = await _apiService.fetchData(slug: 'system_settings');
        if (sys?['status'] == 'success') _systemSettings = sys?['data'] ?? {};
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleUpdateProfile({String? otpCode}) async {
    setState(() => _isSaving = true);
    
    final body = {
      'name': _nameCtrl.text,
      'phone': _phoneCtrl.text,
    };
    if (otpCode != null) body['otp_code'] = otpCode;

    final res = await _apiService.fetchData(
      slug: 'profile',
      method: 'POST',
      body: body,
    );

    if (mounted) {
      if (res?['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully'), backgroundColor: PaceColors.emerald));
        setState(() => _isEditingProfile = false);
        _fetchData();
      } else if (res?['status'] == 'otp_required') {
        _showOtpModal(otpCode == null); // Only show if we haven't already
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Update failed'), backgroundColor: Colors.redAccent));
      }
      setState(() => _isSaving = false);
    }
  }

  Future<void> _handleChangePassword({String? otpCode}) async {
    if (_passCtrl.text.isEmpty || _passCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isSaving = true);
    final body = {
      'password': _passCtrl.text,
      'name': _nameCtrl.text,
      'phone': _phoneCtrl.text,
    };
    if (otpCode != null) body['otp_code'] = otpCode;

    final res = await _apiService.fetchData(
      slug: 'profile',
      method: 'POST',
      body: body,
    );

    if (mounted) {
      if (res?['status'] == 'success') {
        Navigator.pop(context); // Close password modal
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully'), backgroundColor: PaceColors.emerald));
        _passCtrl.clear();
        _confirmPassCtrl.clear();
      } else if (res?['status'] == 'otp_required') {
        _showOtpModal(true, isPassword: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Update failed'), backgroundColor: Colors.redAccent));
      }
      setState(() => _isSaving = false);
    }
  }

  void _showOtpModal(bool show, {bool isPassword = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OtpModal(
        phoneNumber: _phoneCtrl.text,
        onVerify: (code) {
          Navigator.pop(context);
          if (isPassword) {
            _handleChangePassword(otpCode: code);
          } else {
            _handleUpdateProfile(otpCode: code);
          }
        },
      ),
    );
  }

  Future<void> _updateSystem(String field, bool value) async {
    setState(() => _isSaving = true);
    final val = value ? 1 : 0;
    final res = await _apiService.fetchData(slug: 'system_settings', method: 'POST', body: {field: val});
    if (mounted) {
      if (res?['status'] == 'success') {
        setState(() => _systemSettings[field] = val);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Setting updated: ${field.replaceAll('_', ' ').toUpperCase()}'), backgroundColor: PaceColors.emerald));
      }
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return PaceOverlayLoader(
      isLoading: _isSaving,
      message: 'Processing Security Update...',
      child: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: PaceColors.purple))
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  color: PaceColors.purple,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    children: [
                      _buildProfileCard(isDark),
                      const SizedBox(height: 24),
                      if (['admin', 'superadmin'].contains(_user['type'])) ...[
                        _buildSystemConfigHeader(isDark),
                        _buildToggleItem('Double Payment Lock', 'Prevent STK push if active session exists', _systemSettings['doublepayment_lock'] == 1, (v) => _updateSystem('doublepayment_lock', v), LucideIcons.shield, isDark),
                        _buildToggleItem('Receive Error Info', 'Log MikroTik connection errors to dashboard', _systemSettings['receive_error_info'] == 1, (v) => _updateSystem('receive_error_info', v), LucideIcons.activity, isDark),
                        _buildToggleItem('Vouchers as Sale', 'Mark new vouchers as final sales instantly', _systemSettings['vouchers_as_sale'] == 1, (v) => _updateSystem('vouchers_as_sale', v), LucideIcons.tag, isDark),
                      ],
                      const SizedBox(height: 32),
                      _buildSecurityHeader(isDark),
                      _buildToggleItem('App Lock (Biometrics)', 'Require fingerprint or PIN to open app', settings.isAppLockEnabled, (v) => settings.toggleAppLock(v), LucideIcons.lock, isDark),
                      _buildActionItem('Change Password', 'Update your account login credentials', LucideIcons.key, () => _showPasswordModal(isDark), isDark),
                      const SizedBox(height: 32),
                      _buildAccountSwitcherHeader(isDark, settings),
                      _buildAccountList(settings, isDark),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SYSTEM & ACCOUNT', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
          Text('CONFIGURE YOUR APP & SETTINGS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildProfileCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark), 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: PaceColors.getBorder(isDark)),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(children: [
            Container(
              width: 56, 
              height: 56, 
              decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), shape: BoxShape.circle), 
              child: Center(child: Text(_user['name']?.toString().substring(0,1).toUpperCase() ?? '?', style: const TextStyle(color: PaceColors.purple, fontWeight: FontWeight.w600, fontSize: 20)))
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_user['name'] ?? 'USER', style: GoogleFonts.figtree(fontWeight: FontWeight.w600, fontSize: 18, color: PaceColors.getPrimaryText(isDark))),
              Text("@${_user['username'] ?? 'username'}", style: TextStyle(fontSize: 12, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w500)),
            ])),
            PaceBadge(label: _user['type']?.toString().toUpperCase() ?? 'STAFF', variant: BadgeVariant.secondary),
          ]),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          if (!_isEditingProfile) ...[
            _buildInfoRow(LucideIcons.phone, 'Phone Number', _user['phone'] ?? '---', isDark),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => setState(() => _isEditingProfile = true),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: PaceColors.purple.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('EDIT PROFILE', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w700, color: PaceColors.purple, letterSpacing: 1)),
              ),
            ),
          ] else ...[
             _buildEditField('FULL NAME', _nameCtrl, LucideIcons.user, isDark),
             const SizedBox(height: 16),
             _buildEditField('PHONE NUMBER', _phoneCtrl, LucideIcons.phone, isDark, keyboardType: TextInputType.phone),
             const SizedBox(height: 24),
             Row(children: [
               Expanded(child: TextButton(onPressed: () => setState(() => _isEditingProfile = false), child: Text('CANCEL', style: TextStyle(color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w700, fontSize: 11)))),
               const SizedBox(width: 12),
               Expanded(child: ElevatedButton(
                 onPressed: _handleUpdateProfile,
                 style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                 child: const Text('SAVE CHANGES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
               )),
             ]),
          ],
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController ctrl, IconData icon, bool isDark, {TextInputType? keyboardType}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
      const SizedBox(height: 8),
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 16, color: PaceColors.purple),
          filled: true,
          fillColor: PaceColors.getSurface(isDark),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    ]);
  }

  Widget _buildInfoRow(IconData icon, String label, String val, bool isDark) {
    return Row(children: [
      Icon(icon, size: 14, color: PaceColors.getDimText(isDark)),
      const SizedBox(width: 12),
      Text(label, style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w500)),
      const Spacer(),
      Text(val, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
    ]);
  }

  Widget _buildSystemConfigHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INFRASTRUCTURE LOGIC', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w800, color: PaceColors.purple, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text('Manage global hotspot and billing behavior', style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSecurityHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SECURITY & PRIVACY', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w800, color: PaceColors.purple, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text('Manage access and biometric authentication', style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildActionItem(String title, String sub, IconData icon, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark))),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: PaceColors.purple)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
              Text(sub, style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark))),
            ])),
            Icon(LucideIcons.chevronRight, size: 16, color: PaceColors.getDimText(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSwitcherHeader(bool isDark, SettingsProvider settings) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ACCOUNT SWITCHER', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w800, color: PaceColors.purple, letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text('Seamlessly transition between managed ISP instances', style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w500)),
            ],
          ),
          if (settings.accounts.length < 4)
            IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
              icon: const Icon(LucideIcons.plusCircle, size: 20, color: PaceColors.purple),
            ),
        ],
      ),
    );
  }

  Widget _buildAccountList(SettingsProvider settings, bool isDark) {
    return Column(
      children: List.generate(settings.accounts.length, (index) {
        final acc = settings.accounts[index];
        final bool isActive = settings.activeAccount?.subdomain == acc.subdomain && settings.activeAccount?.domain == acc.domain;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isActive ? PaceColors.purple.withOpacity(0.05) : PaceColors.getSurface(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isActive ? PaceColors.purple : PaceColors.getBorder(isDark), width: isActive ? 1.5 : 1),
          ),
          child: ListTile(
            dense: true,
            onTap: isActive ? null : () => settings.switchAccount(index),
            leading: Icon(LucideIcons.globe, size: 16, color: isActive ? PaceColors.purple : Colors.grey),
            title: Text(acc.accountName.toUpperCase(), style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w700, color: isActive ? PaceColors.purple : PaceColors.getPrimaryText(isDark))),
            subtitle: Text("${acc.subdomain}.${acc.domain}", style: GoogleFonts.figtree(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
            trailing: isActive 
              ? const Icon(LucideIcons.checkCircle, color: PaceColors.purple, size: 16)
              : IconButton(icon: const Icon(LucideIcons.trash2, size: 14, color: Colors.redAccent), onPressed: () => settings.removeAccount(index)),
          ),
        );
      }),
    );
  }

  Widget _buildToggleItem(String title, String sub, bool val, Function(bool) onChanged, IconData icon, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (val ? PaceColors.purple : Colors.grey).withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: val ? PaceColors.purple : Colors.grey)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
            Text(sub, style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark))),
          ])),
          Switch(
            value: val, 
            onChanged: _isSaving ? null : onChanged, 
            activeColor: PaceColors.purple,
            activeTrackColor: PaceColors.purple.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  void _showPasswordModal(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getBackground(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('CHANGE PASSWORD', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w700, color: PaceColors.purple, letterSpacing: 1)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEditField('NEW PASSWORD', _passCtrl, LucideIcons.lock, isDark),
            const SizedBox(height: 16),
            _buildEditField('CONFIRM PASSWORD', _confirmPassCtrl, LucideIcons.lock, isDark),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('CANCEL', style: TextStyle(color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w700))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _handleChangePassword(); },
            style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('UPDATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
