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
          Text('MONTHLY CUSTOMERS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
          Text('DISTINCT USERS ACTIVE SINCE ${(_cycleStart.isEmpty ? "CURRENT CYCLE" : _cycleStart).toUpperCase()}', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildStatsCard(bool isDark, double revenue) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark).withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PaceColors.getBorder(isDark).withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('CYCLE USERS', _users.length.toString(), isDark),
          _statItem('CYCLE REVENUE', 'KES ${NumberFormat("#,###").format(revenue)}', isDark),
          _statItem('BILLING WINDOW', _cycleStart.isEmpty ? 'ACTIVE' : _cycleStart.split(' ')[0], isDark),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
      ],
    );
  }

  Widget _buildTableHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark).withOpacity(0.3),
        border: Border(
          top: BorderSide(color: PaceColors.getBorder(isDark).withOpacity(0.5)),
          bottom: BorderSide(color: PaceColors.getBorder(isDark).withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('PHONE NUMBER', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
          Expanded(flex: 2, child: Text('CYCLE PAID', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
          Expanded(flex: 2, child: Text('STATUS', textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
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
                  Text(u['phone']?.toString() ?? 'PRIVATE', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
                  const SizedBox(height: 4),
                  Text('FIRST EVER: ${u['first_bought']?.toString().split(' ')[0] ?? 'N/A'}', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text('KES ${u['total_amount']}', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.emerald)),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PaceBadge(label: isActive ? 'ONLINE' : 'EXPIRED', variant: isActive ? BadgeVariant.success : BadgeVariant.secondary),
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: PaceColors.getBorder(isDark), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Icon(LucideIcons.user, color: PaceColors.purple, size: 32),
            const SizedBox(height: 12),
            Text('BILLING SUMMARY', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: PaceColors.purple, letterSpacing: 1.5)),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildDrawerItem('CUSTOMER PHONE', u['phone']?.toString() ?? 'N/A', isDark),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildDrawerItem('FIRST BOUGHT', u['first_bought']?.toString().split(' ')[0] ?? 'N/A', isDark)),
                      Expanded(child: _buildDrawerItem('LAST SEEN', u['last_bought']?.toString().split(' ')[0] ?? 'N/A', isDark)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildDrawerItem('CYCLE REVENUE', 'KES ${u['total_amount'] ?? '0'}', isDark, valueColor: PaceColors.emerald)),
                      Expanded(child: _buildDrawerItem('STATUS', (u['is_active'] == 1 ? 'ONLINE' : 'EXPIRED'), isDark, valueColor: (u['is_active'] == 1 ? PaceColors.emerald : Colors.red))),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerHistoryScreen(phone: u['phone'].toString())));
                      },
                      icon: const Icon(LucideIcons.history, size: 16),
                      label: const Text('VIEW FULL HISTORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PaceColors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(String label, String value, bool isDark, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? PaceColors.getPrimaryText(isDark))),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.users, size: 48, color: PaceColors.getDimText(isDark).withOpacity(0.1)),
          const SizedBox(height: 16),
          Text('NO CUSTOMERS FOUND THIS CYCLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        ],
      ),
    );
  }
}

