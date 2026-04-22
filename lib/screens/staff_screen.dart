import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
import '../components/otp_modal.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _staff = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSubmitting = false;
  String _search = '';

  final List<Map<String, String>> _availablePolicies = [
    {'id': 'view_dashboard', 'label': 'View Dashboard', 'desc': 'Access main dashboard overview'},
    {'id': 'view_entries', 'label': 'View Entries', 'desc': 'Monitor live connections'},
    {'id': 'view_logs', 'label': 'System Debug Logs', 'desc': 'View detailed debug info'},
    {'id': 'view_notifications', 'label': 'Notifications', 'desc': 'Access system alerts center'},
    {'id': 'manage_plans', 'label': 'Manage Plans', 'desc': 'Create/edit hotspot packages'},
    {'id': 'view_vouchers', 'label': 'Browse Vouchers', 'desc': 'Search existing access codes'},
    {'id': 'create_voucher', 'label': 'Generate Vouchers', 'desc': 'Create bulk prepaid codes'},
    {'id': 'view_customers', 'label': 'View Customers', 'desc': 'Access customer lists'},
    {'id': 'manage_customers', 'label': 'Manage Customers', 'desc': 'Edit or block accounts'},
    {'id': 'view_active_users', 'label': 'Live Connections', 'desc': 'Monitor connected devices'},
    {'id': 'view_income', 'label': 'Revenue Analytics', 'desc': 'Access core income data'},
    {'id': 'manage_expenses', 'label': 'Expense Tracking', 'desc': 'Record system overheads'},
    {'id': 'view_reports', 'label': 'Financial Reports', 'desc': 'Access compiled statements'},
    {'id': 'view_mpesa', 'label': 'Gateway Logs', 'desc': 'Monitor M-Pesa history'},
    {'id': 'view_routers', 'label': 'View Nodes', 'desc': 'Monitor router connectivity'},
    {'id': 'manage_routers', 'label': 'Configure Hardware', 'desc': 'Add/edit router nodes'},
    {'id': 'wa_alerts', 'label': 'WhatsApp Alerts', 'desc': 'Manage automated reporting'},
    {'id': 'manage_users', 'label': 'Staff Management', 'desc': 'Add/Remove personnel'},
    {'id': 'manage_themes', 'label': 'Portal Themes', 'desc': 'Customize landing pages'},
    {'id': 'system_config', 'label': 'Global Config', 'desc': 'Modify core system settings'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    setState(() => _isRefreshing = true);
    final res = await _apiService.getStaff(forceRefresh: true);
    if (mounted) {
      setState(() {
        _staff = res?['data'] ?? [];
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  void _showStaffForm([dynamic staff]) {
    final bool isEdit = staff != null;
    final nameCtrl = TextEditingController(text: staff?['name']);
    final userCtrl = TextEditingController(text: staff?['username']);
    final phoneCtrl = TextEditingController(text: staff?['phone']);
    final passCtrl = TextEditingController();
    String type = staff?['type'] ?? 'user';
    String status = staff?['status'] ?? 'active';
    List<String> policies = List<String>.from(staff?['policies'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Container(
          height: MediaQuery.of(ctx).size.height * 0.9,
          decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 32),
                Text(isEdit ? 'UPDATE PERSONNEL' : 'PROVISION ACCOUNT', style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1)),
                Text(isEdit ? 'Modifying ${staff['username']}' : 'Assign credentials for new member', style: GoogleFonts.figtree(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                _buildField('FULL NAME', nameCtrl, LucideIcons.user),
                const SizedBox(height: 16),
                _buildField('USERNAME', userCtrl, LucideIcons.atSign, enabled: !isEdit),
                const SizedBox(height: 16),
                _buildField('PHONE NUMBER', phoneCtrl, LucideIcons.phone),
                const SizedBox(height: 16),
                _buildField(isEdit ? 'NEW PASSWORD (OPT) ' : 'PASSWORD', passCtrl, LucideIcons.key, isPass: true),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: _buildDropdown('ROLE', type, ['user', 'admin'], (v) => setM(() => type = v!))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDropdown('STATUS', status, ['active', 'suspended', 'inactive'], (v) => setM(() => status = v!))),
                ]),
                if (type == 'user') ...[
                  const SizedBox(height: 32),
                  Row(children: [
                    const Icon(LucideIcons.shield, color: PaceColors.purple, size: 14),
                    const SizedBox(width: 8),
                    Text('SYSTEM POLICIES', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.black, color: PaceColors.purple, letterSpacing: 1.5)),
                  ]),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 1, mainAxisExtent: 60, mainAxisSpacing: 8),
                    itemCount: _availablePolicies.length,
                    itemBuilder: (ctx, i) {
                      final p = _availablePolicies[i];
                      final isSel = policies.contains(p['id']);
                      return InkWell(
                        onTap: () => setM(() { if (isSel) policies.remove(p['id']); else policies.add(p['id']!); }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(color: isSel ? PaceColors.purple.withOpacity(0.05) : Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: isSel ? PaceColors.purple : Colors.white10)),
                          child: Row(children: [
                            Icon(isSel ? LucideIcons.checkCircle2 : LucideIcons.circle, color: isSel ? PaceColors.purple : Colors.grey, size: 16),
                            const SizedBox(width: 16),
                            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p['label']!, style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? PaceColors.purple : Colors.white)),
                              Text(p['desc']!, style: GoogleFonts.figtree(fontSize: 8, color: Colors.grey)),
                            ])),
                          ]),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 48),
                SizedBox(height: 56, child: ElevatedButton(
                  onPressed: _isSubmitting ? null : () => _handleAction(isEdit, staff?['id'], {'name': nameCtrl.text, 'username': userCtrl.text, 'phone': phoneCtrl.text, 'password': passCtrl.text, 'type': type, 'status': status, 'policies': policies}),
                  style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : Text(isEdit ? 'UPDATE ACCOUNT' : 'CREATE ACCOUNT', style: GoogleFonts.figtree(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(bool isEdit, String? id, Map<String, dynamic> data, {String? otp}) async {
    final payload = {...data};
    if (otp != null) payload['otp_code'] = otp;
    setState(() => _isSubmitting = true);
    final res = isEdit ? await _apiService.updateStaff(id!, payload) : await _apiService.createStaff(payload);
    if (mounted) {
      if (res?['status'] == 'otp_required') {
        _showOtpModal((code) => _handleAction(isEdit, id, data, otp: code));
      } else if (res?['status'] == 'success') {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Personnel Updated'), backgroundColor: PaceColors.emerald));
        _fetchStaff();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Error'), backgroundColor: Colors.red));
      }
      setState(() => _isSubmitting = false);
    }
  }

  void _showOtpModal(Function(String) onVerify) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => OtpModal(phoneNumber: 'VERIFYING CHANGE', onVerify: (code) { Navigator.pop(ctx); onVerify(code); }));
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;
    final list = _staff.where((s) => (s['name'] ?? '').toLowerCase().contains(_search.toLowerCase()) || (s['username'] ?? '').toLowerCase().contains(_search.toLowerCase())).toList();

    return Column(
      children: [
        _buildHeader(isDark),
        _buildSearch(isDark),
        Expanded(
          child: _isLoading 
            ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList())
            : RefreshIndicator(
                onRefresh: _fetchStaff,
                color: PaceColors.purple,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => _buildStaffCard(list[i], isDark),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('STAFF MANAGEMENT', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
            Text('ADMIN ACCESS & POLICY CONTROL', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ]),
          IconButton(onPressed: () => _showStaffForm(), icon: const Icon(LucideIcons.plusCircle, color: PaceColors.purple)),
        ],
      ),
    );
  }

  Widget _buildSearch(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: TextField(
        onChanged: (v) => setState(() => _search = v),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        decoration: InputDecoration(hintText: 'Search team members...', prefixIcon: const Icon(LucideIcons.search, size: 16), filled: true, fillColor: PaceColors.getSurface(isDark), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
      ),
    );
  }

  Widget _buildStaffCard(dynamic s, bool isDark) {
    final type = s['type']?.toString().toUpperCase() ?? 'STAFF';
    final bool isAdmin = type == 'ADMIN' || type == 'SUPERADMIN';
    return InkWell(
      onTap: () => _showStaffForm(s),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark))),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), shape: BoxShape.circle), child: Center(child: Icon(isAdmin ? LucideIcons.shieldCheck : LucideIcons.user, color: PaceColors.purple, size: 18))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['name'] ?? 'STAFF', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w800)),
            Text(s['username'] ?? '', style: GoogleFonts.figtree(fontSize: 9, color: Colors.grey)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            PaceBadge(label: type, variant: isAdmin ? BadgeVariant.info : BadgeVariant.secondary),
            const SizedBox(height: 6),
            Text(s['status']?.toString().toUpperCase() ?? 'ACTIVE', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: s['status'] == 'active' ? PaceColors.emerald : Colors.red)),
          ]),
        ]),
      ),
    );
  }

   Widget _buildField(String l, TextEditingController c, IconData i, bool isDark, {bool isPass = false, bool enabled = true}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.black, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
      const SizedBox(height: 8),
      TextField(controller: c, enabled: enabled, obscureText: isPass, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)), decoration: InputDecoration(prefixIcon: Icon(i, size: 14, color: Colors.grey), filled: true, fillColor: PaceColors.getSurface(isDark), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
    ]);
  }

  Widget _buildDropdown(String l, String v, List<String> items, Function(String?) onChange, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.black, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(16)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: v, isExpanded: true, dropdownColor: PaceColors.getCard(isDark), items: items.map((it) => DropdownMenuItem(value: it, child: Text(it.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))))).toList(), onChanged: onChange))),
    ]);
  }
}
