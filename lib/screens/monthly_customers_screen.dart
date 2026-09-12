import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/empty_state.dart';
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
  final _currencyFormat = NumberFormat("#,###", "en_US");

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
    try {
      final res = await _apiService.getMonthlyCustomers(forceRefresh: true);
      if (mounted && res != null) {
        setState(() {
          _users = res['users'] ?? res['data'] ?? [];
          _cycleStart = res['cycle_start']?.toString() ?? '';
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

    final filtered = _users.where((u) {
      final phone = (u['phone'] ?? '').toString().toLowerCase();
      return phone.contains(_search.toLowerCase());
    }).toList();

    final double totalRevenue = _users.fold(0, (sum, u) => sum + (double.tryParse(u['total_amount']?.toString() ?? '0') ?? 0));

    return Column(
      children: [
        _buildHeader(isDark),
        _buildSummaryCards(isDark, totalRevenue),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: PaceSearchBar(
            hint: 'Search monthly customer by phone...',
            isDark: isDark,
            onChanged: (val) => setState(() => _search = val),
          ),
        ),
        Expanded(
          child: _isLoading && _users.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 6))
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  color: PaceColors.purple,
                  child: filtered.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: PaceEmptyState(
                            title: 'No Monthly Customers',
                            subtitle: 'Recurring customers for this billing cycle will appear here.',
                            onRetry: _fetchData,
                            isDark: isDark,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Customers',
            style: GoogleFonts.figtree(
              color: PaceColors.getPrimaryText(isDark),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Recurring hotspot subscriber analytics and cycle billing',
            style: GoogleFonts.figtree(
              color: PaceColors.getDimText(isDark),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark, double revenue) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _statCard('Cycle Users', _users.length.toString(), LucideIcons.users, PaceColors.purple, isDark),
          const SizedBox(width: 10),
          _statCard('Cycle Revenue', 'KES ${_currencyFormat.format(revenue)}', LucideIcons.trendingUp, PaceColors.emerald, isDark),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.figtree(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: PaceColors.getPrimaryText(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(dynamic u, bool isDark) {
    final phone = u['phone']?.toString() ?? 'Unknown';
    final totalSpent = u['total_amount']?.toString() ?? '0';
    final txnCount = u['total_transactions'] ?? u['payments_count'] ?? 1;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CustomerHistoryScreen(phone: phone)),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PaceColors.getBorder(isDark)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PaceColors.purple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.user, color: PaceColors.purple, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    phone,
                    style: GoogleFonts.figtree(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: PaceColors.getPrimaryText(isDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$txnCount billing transactions',
                    style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'KES $totalSpent',
                  style: GoogleFonts.figtree(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: PaceColors.emerald,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(LucideIcons.chevronRight, size: 14, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
