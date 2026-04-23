import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
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
    {'id': 'change_payment', 'label': 'Payment Settings', 'description': 'Configure MPESA and KCB integrations'},
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
      final res = await _apiService.getLogs(limit: 50); // Re-using an endpoint in place of a full staff management one
      if (mounted && res != null) {
        setState(() {
          _staff = res['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: _isLoading && _staff.isEmpty
        ? const SkeletonList()
        : RefreshIndicator(
            onRefresh: _fetchStaff,
            color: PaceColors.purple,
            child: _staff.isEmpty
              ? SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: PaceEmptyState(onRetry: _fetchStaff, isDark: isDark))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _staff.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final s = _staff[index];
                    return _buildStaffMember(s, isDark);
                  },
                ),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: PaceColors.purple,
        child: const Icon(Icons.add_moderator, color: Colors.white),
      ),
    );
  }

  Widget _buildStaffMember(dynamic s, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaceColors.getBorder(isDark)),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.shield_outlined, color: PaceColors.purple, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['username']?.toString().toUpperCase() ?? 'STAFF', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: -0.2)),
                    Text(s['action'] ?? 'SYSTEM ADMINISTRATOR', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Colors.blueGrey),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availablePolicies.take(3).map((p) => _buildPolicyBadge(p['label']!, isDark)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyBadge(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? PaceColors.purple.withOpacity(0.1) : PaceColors.purple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: PaceColors.purple.withOpacity(0.2)),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.purple, letterSpacing: 0.5),
      ),
    );
  }
}
