import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
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

    final filtered = _users.where((u) => (u['phone'] ?? '').toString().contains(_search)).toList();
    final totalRevenue = _users.fold<double>(0, (sum, u) => sum + (double.tryParse(u['total_amount'].toString()) ?? 0));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: PaceColors.purple,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MONTHLY CUSTOMERS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
                Text('DISTINCT USERS SINCE ${_cycleStart.toUpperCase()}', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ]),
            ),
            
            _buildSummary(isDark, totalRevenue),
            _buildSearchBox(isDark),

            Expanded(
              child: _isLoading && _users.isEmpty
                ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 10))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildUserCard(filtered[index], isDark),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(bool isDark, double revenue) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PaceColors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PaceColors.purple.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _buildSummaryItem('CYCLE USERS', _users.length.toString(), LucideIcons.users, isDark),
          Container(width: 1, height: 40, color: PaceColors.purple.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 20)),
          _buildSummaryItem('CYCLE REVENUE', 'KES ${revenue.toStringAsFixed(0)}', LucideIcons.creditCard, isDark),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, bool isDark) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 10, color: PaceColors.purple),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.black, color: PaceColors.purple, letterSpacing: 1)),
          ]),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark))),
        ],
      ),
    );
  }

  Widget _buildSearchBox(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
        child: TextField(
          onChanged: (val) => setState(() => _search = val),
          keyboardType: TextInputType.phone,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
          decoration: InputDecoration(
            hintText: 'Filter by phone...', 
            hintStyle: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 12), 
            icon: Icon(LucideIcons.search, color: PaceColors.getDimText(isDark), size: 18), 
            border: InputBorder.none, 
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(dynamic u, bool isDark) {
    final bool isActive = u['is_active'] == true || u['is_active'] == 1;
    
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerHistoryScreen(phone: u['phone'].toString()))),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
        child: Row(children: [
          CircleAvatar(radius: 20, backgroundColor: PaceColors.purple.withOpacity(0.1), child: Icon(LucideIcons.user, color: PaceColors.purple, size: 20)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u['phone']?.toString() ?? 'PRIVATE', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w800, color: PaceColors.getPrimaryText(isDark), letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text('PAID KES ${u['total_amount']}', style: GoogleFonts.figtree(fontSize: 9, color: PaceColors.purple, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            PaceBadge(label: isActive ? 'ONLINE' : 'EXPIRED', variant: isActive ? BadgeVariant.success : BadgeVariant.error),
            const SizedBox(height: 6),
            Text(u['last_bought']?.toString().split(' ')[0] ?? '', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
          ]),
        ]),
      ),
    );
  }
}
