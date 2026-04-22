import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
import '../components/search_bar.dart';
import '../components/overlay_loader.dart';
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
  bool _isProcessing = false;
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

  void _showUserDrawer(dynamic u, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getBackground(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('BILLING INFO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: -0.5)),
                IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 20),
            _drawerRow('PHONE', u['phone']?.toString() ?? 'N/A', isDark),
            _drawerRow('FIRST BOUGHT', u['first_bought']?.toString() ?? 'N/A', isDark),
            _drawerRow('CYCLE START', u['first_purchase_this_month']?.toString() ?? 'N/A', isDark),
            _drawerRow('LAST PURCHASE', u['last_bought']?.toString() ?? 'N/A', isDark),
            _drawerRow('CYCLE REVENUE', 'KES ${u['total_amount'] ?? '0'}', isDark),
            _drawerRow('STATUS', (u['is_active'] == 1 ? 'ACTIVE' : 'EXPIRED'), isDark),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerHistoryScreen(phone: u['phone'].toString())));
                    },
                    icon: const Icon(LucideIcons.history, size: 16),
                    label: const Text('HISTORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: PaceColors.getBorder(isDark)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(LucideIcons.checkCircle, size: 16),
                    label: const Text('DONE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PaceColors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: MonthlyCustomersScreen.build() called');
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    if (!settings.hasPolicy('view_customers')) {
      return const Center(child: Text('ACCESS RESTRICTED'));
    }

    final filtered = _users.where((u) => (u['phone'] ?? '').toString().contains(_search)).toList();
    final totalRevenue = _users.fold<double>(0, (sum, u) => sum + (double.tryParse(u['total_amount'].toString()) ?? 0));

    return PaceOverlayLoader(
      isLoading: _isProcessing,
      message: 'Processing...',
      child: Column(
        children: [
          _buildHeader(isDark),
          _buildMonthlyStats(isDark, totalRevenue),
          _buildSearchBox(isDark),
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark)))),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('CUSTOMER PHONE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
                Expanded(flex: 2, child: Text('CONTRIBUTION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
                Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
              ],
            ),
          ),
          Expanded(
            child: _isLoading && _users.isEmpty
              ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 10))
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  color: PaceColors.purple,
                  child: filtered.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(LucideIcons.calendarDays, size: 48, color: PaceColors.getDimText(isDark).withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text('NO RECURRING USERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
                      ]))
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                        itemBuilder: (context, index) => _buildUserRow(filtered[index], isDark),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MONTHLY RECURRING', style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
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

  Widget _buildUserRow(dynamic u, bool isDark) {
    final bool isActive = u['is_active'] == true || u['is_active'] == 1;
    Color statusColor = isActive ? PaceColors.emerald : Colors.redAccent;

    return InkWell(
      onTap: () => _showUserDrawer(u, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u['phone']?.toString() ?? 'PRIVATE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                  const SizedBox(height: 2),
                  Text('SINCE ${u['first_bought']?.toString().split(' ')[0] ?? 'N/A'}', style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark))),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text('KES ${u['total_amount']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(isActive ? 'ACTIVE' : 'EXPIRED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: statusColor)),
                  ),
                  const Spacer(),
                  Icon(Icons.more_vert, size: 16, color: PaceColors.getDimText(isDark)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
