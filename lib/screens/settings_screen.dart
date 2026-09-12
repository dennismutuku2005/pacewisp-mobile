import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
    try {
      final profile = await _apiService.fetchData(slug: 'profile', forceRefresh: true);
      if (profile != null && (profile['status'] == 'success' || profile['success'] == true)) {
        _user = profile['data'] ?? profile;
        _nameCtrl.text = _user['name'] ?? '';
        _phoneCtrl.text = _user['phone'] ?? '';
        
        final String userType = (_user['type'] ?? '').toString().toLowerCase();
        if (['admin', 'superadmin'].contains(userType)) {
          final sys = await _apiService.getGlobalSettings();
          if (sys != null && (sys['status'] == 'success' || sys['success'] == true)) {
            _systemSettings = sys['data'] ?? sys;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching settings: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUpdateProfile({String? otpCode}) async {
    setState(() => _isSaving = true);
    
    final body = {
      'name': _nameCtrl.text,
      'phone': _phoneCtrl.text,
      if (otpCode != null) 'otp_code': otpCode,
    };

    try {
      final res = await _apiService.fetchData(
        slug: 'profile',
        method: 'POST',
        body: body,
      );

      if (mounted) {
        if (res?['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully'), backgroundColor: PaceColors.green, behavior: SnackBarBehavior.floating),
          );
          setState(() {
            _isEditingProfile = false;
            _isSaving = false;
          });
          
          final settings = Provider.of<SettingsProvider>(context, listen: false);
          await settings.updateActiveAccountInfo(name: _nameCtrl.text, phone: _phoneCtrl.text);
          _fetchData();
        } else if (res?['status'] == 'otp_required') {
          setState(() => _isSaving = false);
          _showOtpModal(isPassword: false);
        } else {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res?['message'] ?? 'Update failed'), backgroundColor: PaceColors.red, behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleChangePassword({String? otpCode}) async {
    if (_passCtrl.text.isEmpty || _passCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isSaving = true);
    final body = {
      'password': _passCtrl.text,
      if (otpCode != null) 'otp_code': otpCode,
    };

    try {
      final res = await _apiService.fetchData(
        slug: 'profile',
        method: 'POST',
        body: body,
      );

      if (mounted) {
        if (res?['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password changed successfully'), backgroundColor: PaceColors.green, behavior: SnackBarBehavior.floating),
          );
          _passCtrl.clear();
          _confirmPassCtrl.clear();
          setState(() => _isSaving = false);
        } else if (res?['status'] == 'otp_required') {
          setState(() => _isSaving = false);
          _showOtpModal(isPassword: true);
        } else {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res?['message'] ?? 'Update failed'), backgroundColor: PaceColors.red, behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showOtpModal({bool isPassword = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OtpModal(
        phoneNumber: _phoneCtrl.text,
        actionType: isPassword ? 'password_change' : 'phone_change',
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

  String? _activeToggle;

  bool _parseBool(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is int) return val == 1;
    if (val is String) {
      final s = val.toLowerCase();
      return s == '1' || s == 'true' || s == 'yes' || s == 'on';
    }
    return false;
  }

  Future<void> _updateSystem(String field, bool value) async {
    setState(() => _activeToggle = field);
    final val = value ? 1 : 0;
    try {
      final res = await _apiService.updateGlobalSetting(field, val);
      if (mounted) {
        if (res != null && (res['status'] == 'success' || res['success'] == true)) {
          setState(() => _systemSettings[field] = val);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Setting updated: ${field.replaceAll('_', ' ')}'), backgroundColor: PaceColors.green, behavior: SnackBarBehavior.floating),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res?['message'] ?? 'Failed to update'), backgroundColor: PaceColors.red, behavior: SnackBarBehavior.floating),
          );
        }
        setState(() => _activeToggle = null);
      }
    } catch (_) {
      if (mounted) setState(() => _activeToggle = null);
    }
  }

  Future<void> _handleSwitchAccount(int index, SettingsProvider settings) async {
    final acc = settings.accounts[index];
    final isDark = settings.isDarkMode;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Switch Account', style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w700, color: PaceColors.purple)),
        content: Text('Switch active workspace to ${acc.accountName} (${acc.subdomain})?', style: GoogleFonts.figtree(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Switch', style: GoogleFonts.figtree(fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await settings.switchAccount(index);
      _fetchData();
    }
  }

  Future<void> _handleRemoveAccount(int index, SettingsProvider settings) async {
    final acc = settings.accounts[index];
    final isDark = settings.isDarkMode;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Account', style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w700, color: PaceColors.red)),
        content: Text('Remove ${acc.accountName} (${acc.subdomain}) from this device?', style: GoogleFonts.figtree(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Keep', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: PaceColors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: GoogleFonts.figtree(fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await settings.removeAccount(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return PaceOverlayLoader(
      isLoading: _isSaving,
      message: 'Processing Security Update...',
      child: Scaffold(
        backgroundColor: PaceColors.getBackground(isDark),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDark),
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2))
                  : RefreshIndicator(
                      onRefresh: _fetchData,
                      color: PaceColors.purple,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        children: [
                          _buildProfileCard(isDark),
                          const SizedBox(height: 20),
                          if (_systemSettings.isNotEmpty) ...[
                            _buildSectionTitle('Infrastructure Logic', 'Global hotspot & billing behavior', isDark),
                            _buildToggleItem('Double Payment Lock', 'Prevent STK push if active session exists', _parseBool(_systemSettings['doublepayment_lock']), (v) => _updateSystem('doublepayment_lock', v), LucideIcons.shield, isDark, isLoading: _activeToggle == 'doublepayment_lock'),
                            _buildToggleItem('Error Notifications', 'Receive and log MikroTik connection errors', _parseBool(_systemSettings['receive_error_info']), (v) => _updateSystem('receive_error_info', v), LucideIcons.activity, isDark, isLoading: _activeToggle == 'receive_error_info'),
                            _buildToggleItem('Vouchers as Sales', 'Automatically mark new vouchers as final sales', _parseBool(_systemSettings['vouchers_as_sale']), (v) => _updateSystem('vouchers_as_sale', v), LucideIcons.tag, isDark, isLoading: _activeToggle == 'vouchers_as_sale'),
                            const SizedBox(height: 20),
                          ],
                          _buildSectionTitle('Security & Access', 'Manage biometric lock and credentials', isDark),
                          _buildToggleItem(
                            'App Lock (Biometrics)', 
                            'Require fingerprint or PIN to open app', 
                            settings.isAppLockEnabled, 
                            (v) async {
                              final bool didAuth = await _apiService.authenticateBiometric(
                                reason: 'Verify identity to ${v ? 'enable' : 'disable'} App Lock'
                              );
                              if (didAuth) {
                                settings.toggleAppLock(v);
                              }
                            }, 
                            LucideIcons.lock, 
                            isDark
                          ),
                          _buildActionItem('Change Password', 'Update your account login credentials', LucideIcons.key, () => _showPasswordModal(isDark), isDark),
                          const SizedBox(height: 20),
                          _buildAccountSwitcherHeader(isDark, settings),
                          _buildAccountList(settings, isDark),
                          const SizedBox(height: 32),
                          Center(
                            child: Column(
                              children: [
                                Text('Pace Management Portal', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark))),
                                const SizedBox(height: 2),
                                Text('v${settings.appVersion}', style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark).withOpacity(0.6))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('System & Account', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Configure instance settings and preferences', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildProfileCard(bool isDark) {
    final name = _user['name'] ?? 'Administrator';
    final username = _user['username'] ?? 'admin';
    final type = _user['type']?.toString().toUpperCase() ?? 'STAFF';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44, 
                height: 44, 
                decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), shape: BoxShape.circle), 
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name.substring(0,1).toUpperCase() : 'A',
                    style: GoogleFonts.figtree(color: PaceColors.purple, fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.figtree(fontWeight: FontWeight.w700, fontSize: 15, color: PaceColors.getPrimaryText(isDark))),
                    Text("@$username", style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark))),
                  ],
                ),
              ),
              PaceBadge(label: type, variant: BadgeVariant.secondary),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          if (!_isEditingProfile) ...[
            _buildInfoRow(LucideIcons.phone, 'Phone Number', _user['phone'] ?? 'Not set', isDark),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton(
                onPressed: () => setState(() => _isEditingProfile = true),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: PaceColors.purple.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Edit Profile', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.purple)),
              ),
            ),
          ] else ...[
             _buildEditField('Full Name', _nameCtrl, LucideIcons.user, isDark),
             const SizedBox(height: 12),
             _buildEditField('Phone Number', _phoneCtrl, LucideIcons.phone, isDark, keyboardType: TextInputType.phone),
             const SizedBox(height: 16),
             Row(
               children: [
                 Expanded(
                   child: TextButton(
                     onPressed: () => setState(() => _isEditingProfile = false),
                     child: Text('Cancel', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600, fontSize: 12)),
                   ),
                 ),
                 const SizedBox(width: 10),
                 Expanded(
                   child: ElevatedButton(
                     onPressed: _handleUpdateProfile,
                     style: ElevatedButton.styleFrom(
                       backgroundColor: PaceColors.purple,
                       foregroundColor: Colors.white,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                       elevation: 0,
                     ),
                     child: Text('Save', style: GoogleFonts.figtree(fontWeight: FontWeight.w700, fontSize: 12)),
                   ),
                 ),
               ],
             ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController ctrl, IconData icon, bool isDark, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark))),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 16, color: PaceColors.purple),
            filled: true,
            fillColor: PaceColors.getSurface(isDark),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: PaceColors.getBorder(isDark))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String val, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 14, color: PaceColors.getDimText(isDark)),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark))),
        const Spacer(),
        Text(val, style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
      ],
    );
  }

  Widget _buildSectionTitle(String title, String subtitle, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w700, color: PaceColors.purple)),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark))),
        ],
      ),
    );
  }

  Widget _buildActionItem(String title, String sub, IconData icon, VoidCallback onTap, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 16, color: PaceColors.purple),
        ),
        title: Text(title, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
        subtitle: Text(sub, style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark))),
        trailing: Icon(LucideIcons.chevronRight, size: 16, color: PaceColors.getDimText(isDark)),
      ),
    );
  }

  Widget _buildAccountSwitcherHeader(bool isDark, SettingsProvider settings) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Account Switcher', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w700, color: PaceColors.purple)),
              const SizedBox(height: 2),
              Text('Seamlessly transition between managed ISP accounts', style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark))),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            icon: const Icon(LucideIcons.plusCircle, size: 18, color: PaceColors.purple),
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
            color: isActive ? PaceColors.purple.withOpacity(0.05) : PaceColors.getCard(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isActive ? PaceColors.purple : PaceColors.getBorder(isDark), width: isActive ? 1.5 : 1),
          ),
          child: ListTile(
            dense: true,
            onTap: isActive ? null : () => _handleSwitchAccount(index, settings),
            leading: Icon(LucideIcons.globe, size: 16, color: isActive ? PaceColors.purple : Colors.grey),
            title: Text(
              acc.accountName,
              style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w700, color: isActive ? PaceColors.purple : PaceColors.getPrimaryText(isDark)),
            ),
            subtitle: Text(
              "${acc.subdomain}.${acc.domain}",
              style: GoogleFonts.figtree(fontSize: 11, color: Colors.grey),
            ),
            trailing: isActive 
              ? const Icon(LucideIcons.checkCircle2, color: PaceColors.purple, size: 16)
              : IconButton(icon: const Icon(LucideIcons.trash2, size: 14, color: PaceColors.red), onPressed: () => _handleRemoveAccount(index, settings)),
          ),
        );
      }),
    );
  }

  Widget _buildToggleItem(String title, String sub, bool val, Function(bool) onChanged, IconData icon, bool isDark, {bool isLoading = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (val ? PaceColors.purple : Colors.grey).withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: val ? PaceColors.purple : Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
                Text(sub, style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark))),
              ],
            ),
          ),
          isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: PaceColors.purple)),
              )
            : Switch(
                value: val, 
                onChanged: _isSaving ? null : onChanged, 
                activeColor: PaceColors.purple,
              ),
        ],
      ),
    );
  }

  void _showPasswordModal(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          top: 24,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: PaceColors.getBorder(isDark)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: PaceColors.getBorder(isDark), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Change Password', style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w700, color: PaceColors.getPrimaryText(isDark))),
            const SizedBox(height: 16),
            _buildEditField('New Password', _passCtrl, LucideIcons.lock, isDark),
            const SizedBox(height: 12),
            _buildEditField('Confirm Password', _confirmPassCtrl, LucideIcons.lock, isDark),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600)))),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleChangePassword();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                    child: Text('Update Password', style: GoogleFonts.figtree(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
