import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/empty_state.dart';
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
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _active = [];
  int _page = 1;
  int _total = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchData(pageNum: 1);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchMore();
      }
    }
  }

  Future<void> _fetchData({required int pageNum}) async {
    if (pageNum == 1) setState(() => _isLoading = true);
    
    try {
      final res = await _apiService.getActiveConnections(
        page: pageNum,
        limit: 25,
        search: _search,
        forceRefresh: true
      );

      if (mounted && res != null) {
        setState(() {
          final newItems = res['data'] ?? res['users'] ?? res['customers'] ?? [];
          if (pageNum == 1) {
            _active = newItems;
          } else {
            _active.addAll(newItems);
          }
          _total = res['pagination']?['total'] ?? 0;
          _hasMore = res['pagination']?['has_more'] ?? false;
          _page = pageNum;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMore() async {
    setState(() => _isLoadingMore = true);
    try {
      await _fetchData(pageNum: _page + 1);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
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
          _buildControls(isDark),
          Expanded(
            child: _isLoading 
              ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 10))
              : Column(
                  children: [
                    _buildTableHeader(isDark),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => _fetchData(pageNum: 1),
                        color: PaceColors.purple,
                        child: _active.isEmpty 
                          ? SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: PaceEmptyState(onRetry: () => _fetchData(pageNum: 1), isDark: isDark))
                          : ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                              itemCount: _active.length + (_isLoadingMore ? 1 : 0),
                              separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark).withOpacity(0.4), height: 1),
                              itemBuilder: (context, index) {
                                if (index == _active.length) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)));
                                return _buildActiveRow(_active[index], isDark);
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
          Row(
            children: [
              const Icon(LucideIcons.zap, color: PaceColors.purple, size: 20),
              const SizedBox(width: 8),
              Text('LIVE CONNECTIONS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
            ],
          ),
          Text('REAL-TIME HOTSPOT SESSIONS & ACTIVITY', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildControls(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: PaceSearchBar(
        hint: 'Search by phone or code...', 
        isDark: isDark, 
        onChanged: (val) {
          _search = val;
          _fetchData(pageNum: 1);
        }
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
          Expanded(flex: 3, child: Text('PHONE / RECEIPT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
          Expanded(flex: 2, child: Text('PLAN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
          Expanded(flex: 2, child: Text('STATUS', textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
        ],
      ),
    );
  }

  Widget _buildActiveRow(dynamic u, bool isDark) {
    return InkWell(
      onTap: () => Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => CustomerHistoryScreen(phone: u['phone'].toString()))
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u['phone']?.toString() ?? 'N/A', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark), letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(u['mpesa_code']?.toString().toUpperCase() ?? 'VOUCHER', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(u['plan']?.toString() ?? 'N/A', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w600, color: PaceColors.purple)),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PaceBadge(label: 'ONLINE', variant: BadgeVariant.success),
                  const SizedBox(width: 8),
                  Icon(LucideIcons.chevronRight, size: 14, color: PaceColors.getDimText(isDark).withOpacity(0.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
