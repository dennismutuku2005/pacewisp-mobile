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
    
    final double totalRevenue = _users.fold(0, (sum, u) => sum + (double.tryParse(u['total_amount'].toString()) ?? 0));

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: Column(
        children: [
          _buildHeader(isDark),
          _buildSummaryBanner(isDark, totalRevenue),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PaceSearchBar(
              hint: 'FILTER BY PHONE...', 
              isDark: isDark, 
              onChanged: (val) => setState(() => _search = val)
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading && _users.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 6))
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  color: PaceColors.purple,
                  child: Column(
                    children: [
                      _buildTableHeader(isDark),
                      Expanded(
                        child: filtered.isEmpty 
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(), 
                              child: Container(
                                height: MediaQuery.of(context).size.height * 0.6,
                                child: PaceEmptyState(
                                  onRetry: _fetchData, 
                                  isDark: isDark,
                                  title: 'NO CYCLE DATA FOUND',
                                  subtitle: 'No synchronization found for this billing period.',
                                ),
                              )
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark).withOpacity(0.4), height: 1),
                              itemBuilder: (context, index) => _buildUserRow(filtered[index], isDark),
                            ),
                      ),
                    ],
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MONTHLY CUSTOMERS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
          Text('RECURRING CUSTOMERS WITH OVER 5 PURCHASES THIS CYCLE', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner(bool isDark, double revenue) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5),
        boxShadow: isDark ? [] : [BoxShadow(color: PaceColors.purple.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 10))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('CYCLE USERS', _users.length.toString(), isDark, PaceColors.purple),
          _statItem('CYCLE REVENUE', 'KES ${NumberFormat("#,###").format(revenue)}', isDark, PaceColors.emerald),
          _statItem('BILLING START', _formatDateShort(_cycleStart), isDark, Colors.blueAccent),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, bool isDark, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.2)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
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
          Expanded(flex: 3, child: Text('PHONE / SESSION', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
          Expanded(flex: 2, child: Text('CYCLE PAID', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
          Expanded(flex: 2, child: Text('STATUS', textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
        ],
      ),
    );
  }

  Widget _buildUserRow(dynamic u, bool isDark) {
    final bool isActive = (u['is_active'] == true || u['is_active'] == 1 || u['is_active'] == '1');
    final String lastBought = u['last_bought']?.toString().split(' ')[0] ?? 'N/A';
    final String phone = u['phone']?.toString() ?? 'PRIVATE';

    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerHistoryScreen(phone: phone)));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(phone, style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark), letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text('${u['purchase_count'] ?? 0} PURCHASES', style: TextStyle(fontSize: 7, color: PaceColors.purple, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Text('LATEST: ', style: TextStyle(fontSize: 7, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
                      Text(lastBought.toUpperCase(), style: TextStyle(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('KES ${NumberFormat("#,###").format(u['total_amount'] ?? 0)}', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.emerald)),
                  Text('CYCLE TOTAL', style: TextStyle(fontSize: 7, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PaceBadge(
                    label: isActive ? 'ONLINE' : 'EXPIRED', 
                    variant: isActive ? BadgeVariant.success : BadgeVariant.secondary
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateShort(String? date) {
    if (date == null || date.isEmpty) return 'CURRENT';
    try {
      final d = DateTime.parse(date);
      return DateFormat('dd MMM').format(d).toUpperCase();
    } catch (_) {
      return date.split(' ')[0].toUpperCase();
    }
  }
}
