import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
import '../components/empty_state.dart';

class UserPolicyScreen extends StatefulWidget {
  const UserPolicyScreen({super.key});

  @override
  State<UserPolicyScreen> createState() => _UserPolicyScreenState();
}

class _UserPolicyScreenState extends State<UserPolicyScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _staff = [];

  final List<Map<String, String>> _availablePolicies = [
    {'id': 'create_voucher', 'label': 'Create Vouchers', 'description': 'Generate and manage access tokens'},
    {'id': 'view_income', 'label': 'View Income', 'description': 'Analyze revenue and financial trends'},
    {'id': 'manage_users', 'label': 'System Policy', 'description': 'Manage other staff roles and levels'},
    {'id': 'view_routers', 'label': 'View Routers', 'description': 'Monitor station hardware connectivity'},
    {'id': 'change_payment', 'label': 'Payment Settings', 'description': 'Configure M-Pesa and KCB integrations'},
    {'id': 'manage_customers', 'label': 'Manage Customers', 'description': 'Edit, block or delete customer records'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getStaff(forceRefresh: true);
      if (mounted && res != null) {
        setState(() {
          _staff = res['data'] ?? [];
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
          child: _isLoading && _staff.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 6))
              : RefreshIndicator(
                  onRefresh: _fetchStaff,
                  color: PaceColors.purple,
                  child: _staff.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: PaceEmptyState(
                            title: 'No Policy Roles Found',
                            subtitle: 'Staff accounts and policy assignments will appear here.',
                            onRetry: _fetchStaff,
                            isDark: isDark,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                          itemCount: _staff.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _buildStaffCard(_staff[index], isDark),
                        ),
                ),
        ),
      ],
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
          Text(
            'User Policies',
            style: GoogleFonts.figtree(
              color: PaceColors.getPrimaryText(isDark),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Granular permissions and role enforcement for staff members',
            style: GoogleFonts.figtree(
              color: PaceColors.getDimText(isDark),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(dynamic s, bool isDark) {
    final name = s['name'] ?? s['username'] ?? 'Staff Member';
    final role = (s['type'] ?? 'user').toString().toUpperCase();
    final List policies = s['policies'] ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PaceColors.purple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.shield, color: PaceColors.purple, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                    ),
                    Text(
                      '@${s['username'] ?? ''} • $role',
                      style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark)),
                    ),
                  ],
                ),
              ),
              PaceBadge(label: role, variant: role == 'ADMIN' ? BadgeVariant.info : BadgeVariant.secondary),
            ],
          ),
          if (policies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: policies.map((p) {
                return PaceBadge(
                  label: p.toString().replaceAll('_', ' '),
                  variant: BadgeVariant.secondary,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
