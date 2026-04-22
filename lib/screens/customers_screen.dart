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
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _customers = [];
  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isProcessing = false;
  bool _hasMore = true;
  String _search = '';
  int _total = 0;
  int _onlineCount = 0;
  int _monthlyCount = 0;
  Timer? _searchDebounce;

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
    final res = await _apiService.getSummaryWidgets(forceRefresh: true);
    if (mounted && res != null) {
      setState(() {
        _onlineCount = int.tryParse(res['data']?['widgets']?['online_customers']?['value']?.toString() ?? '0') ?? 0;
        _monthlyCount = int.tryParse(res['data']?['widgets']?['customers_month']?['value']?.toString() ?? '0') ?? 0;
      });
    }
  }

  Future<void> _fetchCustomers({bool force = false}) async {
    if (!force && _customers.isNotEmpty) return;
    
    setState(() => _isLoading = true);
    final res = await _apiService.getCustomers(search: _search, page: 1, forceRefresh: force);
    if (mounted) {
      if (res != null) {
        _processCustomers(res, 1);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  void _processCustomers(Map<String, dynamic> res, int page) {
    setState(() {
      final items = res['data'] is List ? res['data'] : (res['data']?['data'] ?? res['customers'] ?? []);
      if (page == 1) _customers = items;
      else _customers.addAll(items);

      final p = res['pagination'] ?? res['data']?['pagination'];
      if (p is Map) {
        _hasMore = p['has_more'] ?? false;
        _total = p['total'] ?? 0;
      } else {
        _hasMore = items.length >= 12; // Fallback
      }
      _page = page;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String val) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _search = val;
        _isLoading = true;
        _customers = [];
        _page = 1;
      });
      _fetchCustomers(force: true);
    });
  }

  Future<void> _fetchMoreCustomers() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final res = await _apiService.getCustomers(search: _search, page: nextPage);
    if (mounted) {
      if (res != null) {
        _processCustomers(res, nextPage);
      }
      setState(() => _isLoadingMore = false);
    }
  }

  void _showCustomerDrawer(dynamic c, bool isDark) {
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
                Text('CUSTOMER INFO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: -0.5)),
                IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 20),
            _drawerRow('PHONE', c['phone']?.toString() ?? 'N/A', isDark),
            _drawerRow('MAC ADDRESS', c['mac']?.toString().toUpperCase() ?? 'N/A', isDark),
            _drawerRow('TOTAL SPENT', 'KES ${c['totalSpent'] ?? '0'}', isDark),
            _drawerRow('SESSIONS', c['sessions']?.toString() ?? '0', isDark),
            _drawerRow('LAST SEEN', c['lastSeen']?.toString() ?? 'N/A', isDark),
            _drawerRow('STATUS', (c['status']?.toString() ?? 'INACTIVE').toUpperCase(), isDark),
            const SizedBox(height: 24),
            Row(
              children: [
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
                Expanded(flex: 3, child: Text('CUSTOMER PHONE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
                Expanded(flex: 2, child: Text('TOTAL SPENT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
                Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
              ],
            ),
          ),
          Expanded(
            child: _isLoading && _customers.isEmpty
              ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 10))
              : RefreshIndicator(
                  onRefresh: () async { _fetchStats(); await _fetchCustomers(force: true); },
                  color: PaceColors.purple,
                  child: _customers.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(LucideIcons.users, size: 48, color: PaceColors.getDimText(isDark).withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text('NO CUSTOMERS FOUND', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
                      ]))
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: _customers.length + (_isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                        itemBuilder: (context, index) {
                          if (index < _customers.length) {
                            return _buildCustomerRow(_customers[index], isDark);
                          }
                          if (index == _customers.length && _isLoadingMore) {
                             return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)));
                          }
                          return const SizedBox.shrink();
                        },
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CUSTOMER LIST', style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              Text('MANAGE YOUR CUSTOMERS', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ],
          ),
          Row(children: [
            _buildSmallStatCard(_monthlyCount.toString(), 'MONTHLY', Colors.indigo),
            const SizedBox(width: 8),
            _buildSmallStatCard(_onlineCount.toString(), 'ONLINE', PaceColors.emerald),
          ]),
        ],
      ),
    );
  }

  Widget _buildSmallStatCard(String val, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
      ]),
    );
  }

  Widget _buildSearchBox(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: PaceSearchBar(
        hint: 'Search MAC or mobile number...',
        isDark: isDark,
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildCustomerRow(dynamic c, bool isDark) {
    final status = c['status']?.toString().toLowerCase() ?? 'inactive';
    final isOnline = status == 'active' || status == 'online';
    Color statusColor = isOnline ? PaceColors.emerald : Colors.redAccent;

    return InkWell(
      onTap: () => _showCustomerDrawer(c, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['phone']?.toString() ?? 'N/A', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                  const SizedBox(height: 2),
                  Text(c['mac']?.toString().toUpperCase() ?? '00:00:00:00:00:00', style: TextStyle(fontSize: 10, color: PaceColors.getDimText(isDark))),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text('KES ${c['totalSpent'] ?? '0'}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(status.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: statusColor)),
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
