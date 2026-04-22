import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/skeleton.dart';
import '../components/search_bar.dart';
import '../components/overlay_loader.dart';
import 'customer_history_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _customers = [];
  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _fetchLock = false;
  String _search = '';
  int _total = 0;
  int _onlineCount = 0;
  int _monthlyCount = 0;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchStats();
      _loadCustomers(1);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && !_fetchLock) {
        _loadCustomers(_page + 1, isAppend: true);
      }
    }
  }

  Future<void> _fetchStats() async {
    try {
      final res = await _api.getSummaryWidgets(forceRefresh: true);
      if (mounted && res != null && res['status'] == 'success') {
        setState(() {
          final widgets = res['data']?['widgets'];
          _onlineCount = int.tryParse(widgets?['online_customers']?['value']?.toString() ?? '0') ?? 0;
          _monthlyCount = int.tryParse(widgets?['customers_month']?['value']?.toString() ?? '0') ?? 0;
        });
      }
    } catch (e) {
      // Silent fail for stats
    }
  }

  /// Mirrors WispPortal: customerService.getCustomers({ page, limit: 12, search })
  /// Response: { status, data: [...], pagination: { total, has_more } }
  Future<void> _loadCustomers(int pageNum, {bool isAppend = false}) async {
    if (_fetchLock) return;
    _fetchLock = true;

    if (!isAppend) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final res = await _api.getCustomers(search: _search, page: pageNum, forceRefresh: true);

      if (mounted && res != null && res['status'] == 'success') {
        final newItems = res['data'] ?? [];
        final serverTotal = res['pagination']?['total'] ?? 0;
        final serverHasMore = res['pagination']?['has_more'] ?? false;

        setState(() {
          if (isAppend) {
            _customers.addAll(newItems);
          } else {
            _customers = List.from(newItems);
          }
          _total = serverTotal is int ? serverTotal : int.tryParse(serverTotal.toString()) ?? 0;
          _hasMore = serverHasMore == true;
          _page = pageNum;
        });
      } else if (mounted) {
        setState(() => _hasMore = false);
      }
    } catch (e) {
      if (mounted) setState(() => _hasMore = false);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
      _fetchLock = false;
    }
  }

  void _onSearchChanged(String val) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _search = val;
        _customers = [];
        _page = 1;
        _hasMore = true;
        _loadCustomers(1);
      }
    });
  }

  void _showCustomerDrawer(dynamic c, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getBackground(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('CUSTOMER INFO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: -0.5)),
            IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(ctx)),
          ]),
          const SizedBox(height: 20),
          _drawerRow('PHONE', c['phone']?.toString() ?? 'N/A', isDark),
          _drawerRow('MAC ADDRESS', c['mac']?.toString().toUpperCase() ?? 'N/A', isDark),
          _drawerRow('TOTAL SPENT', 'KES ${c['totalSpent'] ?? '0'}', isDark),
          _drawerRow('SESSIONS', c['sessions']?.toString() ?? '0', isDark),
          _drawerRow('LAST SEEN', c['lastSeen']?.toString() ?? 'N/A', isDark),
          _drawerRow('STATUS', (c['status']?.toString() ?? 'INACTIVE').toUpperCase(), isDark),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerHistoryScreen(phone: c['phone'].toString())));
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
          ]),
        ]),
      ),
    );
  }

  Widget _drawerRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: Column(children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark)))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CUSTOMER LIST', style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              Text('MANAGE YOUR CUSTOMERS', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ]),
            Row(children: [
              _statBadge(_monthlyCount.toString(), 'MONTHLY', Colors.indigo),
              const SizedBox(width: 8),
              _statBadge(_onlineCount.toString(), 'ONLINE', PaceColors.emerald),
            ]),
          ]),
        ),

        // Search + Record count
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: PaceSearchBar(hint: 'Search MAC or mobile number...', isDark: isDark, onChanged: _onSearchChanged),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(10), border: Border.all(color: PaceColors.getBorder(isDark))),
              child: Text('${_customers.length} of $_total', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 0.5)),
            ),
          ]),
        ),

        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark)))),
          child: Row(children: [
            Expanded(flex: 3, child: Text('PHONE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
            Expanded(flex: 2, child: Text('SPENT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
            Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
          ]),
        ),

        // List
        Expanded(
          child: _isLoading && _customers.isEmpty
            ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 10))
            : RefreshIndicator(
                onRefresh: () async {
                  _customers = [];
                  _page = 1;
                  _hasMore = true;
                  await _fetchStats();
                  await _loadCustomers(1);
                },
                color: PaceColors.purple,
                child: _customers.isEmpty
                  ? ListView(children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                      Center(child: Column(children: [
                        Icon(LucideIcons.users, size: 48, color: PaceColors.getDimText(isDark).withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text('NO CUSTOMERS FOUND', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
                      ])),
                    ])
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: _customers.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _customers.length) {
                          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)));
                        }
                        return _buildCustomerRow(_customers[index], isDark);
                      },
                    ),
              ),
        ),
      ]),
    );
  }

  Widget _statBadge(String val, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
      ]),
    );
  }

  Widget _buildCustomerRow(dynamic c, bool isDark) {
    final status = c['status']?.toString().toLowerCase() ?? 'inactive';
    final isOnline = status == 'active';
    final statusColor = isOnline ? PaceColors.emerald : Colors.redAccent;

    return InkWell(
      onTap: () => _showCustomerDrawer(c, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark)))),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['phone']?.toString() ?? 'N/A', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
              const SizedBox(height: 2),
              Text(c['mac']?.toString().toUpperCase() ?? '00:00:00:00:00:00', style: TextStyle(fontSize: 10, color: PaceColors.getDimText(isDark))),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Text('KES ${c['totalSpent'] ?? '0'}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.purple)),
          ),
          Expanded(
            flex: 2,
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(status.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: statusColor)),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, size: 16, color: PaceColors.getDimText(isDark)),
            ]),
          ),
        ]),
      ),
    );
  }
}
