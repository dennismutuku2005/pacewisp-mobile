import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
import '../components/search_bar.dart';
import '../components/overlay_loader.dart';
import 'customer_history_screen.dart';

class ActiveCustomersScreen extends StatefulWidget {
  const ActiveCustomersScreen({super.key});

  @override
  State<ActiveCustomersScreen> createState() => _ActiveCustomersScreenState();
}

class _ActiveCustomersScreenState extends State<ActiveCustomersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _active = [];
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
    final res = await _apiService.getActiveCustomers(forceRefresh: true);
    if (mounted) {
      setState(() {
        // active_connections.php returns 'data'
        _active = res?['data'] ?? res?['users'] ?? [];
        _isLoading = false;
      });
    }
  }

  void _showSessionDrawer(dynamic u, bool isDark) {
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
                Text('SESSION DETAILS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: -0.5)),
                IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 20),
            _drawerRow('PHONE', u['phone']?.toString() ?? 'N/A', isDark),
            _drawerRow('PLAN', u['plan']?.toString() ?? 'N/A', isDark),
            _drawerRow('AMOUNT', 'KES ${u['amount'] ?? '0'}', isDark),
            _drawerRow('RECEIPT', u['mpesa_code']?.toString() ?? 'Voucher', isDark),
            _drawerRow('STARTED', u['created_at']?.toString() ?? 'N/A', isDark),
            _drawerRow('EXPIRES', u['expire_time']?.toString() ?? 'N/A', isDark),
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
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    if (!settings.hasPolicy('view_active_users')) {
      return const Center(child: Text('ACCESS RESTRICTED'));
    }

    final filtered = _active.where((u) => 
      (u['phone'] ?? '').toString().contains(_search) || 
      (u['mpesa_code'] ?? '').toString().toLowerCase().contains(_search.toLowerCase())
    ).toList();

    return PaceOverlayLoader(
      isLoading: _isProcessing,
      message: 'Processing...',
      child: Column(
        children: [
          _buildHeader(isDark),
          _buildSearchBox(isDark),
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark)))),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('PHONE / RECEIPT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
                Expanded(flex: 2, child: Text('PLAN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
                Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
              ],
            ),
          ),
          Expanded(
            child: _isLoading && _active.isEmpty
              ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 10))
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  color: PaceColors.purple,
                  child: filtered.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(LucideIcons.zap, size: 48, color: PaceColors.getDimText(isDark).withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text('NO ACTIVE SESSIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
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
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LIVE CONNECTIONS', style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          Text('CURRENTLY ONLINE HOTSPOT SESSIONS', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildSearchBox(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: PaceSearchBar(
        hint: 'Filter by phone or receipt...', 
        isDark: isDark,
        onChanged: (val) => setState(() => _search = val),
      ),
    );
  }

  Widget _buildUserRow(dynamic u, bool isDark) {
    return InkWell(
      onTap: () => _showSessionDrawer(u, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u['phone']?.toString() ?? 'N/A', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                  const SizedBox(height: 2),
                  Text(u['mpesa_code']?.toString() ?? 'VOUCHER', style: TextStyle(fontSize: 10, color: PaceColors.getDimText(isDark))),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(u['plan']?.toString() ?? 'N/A', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: PaceColors.emerald.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: const Text('ONLINE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.emerald)),
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
