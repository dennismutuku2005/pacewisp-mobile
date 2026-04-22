import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
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
    setState(() => _isLoading = true);
    final res = await _apiService.getCustomers(search: _search, page: 1, forceRefresh: force);
    if (mounted && res != null) {
      _processCustomers(res, 1);
    } else if (mounted) {
      setState(() => _isLoading = false);
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
      }
      _page = page;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String val) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _search = val;
      _fetchCustomers(force: true);
    });
  }

  Future<void> _fetchMoreCustomers() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final res = await _apiService.getCustomers(search: _search, page: nextPage);
    if (mounted && res != null) {
      _processCustomers(res, nextPage);
    }
    if (mounted) setState(() => _isLoadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Column(
      children: [
        _buildHeader(isDark),
        _buildControlBar(isDark),
        Expanded(
          child: _isLoading && _customers.isEmpty
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 8))
            : RefreshIndicator(
                onRefresh: () async { _fetchStats(); await _fetchCustomers(force: true); },
                color: PaceColors.purple,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
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
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CUSTOMERS MASTER LIST', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
              Text('MANAGE HOTSPOT USERS, DISTINCT BY PHONE', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
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
        Text(val, style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: GoogleFonts.figtree(fontSize: 7, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
      ]),
    );
  }

  Widget _buildControlBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
              child: TextField(
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Search MAC or mobile number...', 
                  hintStyle: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 11), 
                  icon: Icon(LucideIcons.search, color: PaceColors.getDimText(isDark), size: 14), 
                  border: InputBorder.none, 
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
            child: Text('$_total RECORDS', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerItem(dynamic c, bool isDark) {
    final status = c['status']?.toString().toLowerCase() ?? 'inactive';
    final isOnline = status == 'active' || status == 'online';

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerHistoryScreen(phone: c['phone'].toString()))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['phone']?.toString() ?? 'PRIVATE', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w800, color: PaceColors.purple)),
                const SizedBox(height: 2),
                Text(c['mac']?.toString().toUpperCase() ?? '00:00:00:00:00:00', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('KES ${c['totalSpent'] ?? 0}', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark))),
              PaceBadge(label: status.toUpperCase(), variant: isOnline ? BadgeVariant.success : BadgeVariant.error),
            ]),
            const SizedBox(width: 16),
            const Icon(LucideIcons.chevronRight, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
