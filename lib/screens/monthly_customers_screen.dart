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
        final dynamic raw = res;
        _users = raw?['users'] ?? raw?['data'] ?? raw?['customers'] ?? [];
        _cycleStart = raw?['cycle_start'] ?? '';
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

    return Container(
      color: PaceColors.getBackground(isDark),
      child: Column(
        children: [
          _buildHeader(isDark),
          _buildStatsCard(isDark, totalRevenue),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PaceSearchBar(
              hint: 'Filter distinct users...', 
              isDark: isDark, 
              onChanged: (val) => setState(() => _search = val)
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading && _users.isEmpty 
              ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 10))
              : Column(
                  children: [
                    _buildTableHeader(isDark),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetchData,
                        color: PaceColors.purple,
                        child: filtered.isEmpty 
                          ? _buildEmptyState(isDark)
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark).withOpacity(0.4), height: 1),
                              itemBuilder: (context, index) => _buildUserRow(filtered[index], isDark),
                            ),
                      ),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MONTHLY RECURRING', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          Text('DISTINCT USERS SINCE ${_cycleStart.toUpperCase()}', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildStatsCard(bool isDark, double revenue) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PaceColors.purple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PaceColors.purple.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          _buildStatBox('UNIQUE USERS', _users.length.toString(), isDark),
          Container(width: 1.5, height: 40, color: PaceColors.purple.withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 24)),
          _buildStatBox('CYCLE REVENUE', 'KES ${NumberFormat("#,###").format(revenue)}', isDark),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, bool isDark) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark).withOpacity(0.3),
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark).withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('CUSTOMER PHONE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
          Expanded(flex: 2, child: Text('CONTRIBUTION', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
          Expanded(flex: 2, child: Text('STATUS', textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
        ],
      ),
    );
  }

  Widget _buildUserRow(dynamic u, bool isDark) {
    final bool isActive = u['is_active'] == true || u['is_active'] == 1;

    return InkWell(
      onTap: () => _showUserDrawer(u, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u['phone']?.toString() ?? 'PRIVATE', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                  const SizedBox(height: 4),
                  Text('SINCE ${u['first_bought']?.toString().split(' ')[0] ?? 'N/A'}', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text('KES ${u['total_amount']}', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.emerald)),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PaceBadge(label: isActive ? 'ACTIVE' : 'EXPIRED', variant: isActive ? BadgeVariant.success : BadgeVariant.secondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDrawer(dynamic u, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getBackground(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('BILLING SUMMARY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: -0.5)),
                IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 24),
            _buildDrawerInfo('CUSTOMER PHONE', u['phone']?.toString() ?? 'N/A', isDark, isBig: true),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildDrawerInfo('FIRST BOUGHT', u['first_bought']?.toString() ?? 'N/A', isDark)),
                Expanded(child: _buildDrawerInfo('CYCLE START', u['first_purchase_this_month']?.toString() ?? 'N/A', isDark)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildDrawerInfo('CYCLE REVENUE', 'KES ${u['total_amount'] ?? '0'}', isDark)),
                Expanded(child: _buildDrawerInfo('STATUS', (u['is_active'] == 1 ? 'ACTIVE' : 'EXPIRED'), isDark)),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerHistoryScreen(phone: u['phone'].toString())));
                    },
                    icon: const Icon(LucideIcons.history, size: 16),
                    label: const Text('VIEW FULL HISTORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PaceColors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerInfo(String label, String value, bool isDark, {bool isBig = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: isBig ? 18 : 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.calendarX, size: 48, color: PaceColors.getDimText(isDark).withOpacity(0.1)),
          const SizedBox(height: 16),
          Text('NO RECURRING USERS THIS CYCLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        ],
      ),
    );
  }
}
