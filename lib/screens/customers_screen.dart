import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _customers = [];
  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _search = '';
  int _total = 0;
  int _onlineCount = 0;
  int _monthlyCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _fetchCustomers();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchMoreCustomers();
      }
    }
  }

  Future<void> _fetchStats() async {
    // 1. Silent Cache
    final cached = await _apiService.getSummaryWidgets(forceRefresh: false);
    if (mounted && cached != null) _processStats(cached);
    
    // 2. Live Refresh
    final live = await _apiService.getSummaryWidgets(forceRefresh: true);
    if (mounted && live != null) _processStats(live);
  }

  void _processStats(Map<String, dynamic> widgets) {
    setState(() {
      _onlineCount = int.tryParse(widgets['data']?['widgets']?['online_customers']?['value']?.toString() ?? '0') ?? 0;
      _monthlyCount = int.tryParse(widgets['data']?['widgets']?['customers_month']?['value']?.toString() ?? '0') ?? 0;
    });
  }

  Future<void> _fetchCustomers({bool force = false}) async {
    if (!force) {
      // 1. SILENT CACHE LOAD
      final cached = await _apiService.getCustomers(search: _search, page: 1, forceRefresh: false);
      if (mounted && cached != null) {
        _processCustomers(cached, 1);
        _isLoading = false;
      } else {
        setState(() => _isLoading = true);
      }
    }

    // 2. LIVE REFRESH
    final live = await _apiService.getCustomers(search: _search, page: 1, forceRefresh: true);
    if (mounted && live != null) {
      _processCustomers(live, 1);
      _isLoading = false;
    }
  }

  void _processCustomers(Map<String, dynamic> res, int page) {
    setState(() {
      final newItems = res['data']?['customers'] ?? res['data'] ?? [];
      if (page == 1) {
        _customers = newItems;
      } else {
        _customers.addAll(newItems);
      }
      _hasMore = res['pagination']?['has_more'] ?? res['data']?['pagination']?['has_more'] ?? false;
      _total = res['pagination']?['total'] ?? res['data']?['pagination']?['total'] ?? 0;
      _page = page;
    });
  }

  Future<void> _fetchMoreCustomers() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final res = await _apiService.getCustomers(search: _search, page: nextPage);
    if (mounted) {
      setState(() {
        final newItems = res?['data']?['customers'] ?? res?['data'] ?? [];
        _customers.addAll(newItems);
        _hasMore = res?['pagination']?['has_more'] ?? res?['data']?['pagination']?['has_more'] ?? false;
        _page = nextPage;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Column(
      children: [
        _buildHeader(isDark),
        _buildStatsBar(isDark),
        _buildSearchBox(isDark),
        Expanded(
          child: _isLoading 
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 8))
            : RefreshIndicator(
                onRefresh: () async { _fetchStats(); await _fetchCustomers(force: true); },
                color: PaceColors.purple,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _customers.length + (_isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                  itemBuilder: (context, index) {
                    if (index == _customers.length) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)));
                    return _buildCustomerItem(_customers[index], isDark);
                  },
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('CUSTOMERS', style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: PaceColors.purple.withOpacity(0.1))),
                child: Text('RECORDS: $_total', style: const TextStyle(color: PaceColors.purple, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ),
            ],
          ),
          Text('CORE USER DIRECTORY', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildStatsBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _buildStatItem('MONTHLY', _monthlyCount.toString(), Colors.indigo, isDark),
          const SizedBox(width: 12),
          _buildStatItem('ONLINE', _onlineCount.toString(), PaceColors.emerald, isDark, isLive: true),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, bool isDark, {bool isLive = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isLive) ...[
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: PaceColors.emerald, shape: BoxShape.circle), child: const SizedBox.shrink()),
                  const SizedBox(width: 6),
                ],
                Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color, fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: PaceColors.getSurface(isDark), 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)
        ),
        child: TextField(
          onChanged: (val) { setState(() => _search = val); _fetchCustomers(); },
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
          decoration: InputDecoration(
            hintText: 'Search Phone or MAC...', 
            hintStyle: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 12, fontWeight: FontWeight.bold), 
            prefixIcon: Icon(Icons.search_rounded, color: PaceColors.purple.withOpacity(0.5), size: 20), 
            border: InputBorder.none, 
            contentPadding: const EdgeInsets.symmetric(vertical: 14)
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerItem(dynamic customer, bool isDark) {
    final bool isActive = customer['status'] == 'Active' || customer['status'] == '1';
    final String phone = customer['phone'] ?? '0000000000';
    final String mac = (customer['mac']?.toString().toUpperCase() ?? '00:00:00:00:00:00');
    
    return InkWell(
      onTap: () => _showCustomerDetails(customer, isDark),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10), 
              decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), 
              child: const Icon(Icons.person_pin_rounded, color: PaceColors.purple, size: 22)
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(phone, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1, fontFamily: 'monospace')),
                  const SizedBox(height: 2),
                  Text(mac, style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('KES ${customer['totalSpent']}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark), fontFamily: 'monospace')),
                const SizedBox(height: 6),
                PaceBadge(
                  label: isActive ? 'ACTIVE' : 'INACTIVE', 
                  variant: isActive ? BadgeVariant.success : BadgeVariant.error
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 18, color: PaceColors.getBorder(isDark)),
          ],
        ),
      ),
    );
  }

  void _showCustomerDetails(dynamic row, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: PaceColors.getBackground(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: PaceColors.getBorder(isDark)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: PaceColors.getBorder(isDark), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 32),
            const Icon(Icons.account_circle_rounded, color: PaceColors.purple, size: 64),
            const SizedBox(height: 16),
            Text(row['phone'] ?? 'Unknown User', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1, fontFamily: 'monospace')),
            Text(row['id'] ?? 'CUST-ID', style: TextStyle(fontSize: 10, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900, letterSpacing: 2)),
            
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            
            _buildDetailRow(Icons.data_usage_rounded, 'TOTAL SPENT', 'KES ${row['totalSpent']}', isDark),
            const SizedBox(height: 20),
            _buildDetailRow(Icons.history_toggle_off_rounded, 'TOTAL SESSIONS', '${row['sessions']} CONNECTS', isDark),
            const SizedBox(height: 20),
            _buildDetailRow(Icons.calendar_month_rounded, 'LAST SEEN', row['lastSeen'] ?? 'N/A', isDark),
            
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleDelete(row['phone']);
                    },
                    icon: const Icon(Icons.delete_forever_rounded, size: 18),
                    label: const Text('PURGE RECORD', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.08),
                      foregroundColor: Colors.red,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PaceColors.getSurface(isDark),
                      foregroundColor: PaceColors.getPrimaryText(isDark),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: PaceColors.getBorder(isDark))),
                    ),
                    child: const Text('DISMISS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: PaceColors.purple, size: 18),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark), fontFamily: 'monospace')),
          ],
        ),
      ],
    );
  }

  Future<void> _handleDelete(String phone) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Purge'),
        content: Text('Delete all connection records for $phone? This action is permanent.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('PURGE', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _apiService.deleteCustomer(phone);
      if (res?['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer history purged successfully'), backgroundColor: Colors.green));
        _fetchCustomers(force: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Failed to purge records'), backgroundColor: Colors.red));
      }
    }
  }
}
