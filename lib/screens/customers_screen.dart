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
  List<dynamic> _routers = [];
  int _page = 1;
  int _total = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _search = '';
  String _selectedRouter = 'all';
  
  // Stats
  int _onlineCount = 0;
  int _monthlyCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchMore();
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // Parallel fetch for speed
      final results = await Future.wait([
        _apiService.getRouters(forceRefresh: true),
        _apiService.getSummaryWidgets(forceRefresh: true),
      ]);

      final routersRes = results[0] as Map<String, dynamic>?;
      final widgetsRes = results[1] as Map<String, dynamic>?;

      await _fetchCustomers(pageNum: 1, isInitial: true);

      if (mounted) {
        setState(() {
          _routers = routersRes?['data'] ?? [];
          if (widgetsRes != null && widgetsRes['status'] == 'success') {
            final w = widgetsRes['data']?['widgets'];
            _onlineCount = int.tryParse(w?['online_customers']?['value']?.toString() ?? '0') ?? 0;
            _monthlyCount = int.tryParse(w?['customers_month']?['value']?.toString() ?? '0') ?? 0;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCustomers({required int pageNum, bool isInitial = false}) async {
    final res = await _apiService.fetchData(slug: 'customers', params: {
      'page': pageNum,
      'limit': 15,
      'search': _search,
      'router_name': _selectedRouter == 'all' ? null : _selectedRouter,
    });

    if (mounted && res?['status'] == 'success') {
      setState(() {
        if (pageNum == 1) {
          _customers = res?['data'] ?? [];
        } else {
          _customers.addAll(res?['data'] ?? []);
        }
        _hasMore = res?['pagination']?['has_more'] ?? false;
        _total = res?['pagination']?['total'] ?? 0;
        _page = pageNum;
      });
    }
  }

  Future<void> _fetchMore() async {
    setState(() => _isLoadingMore = true);
    try {
      await _fetchCustomers(pageNum: _page + 1);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged(String val) {
    _search = val;
    _fetchCustomers(pageNum: 1);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Container(
      color: PaceColors.getBackground(isDark),
      child: Column(
        children: [
          _buildHeader(isDark),
          _buildStatsStrip(isDark),
          _buildControls(isDark),
          Expanded(
            child: _isLoading 
              ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 10))
              : Column(
                  children: [
                    _buildTableHeader(isDark),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadInitialData,
                        color: PaceColors.purple,
                        child: _customers.isEmpty 
                          ? _buildEmptyState(isDark)
                          : ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                              itemCount: _customers.length + (_isLoadingMore ? 1 : 0),
                              separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark).withOpacity(0.4), height: 1),
                              itemBuilder: (context, index) {
                                if (index == _customers.length) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)));
                                return _buildCustomerRow(_customers[index], isDark);
                              },
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
          Text('CUSTOMER REGISTRY', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
          Text('CENTRALIZED HOTSPOT USER MANAGEMENT', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildStatsStrip(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _statCard('ONLINE NOW', _onlineCount.toString(), PaceColors.emerald, isDark, LucideIcons.zap),
          const SizedBox(width: 12),
          _statCard('MONTHLY USERS', _monthlyCount.toString(), Colors.blueAccent, isDark, LucideIcons.calendar),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, bool isDark, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 6),
                Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w600, color: color, letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: PaceSearchBar(
                  hint: 'Search MAC or phone...', 
                  isDark: isDark, 
                  onChanged: _onSearchChanged
                ),
              ),
              const SizedBox(width: 12),
              _buildFilterButton(isDark),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_total TOTAL RECORDS FOUND', 
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 0.5)
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(bool isDark) {
    return InkWell(
      onTap: () => _showRouterPicker(isDark),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PaceColors.getSurface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PaceColors.getBorder(isDark)),
        ),
        child: Icon(LucideIcons.sliders, size: 18, color: PaceColors.getPrimaryText(isDark)),
      ),
    );
  }

  void _showRouterPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getBackground(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text('FILTER BY NODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 2)),
            ),
            ListTile(
              onTap: () { setState(() => _selectedRouter = 'all'); Navigator.pop(context); _fetchCustomers(pageNum: 1); },
              leading: Icon(LucideIcons.globe, size: 18, color: _selectedRouter == 'all' ? PaceColors.purple : PaceColors.getDimText(isDark)),
              title: Text('All Nodes', style: TextStyle(fontSize: 13, fontWeight: _selectedRouter == 'all' ? FontWeight.w600 : FontWeight.normal)),
              selected: _selectedRouter == 'all',
              selectedTileColor: PaceColors.purple.withOpacity(0.05),
            ),
            ..._routers.map((r) {
              final name = r['router_name']?.toString() ?? 'Unknown';
              return ListTile(
                onTap: () { setState(() => _selectedRouter = name); Navigator.pop(context); _fetchCustomers(pageNum: 1); },
                leading: Icon(LucideIcons.router, size: 18, color: _selectedRouter == name ? PaceColors.purple : PaceColors.getDimText(isDark)),
                title: Text(name.toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: _selectedRouter == name ? FontWeight.w600 : FontWeight.normal)),
                selected: _selectedRouter == name,
                selectedTileColor: PaceColors.purple.withOpacity(0.05),
              );
            }).toList(),
            const SizedBox(height: 24),
          ],
        ),
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
          Expanded(flex: 3, child: Text('PHONE & IDENTIFIER', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
          Expanded(flex: 2, child: Text('SPENT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
          Expanded(flex: 2, child: Text('STATUS', textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
        ],
      ),
    );
  }

  Widget _buildCustomerRow(dynamic c, bool isDark) {
    final status = c['status']?.toString() ?? 'Inactive';
    final bool isActive = status == 'Active';

    return InkWell(
      onTap: () => _showCustomerDrawer(c, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['phone']?.toString() ?? 'N/A', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.purple, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(c['mac']?.toString().toUpperCase() ?? 'NO MAC RECORDED', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text('KES ${c['totalSpent'] ?? '0'}', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PaceBadge(label: status.toUpperCase(), variant: isActive ? BadgeVariant.success : BadgeVariant.secondary),
                  const SizedBox(height: 4),
                  Text('SESSIONS: ${c['sessions'] ?? 0}', style: TextStyle(fontSize: 7, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerDrawer(dynamic c, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: PaceColors.getBorder(isDark), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('CUSTOMER PROFILE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: PaceColors.purple, letterSpacing: 1.5)),
                      IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDrawerInfo('PRIMARY PHONE', c['phone']?.toString() ?? 'N/A', isDark, isBig: true),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildDrawerInfo('MAC ADDRESS', c['mac']?.toString().toUpperCase() ?? 'N/A', isDark)),
                      Expanded(child: _buildDrawerInfo('LATEST STATUS', c['status']?.toString().toUpperCase() ?? 'N/A', isDark)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildDrawerInfo('TOTAL SPENT', 'KES ${c['totalSpent'] ?? 0}', isDark)),
                      Expanded(child: _buildDrawerInfo('SESSIONS', '${c['sessions'] ?? 0}', isDark)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildDrawerInfo('LAST VISIBILITY', c['lastSeen']?.toString().toUpperCase() ?? 'N/A', isDark),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerHistoryScreen(phone: c['phone'].toString())));
                      },
                      icon: const Icon(LucideIcons.history, size: 16),
                      label: const Text('VIEW HISTORY & LOGS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PaceColors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
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

  Widget _buildDrawerInfo(String label, String value, bool isDark, {bool isBig = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: isBig ? 18 : 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
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
          Text('NO CUSTOMERS FOUND', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        ],
      ),
    );
  }
}
