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
  bool _isSubmitting = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchCachedThenLive();
  }

  Future<void> _fetchCachedThenLive() async {
    final cached = await _apiService.getStaff(forceRefresh: false);
    if (mounted && cached != null && _staff.isEmpty) {
      setState(() {
        _staff = cached['data'] ?? [];
        _isLoading = false;
      });
    }

    final live = await _apiService.getStaff(forceRefresh: true);
    if (mounted && live != null) {
      setState(() {
        _staff = live['data'] ?? [];
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showStaffForm([dynamic staff]) {
    final bool isEdit = staff != null;
    final nameController = TextEditingController(text: staff?['name']);
    final usernameController = TextEditingController(text: staff?['username']);
    final phoneController = TextEditingController(text: staff?['phone']);
    final passwordController = TextEditingController();
    String type = staff?['type'] ?? 'user';
    String status = staff?['status'] ?? 'active';
    List<String> policies = List<String>.from(staff?['policies'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: PaceColors.getBackground(true), // Always dark for premium feel
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: PaceColors.getBorder(true), borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 32),
                Text(isEdit ? 'UPDATE PERSONNEL' : 'PROVISION ACCOUNT', style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1.2)),
                Text(isEdit ? 'Modifying ${staff['username']}' : 'Assign credentials for new member', style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(true), fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                
                _buildField('FULL NAME', nameController, LucideIcons.user, true),
                const SizedBox(height: 16),
                _buildField('USERNAME', usernameController, LucideIcons.atSign, !isEdit, enabled: !isEdit),
                const SizedBox(height: 16),
                _buildField('PHONE NUMBER', phoneController, LucideIcons.phone, true),
                const SizedBox(height: 16),
                _buildField(isEdit ? 'NEW PASSWORD (OPTIONAL)' : 'PASSWORD', passwordController, LucideIcons.lock, !isEdit, isPassword: true),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(child: _buildDropdown('ROLE', type, ['user', 'admin'], (v) => setModalState(() => type = v!))),
                    const SizedBox(width: 16),
                    Expanded(child: _buildDropdown('STATUS', status, ['active', 'suspended', 'inactive'], (v) => setModalState(() => status = v!))),
                  ],
                ),
                
                if (type == 'user') ...[
                  const SizedBox(height: 32),
                  _buildPolicyHeader(),
                  const SizedBox(height: 16),
                  _buildPolicyGrid(policies, (id) => setModalState(() {
                    if (policies.contains(id)) policies.remove(id); else policies.add(id);
                  })),
                ],
                
                const SizedBox(height: 48),
                SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isSubmitting? null : () => _handleSave(
                      isEdit, 
                      staff?['id'], 
                      {
                        'name': nameController.text,
                        'username': usernameController.text,
                        'phone': phoneController.text,
                        'password': passwordController.text,
                        'type': type,
                        'status': status,
                        'policies': policies,
                      }
                    ),
                    style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: _isSubmitting 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : Text(isEdit ? 'SAVE CHANGES' : 'CREATE ACCOUNT', style: GoogleFonts.figtree(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave(bool isEdit, String? id, Map<String, dynamic> data, {String? otp}) async {
    // 1. Phone change detection (Portal parity)
    // For simplicity, we'll assume the API handles the 'otp_required' response
    
    final payload = {...data};
    if (otp != null) payload['otp_code'] = otp;

    setState(() => _isSubmitting = true);
    try {
      final res = isEdit 
        ? await _apiService.updateStaff(id!, payload) 
        : await _apiService.createStaff(payload);

      if (res?['status'] == 'otp_required') {
        _showOtpModal((code) => _handleSave(isEdit, id, data, otp: code));
      } else if (res?['status'] == 'success') {
        if (mounted) {
           Navigator.pop(context);
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Success'), backgroundColor: PaceColors.emerald));
           _fetchCachedThenLive();
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Error'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showOtpModal(Function(String) onVerify) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OtpModal(
        phoneNumber: Provider.of<SettingsProvider>(context, listen: false).activeAccount?.phone ?? '0700000000',
        onVerify: (code) {
           Navigator.pop(context);
           onVerify(code);
        },
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, bool required, {bool enabled = true, bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(true), letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: PaceColors.getSurface(true), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(true))),
          child: TextField(
            controller: controller,
            enabled: enabled,
            obscureText: isPassword,
            style: GoogleFonts.figtree(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              icon: Icon(icon, size: 16, color: PaceColors.getDimText(true)),
              border: InputBorder.none,
              hintText: 'Enter $label',
              hintStyle: TextStyle(color: PaceColors.getDimText(true).withOpacity(0.5), fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?)? onChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(true), letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: PaceColors.getSurface(true), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(true))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: PaceColors.getSurface(true),
              style: GoogleFonts.figtree(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              items: items.map((it) => DropdownMenuItem(value: it, child: Text(it.toUpperCase()))).toList(),
              onChanged: onChange,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPolicyHeader() {
    return Row(children: [
      const Icon(LucideIcons.shield, color: PaceColors.purple, size: 16),
      const SizedBox(width: 8),
      Text('SYSTEM POLICIES & PERMISSIONS', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1.2)),
    ]);
  }

  Widget _buildPolicyGrid(List<String> selected, Function(String) onToggle) {
    const policies = [
      {'id': 'view_dashboard', 'label': 'DASHBOARD'},
      {'id': 'view_entries', 'label': 'ENTRIES'},
      {'id': 'view_vouchers', 'label': 'VOUCHERS'},
      {'id': 'create_voucher', 'label': 'GEN VOUCHERS'},
      {'id': 'view_income', 'label': 'INCOME'},
      {'id': 'view_mpesa', 'label': 'M-PESA'},
      {'id': 'view_routers', 'label': 'ROUTERS'},
      {'id': 'manage_users', 'label': 'STAFF'},
      {'id': 'system_config', 'label': 'CONFIG'},
    ];
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: policies.map((p) {
        final bool isSelected = selected.contains(p['id']);
        return InkWell(
          onTap: () => onToggle(p['id']!),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? PaceColors.purple.withOpacity(0.1) : PaceColors.getSurface(true),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? PaceColors.purple : PaceColors.getBorder(true)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) const Icon(LucideIcons.checkCircle2, color: PaceColors.purple, size: 12).pOnly(right: 6),
                Text(p['label']!, style: GoogleFonts.figtree(fontSize: 9, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? PaceColors.purple : Colors.white)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    final filtered = _staff.where((s) {
      final name = s['name']?.toString().toLowerCase() ?? '';
      final user = s['username']?.toString().toLowerCase() ?? '';
      return name.contains(_search.toLowerCase()) || user.contains(_search.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showStaffForm(),
        backgroundColor: PaceColors.purple,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchCachedThenLive(),
        color: PaceColors.purple,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('STAFF MANAGEMENT', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
                Text('ADMIN ACCESS & POLICY CONTROL', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ]),
            ),
            _buildSearchBox(isDark),
            Expanded(
              child: _isLoading && _staff.isEmpty
                ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 10))
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildStaffCard(filtered[index], isDark),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
        child: TextField(
          onChanged: (val) => setState(() => _search = val),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
          decoration: InputDecoration(
            hintText: 'Search staff members...', 
            hintStyle: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 12), 
            icon: Icon(Icons.search_rounded, color: PaceColors.getDimText(isDark), size: 20), 
            border: InputBorder.none, 
          ),
        ),
      ),
    );
  }

  Widget _buildStaffCard(dynamic s, bool isDark) {
    final type = s['type']?.toString().toUpperCase() ?? 'STAFF';
    final status = s['status']?.toString().toUpperCase() ?? 'ACTIVE';
    final isPrimary = s['is_primary'] == true || s['is_primary'] == 1;

    return InkWell(
      onTap: () => _showStaffForm(s),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
        child: Row(children: [
          CircleAvatar(radius: 20, backgroundColor: PaceColors.purple.withOpacity(0.1), child: Icon(isPrimary ? LucideIcons.shield : LucideIcons.user, color: PaceColors.purple, size: 20)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['name'] ?? 'STAFF', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w800, color: PaceColors.getPrimaryText(isDark), letterSpacing: -0.2)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(LucideIcons.atSign, size: 8, color: PaceColors.getDimText(isDark)),
              const SizedBox(width: 4),
              Text(s['username'] ?? '', style: GoogleFonts.figtree(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            PaceBadge(label: type, variant: type == 'ADMIN' || type == 'SUPERADMIN' ? BadgeVariant.info : BadgeVariant.secondary),
            const SizedBox(height: 6),
            PaceBadge(label: status, variant: status == 'ACTIVE' ? BadgeVariant.success : BadgeVariant.error),
          ]),
        ]),
      ),
    );
  }
}

extension PaddingExtension on Widget {
  Widget pOnly({double left = 0, double right = 0, double top = 0, double bottom = 0}) => Padding(padding: EdgeInsets.only(left: left, right: right, top: top, bottom: bottom), child: this);
}
