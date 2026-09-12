import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/empty_state.dart';
import '../components/skeleton.dart';
import '../components/search_bar.dart';
import '../components/otp_modal.dart';
import '../components/overlay_loader.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _staff = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _search = '';

  final List<Map<String, String>> _availablePolicies = [
    {'id': 'view_dashboard', 'label': 'View Dashboard', 'desc': 'Access main dashboard overview'},
    {'id': 'view_entries', 'label': 'View Entries', 'desc': 'Monitor live connections & payments'},
    {'id': 'view_logs', 'label': 'System Logs', 'desc': 'View system activity and audit logs'},
    {'id': 'view_notifications', 'label': 'Notifications', 'desc': 'Access system alerts center'},
    {'id': 'manage_plans', 'label': 'Manage Plans', 'desc': 'Create and edit hotspot packages'},
    {'id': 'view_vouchers', 'label': 'Browse Vouchers', 'desc': 'Search existing access codes'},
    {'id': 'create_voucher', 'label': 'Generate Vouchers', 'desc': 'Create bulk prepaid codes'},
    {'id': 'view_customers', 'label': 'View Customers', 'desc': 'Access customer list and history'},
    {'id': 'manage_customers', 'label': 'Manage Customers', 'desc': 'Edit, block or reset customer accounts'},
    {'id': 'view_active_users', 'label': 'Live Connections', 'desc': 'Monitor active connected devices'},
    {'id': 'view_income', 'label': 'Revenue Analytics', 'desc': 'Access core income data and charts'},
    {'id': 'manage_expenses', 'label': 'Expense Tracking', 'desc': 'Record system overheads and costs'},
    {'id': 'view_reports', 'label': 'Financial Reports', 'desc': 'Access compiled monthly statements'},
    {'id': 'view_mpesa', 'label': 'Gateway Logs', 'desc': 'Monitor M-Pesa transaction history'},
    {'id': 'view_routers', 'label': 'View Nodes', 'desc': 'Monitor router connectivity and status'},
    {'id': 'manage_routers', 'label': 'Configure Hardware', 'desc': 'Add, edit or reboot router nodes'},
    {'id': 'wa_alerts', 'label': 'WhatsApp Alerts', 'desc': 'Manage automated daily reporting'},
    {'id': 'manage_users', 'label': 'Staff Management', 'desc': 'Add, edit or remove staff accounts'},
    {'id': 'manage_themes', 'label': 'Portal Themes', 'desc': 'Customize captive portal landing pages'},
    {'id': 'system_config', 'label': 'Global Config', 'desc': 'Modify core system configuration'},
    {'id': 'view_bills', 'label': 'Service Billing', 'desc': 'Access your own service invoices'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    setState(() => _isLoading = true);
    final res = await _apiService.getStaff(forceRefresh: true);
    if (mounted) {
      setState(() {
        _staff = res?['data'] ?? [];
        _isLoading = false;
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
      builder: (ctx) {
        final settings = Provider.of<SettingsProvider>(ctx);
        final isDark = settings.isDarkMode;
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.88,
          decoration: BoxDecoration(
            color: PaceColors.getCard(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: PaceColors.getBorder(isDark)),
          ),
          child: StatefulBuilder(
            builder: (ctx, setM) => Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: PaceColors.getBorder(isDark), borderRadius: BorderRadius.circular(2)),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit ? 'Edit Staff Member' : 'Add Staff Member',
                                  style: GoogleFonts.figtree(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: PaceColors.getPrimaryText(isDark),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isEdit ? 'Updating account permissions for ${staff['name'] ?? staff['username']}' : 'Provision credentials and roles for a team member',
                                  style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark)),
                                ),
                              ],
                            ),
                            IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(context)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildField('Full Name', nameCtrl, LucideIcons.user, isDark, hint: 'e.g. Dennis Mutuku'),
                        const SizedBox(height: 14),
                        _buildField('Username', userCtrl, LucideIcons.atSign, isDark, enabled: !isEdit, hint: 'e.g. dennis_admin'),
                        const SizedBox(height: 14),
                        _buildField('Phone Number', phoneCtrl, LucideIcons.phone, isDark, hint: 'e.g. 0712345678'),
                        const SizedBox(height: 14),
                        _buildField(isEdit ? 'New Password (leave blank to keep)' : 'Password', passCtrl, LucideIcons.lock, isDark, isPass: true, hint: 'Enter secure password'),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(child: _buildDropdown('Role', type, ['user', 'admin'], (v) => setM(() => type = v!), isDark)),
                            const SizedBox(width: 14),
                            Expanded(child: _buildDropdown('Account Status', status, ['active', 'suspended', 'inactive'], (v) => setM(() => status = v!), isDark)),
                          ],
                        ),
                        if (type == 'user') ...[
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Icon(LucideIcons.shield, color: PaceColors.purple, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'System Policy Permissions',
                                style: GoogleFonts.figtree(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: PaceColors.getPrimaryText(isDark),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _availablePolicies.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final p = _availablePolicies[i];
                              final isSel = policies.contains(p['id']);
                              return InkWell(
                                onTap: () => setM(() {
                                  if (isSel) {
                                    policies.remove(p['id']);
                                  } else {
                                    policies.add(p['id']!);
                                  }
                                }),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSel ? PaceColors.purple.withOpacity(0.06) : PaceColors.getSurface(isDark),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isSel ? PaceColors.purple : PaceColors.getBorder(isDark)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSel ? LucideIcons.checkSquare : LucideIcons.square,
                                        color: isSel ? PaceColors.purple : PaceColors.getDimText(isDark),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p['label']!,
                                              style: GoogleFonts.figtree(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isSel ? PaceColors.purple : PaceColors.getPrimaryText(isDark),
                                              ),
                                            ),
                                            Text(
                                              p['desc']!,
                                              style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  side: BorderSide(color: PaceColors.getBorder(isDark)),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _handleAction(
                                          isEdit,
                                          staff?['id']?.toString(),
                                          {
                                            'name': nameCtrl.text.trim(),
                                            'username': userCtrl.text.trim(),
                                            'phone': phoneCtrl.text.trim(),
                                            'password': passCtrl.text.trim(),
                                            'type': type,
                                            'status': status,
                                            'policies': policies,
                                          },
                                        ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: PaceColors.purple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                child: Text(
                                  isEdit ? 'Save Changes' : 'Create Account',
                                  style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Staff member updated' : 'Staff account created', style: GoogleFonts.figtree()),
            backgroundColor: PaceColors.emerald,
          ),
        );
        _fetchStaff();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['message'] ?? 'Action failed', style: GoogleFonts.figtree()), backgroundColor: Colors.red.shade700),
        );
      }
      setState(() => _isSubmitting = false);
    }
  }

  void _showOtpModal(Function(String) onVerify) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OtpModal(
        phoneNumber: 'Security Verification',
        onVerify: (code) {
          Navigator.pop(ctx);
          onVerify(code);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;
    final list = _staff.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final username = (s['username'] ?? '').toString().toLowerCase();
      final q = _search.toLowerCase();
      return name.contains(q) || username.contains(q);
    }).toList();

    return PaceOverlayLoader(
      isLoading: _isSubmitting,
      message: 'Processing staff request...',
      child: Column(
        children: [
          _buildHeader(isDark),
          _buildSearch(isDark),
          Expanded(
            child: _isLoading && _staff.isEmpty
                ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 6))
                : RefreshIndicator(
                    onRefresh: _fetchStaff,
                    color: PaceColors.purple,
                    child: list.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: PaceEmptyState(
                              title: 'No Staff Accounts',
                              subtitle: 'Add team members and configure granular role policies.',
                              onRetry: _fetchStaff,
                              isDark: isDark,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) => _buildStaffCard(list[i], isDark),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Staff Management',
                style: GoogleFonts.figtree(
                  color: PaceColors.getPrimaryText(isDark),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Team credentials and policy authorization',
                style: GoogleFonts.figtree(
                  color: PaceColors.getDimText(isDark),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _showStaffForm(),
            icon: const Icon(LucideIcons.userPlus, size: 16),
            label: Text('Add Staff', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: PaceColors.purple,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: PaceSearchBar(
        hint: 'Search by name or username...',
        isDark: isDark,
        onChanged: (v) => setState(() => _search = v),
      ),
    );
  }

  Widget _buildStaffCard(dynamic s, bool isDark) {
    final type = s['type']?.toString().toLowerCase() ?? 'user';
    final bool isAdmin = type == 'admin' || type == 'superadmin';
    final status = s['status']?.toString().toLowerCase() ?? 'active';
    final bool isActive = status == 'active';

    return InkWell(
      onTap: () => _showStaffForm(s),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PaceColors.getBorder(isDark)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isAdmin ? PaceColors.purple.withOpacity(0.1) : PaceColors.emerald.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  isAdmin ? LucideIcons.shieldCheck : LucideIcons.user,
                  color: isAdmin ? PaceColors.purple : PaceColors.emerald,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        s['name'] ?? 'Staff Member',
                        style: GoogleFonts.figtree(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: PaceColors.getPrimaryText(isDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PaceBadge(
                        label: isAdmin ? 'Admin' : 'Staff',
                        variant: isAdmin ? BadgeVariant.info : BadgeVariant.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${s['username'] ?? ''} • ${s['phone'] ?? 'No phone'}',
                    style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PaceBadge(
                  label: isActive ? 'Active' : 'Suspended',
                  variant: isActive ? BadgeVariant.success : BadgeVariant.danger,
                ),
                const SizedBox(height: 6),
                const Icon(LucideIcons.chevronRight, size: 14, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController c, IconData icon, bool isDark, {bool isPass = false, bool enabled = true, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: PaceColors.getSurface(isDark),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PaceColors.getBorder(isDark)),
          ),
          child: TextField(
            controller: c,
            enabled: enabled,
            obscureText: isPass,
            style: GoogleFonts.figtree(fontSize: 14, color: PaceColors.getPrimaryText(isDark)),
            decoration: InputDecoration(
              icon: Icon(icon, size: 16, color: PaceColors.getDimText(isDark)),
              border: InputBorder.none,
              hintText: hint,
              hintStyle: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getDimText(isDark).withOpacity(0.6)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChange, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: PaceColors.getSurface(isDark),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PaceColors.getBorder(isDark)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: PaceColors.getCard(isDark),
              items: items
                  .map((it) => DropdownMenuItem(
                        value: it,
                        child: Text(
                          it.substring(0, 1).toUpperCase() + it.substring(1),
                          style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
                        ),
                      ))
                  .toList(),
              onChanged: onChange,
            ),
          ),
        ),
      ],
    );
  }
}
