import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
import '../components/search_bar.dart';
import 'customer_history_screen.dart';

class MonthlyCustomersScreen extends StatefulWidget {
  const MonthlyCustomersScreen({super.key});

  @override
  State<MonthlyCustomersScreen> createState() => _MonthlyCustomersScreenState();
}

class _MonthlyCustomersScreenState extends State<MonthlyCustomersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _users = [];
  String _cycleStart = '';
  bool _isLoading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final res = await _apiService.getMonthlyCustomers(forceRefresh: true);
    if (mounted) {
      setState(() {
        _users = res?['users'] ?? [];
        _cycleStart = res?['cycle_start'] ?? '';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    if (!settings.hasPolicy('view_customers')) {
      return const Center(child: Text('ACCESS RESTRICTED'));
    }

    final filtered = _users.where((u) => (u['phone'] ?? '').toString().contains(_search)).toList();
    final totalRevenue = _users.fold<double>(0, (sum, u) => sum + (double.tryParse(u['total_amount'].toString()) ?? 0));

    return Column(
      children: [
        _buildHeader(isDark),
        _buildMonthlyStats(isDark, totalRevenue),
        _buildSearchBox(isDark),
        Expanded(
          child: _isLoading && _users.isEmpty
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 8))
            : RefreshIndicator(
                onRefresh: _fetchData,
                color: PaceColors.purple,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                  itemBuilder: (context, index) => _buildUserCard(filtered[index], isDark),
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
          Text('MONTHLY RECURRING', style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
          Text('DISTINCT USERS SINCE ${_cycleStart.toUpperCase()}', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildMonthlyStats(bool isDark, double revenue) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.purple.withOpacity(0.1))),
      child: Row(children: [
        _buildStatBox('UNIQUE USERS', _users.length.toString(), isDark),
        Container(width: 1.5, height: 40, color: PaceColors.purple.withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 24)),
        _buildStatBox('CYCLE REVENUE', 'KES ${NumberFormat("#,###").format(revenue)}', isDark),
      ]),
    );
  }

  Widget _buildStatBox(String label, String value, bool isDark) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
    ]));
  }

  Widget _buildSearchBox(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: PaceSearchBar(
        hint: 'Filter by phone number...',
        isDark: isDark,
        onChanged: (val) => setState(() => _search = val),
      ),
    );
  }

  Widget _buildUserCard(dynamic u, bool isDark) {
    final bool isActive = u['is_active'] == true || u['is_active'] == 1;
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerHistoryScreen(phone: u['phone'].toString()))),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u['phone']?.toString() ?? 'PRIVATE', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w800, color: PaceColors.getPrimaryText(isDark))),
                Text('LATEST CONTRIBUTION: KES ${u['total_amount']}', style: TextStyle(fontSize: 9, color: PaceColors.purple, fontWeight: FontWeight.bold)),
              ]),
            ),
            PaceBadge(label: isActive ? 'ACTIVE' : 'EXPIRED', variant: isActive ? BadgeVariant.success : BadgeVariant.error),
          ],
        ),
      ),
    );
  }
}
