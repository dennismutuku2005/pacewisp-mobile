import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/skeleton.dart';
import '../components/search_bar.dart';
import '../components/badge.dart';
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
  
  // Stats from WispPortal
  int _onlineCount = 0;
  int _monthlyCount = 0;
  
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
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

  Future<void> _refreshAll() async {
    _fetchStats();
    await _loadCustomers(1);
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
      debugPrint('Stats Fetch Error: $e');
    }
  }

  Future<void> _loadCustomers(int pageNum, {bool isAppend = false}) async {
    if (_fetchLock) return;
    _fetchLock = true;

    if (!isAppend) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final res = await _api.getCustomers(
        search: _search, 
        page: pageNum, 
        limit: 12,
        forceRefresh: true
      );

      if (mounted && res != null && res['status'] == 'success') {
        final newItems = res['data'] ?? [];
        final pagination = res['pagination'];
        final serverTotal = pagination?['total'] ?? 0;
        final serverHasMore = pagination?['has_more'] ?? false;

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
        setState(() {
          _search = val;
          _customers = [];
          _page = 1;
          _hasMore = true;
        });
        _loadCustomers(1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<SettingsProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            _buildControlBar(isDark),
            Expanded(
              child: _isLoading && _customers.isEmpty
                ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 10))
                : RefreshIndicator(
                    onRefresh: _refreshAll,
                    color: PaceColors.purple,
                    child: _customers.isEmpty
                      ? _buildEmptyState(isDark)
                      : _buildListView(isDark),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.users, color: PaceColors.purple, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'CUSTOMERS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: PaceColors.purple,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.only(left: 8),
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: PaceColors.purple, width: 2)),
                  ),
                  child: Text(
                    'MANAGE HOTSPOT USERS, DISTINCT BY PHONE NUMBER.',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: PaceColors.getDimText(isDark),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              _statBadge(
                _monthlyCount.toString(), 
                'MONTHLY', 
                Colors.indigo, 
                LucideIcons.calendar
              ),
              const SizedBox(height: 8),
              _statBadge(
                _onlineCount.toString(), 
                'ONLINE', 
                PaceColors.emerald, 
                LucideIcons.zap,
                pulse: true
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String val, String label, Color color, IconData icon, {bool pulse = false}) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (pulse) 
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              Text(
                val,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: color,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w900,
              color: color.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          PaceSearchBar(
            hint: 'Search MAC or mobile number...', 
            isDark: isDark, 
            onChanged: _onSearchChanged
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: PaceColors.getSurface(isDark),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: PaceColors.getBorder(isDark)),
                ),
                child: Text(
                  '${_customers.length} OF $_total RECORDS',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: PaceColors.getDimText(isDark),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListView(bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _customers.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _customers.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20), 
              child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)
            ),
          );
        }
        return _buildCustomerItem(_customers[index], isDark);
      },
    );
  }

  Widget _buildCustomerItem(dynamic c, bool isDark) {
    final status = c['status']?.toString() ?? 'Inactive';
    final used = c['used'] == true;
    
    return InkWell(
      onTap: () => Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => CustomerHistoryScreen(phone: c['phone'].toString()))
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PaceColors.getBorder(isDark)),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c['phone']?.toString() ?? 'N/A',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: PaceColors.purple,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c['mac']?.toString().toUpperCase() ?? 'NO MAC RECORDED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: PaceColors.getDimText(isDark),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'KES ${c['totalSpent'] ?? '0'}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: PaceColors.purple,
                      ),
                    ),
                    Text(
                      'AGGREGATE SPEND',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        color: PaceColors.getDimText(isDark),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 0.5),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _infoBadge('SESSIONS', c['sessions']?.toString() ?? '0', isDark),
                    const SizedBox(width: 8),
                    PaceBadge(
                      label: status.toUpperCase(),
                      variant: status == 'Active' ? BadgeVariant.success : BadgeVariant.standard,
                    ),
                    const SizedBox(width: 8),
                    PaceBadge(
                      label: used ? 'USED' : 'UNUSED',
                      variant: used ? BadgeVariant.success : BadgeVariant.error,
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(LucideIcons.clock, size: 10, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      c['lastSeen']?.toString().toUpperCase() ?? 'N/A',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: PaceColors.getDimText(isDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: PaceColors.getSurface(isDark),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.users, 
                  size: 48, 
                  color: PaceColors.getDimText(isDark).withOpacity(0.2)
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'NO MATCHING RECORDS FOUND',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: PaceColors.getDimText(isDark),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
