import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final profile = await _apiService.fetchData(slug: 'profile');
    if (profile?['success'] == true) {
      _user = profile?['data'] ?? {};
      if (['admin', 'superadmin'].contains(_user['type'])) {
        final sys = await _apiService.fetchData(slug: 'system_settings');
        if (sys?['status'] == 'success') _systemSettings = sys?['data'] ?? {};
      }
    }
    if (mounted) setState(() => _isLoading = false);
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

    return Column(
      children: [
        _buildHeader(isDark),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
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
                    _buildAccountSwitcherHeader(isDark),
                    _buildAccountList(settings, isDark),
                  ],
                ),
              ),
        ),
      ],
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
          Text('CONFIGURE YOUR ISP BEHAVIOR AND PREFERENCES', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildProfileCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark))),
      child: Column(
        children: [
          Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), shape: BoxShape.circle), child: Center(child: Text(_user['name']?.toString().substring(0,1).toUpperCase() ?? '?', style: const TextStyle(color: PaceColors.purple, fontWeight: FontWeight.w600)))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_user['name'] ?? 'USER', style: GoogleFonts.figtree(fontWeight: FontWeight.w600, fontSize: 16)),
              Text(_user['username'] ?? 'username', style: TextStyle(fontSize: 12, color: PaceColors.getDimText(isDark))),
            ])),
            PaceBadge(label: _user['type']?.toString().toUpperCase() ?? 'STAFF', variant: BadgeVariant.secondary),
          ]),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          _buildInfoRow(LucideIcons.phone, 'Phone Number', _user['phone'] ?? '---', isDark),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String val, bool isDark) {
    return Row(children: [
      Icon(icon, size: 14, color: PaceColors.getDimText(isDark)),
      const SizedBox(width: 12),
      Text(label, style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark))),
      const Spacer(),
      Text(val, style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildSystemConfigHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INFRASTRUCTURE LOGIC', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w600, color: PaceColors.purple, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text('Manage global hotspot and billing behavior', style: GoogleFonts.figtree(fontSize: 9, color: PaceColors.getDimText(isDark))),
        ],
      ),
    );
  }

  Widget _buildAccountSwitcherHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ACCOUNT SWITCHER', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w600, color: PaceColors.purple, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text('Seamlessly transition between managed ISP instances', style: GoogleFonts.figtree(fontSize: 9, color: PaceColors.getDimText(isDark))),
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
            title: Text(acc.accountName.toUpperCase(), style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? PaceColors.purple : PaceColors.getPrimaryText(isDark))),
            subtitle: Text("${acc.subdomain}.${acc.domain}", style: GoogleFonts.figtree(fontSize: 9, color: Colors.grey)),
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
          Icon(icon, size: 20, color: val ? PaceColors.purple : Colors.grey),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600)),
            Text(sub, style: GoogleFonts.figtree(fontSize: 9, color: Colors.grey)),
          ])),
          Switch(value: val, onChanged: _isSaving ? null : onChanged, activeColor: PaceColors.purple),
        ],
      ),
    );
  }
}
