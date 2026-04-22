import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
import '../components/search_bar.dart';
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
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _fetchLock = false;
  int _page = 1;
  int _total = 0;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchData(1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && !_fetchLock) {
        _fetchData(_page + 1, isAppend: true);
      }
    }
  }

  Future<void> _fetchData(int pageNum, {bool isAppend = false}) async {
    if (_fetchLock) return;
    _fetchLock = true;

    if (!isAppend) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final res = await _apiService.getActiveConnections(
        page: pageNum,
        limit: 25,
        search: _search,
        forceRefresh: true
      );

      if (mounted && res != null) {
        final newItems = res['data'] ?? res['users'] ?? res['customers'] ?? [];
        final pagination = res['pagination'];
        final serverTotal = pagination?['total'] ?? 0;
        final serverHasMore = pagination?['has_more'] ?? false;

        setState(() {
          if (isAppend) {
            _active.addAll(newItems);
          } else {
            _active = List.from(newItems);
          }
          _total = serverTotal is int ? serverTotal : int.tryParse(serverTotal.toString()) ?? 0;
          _hasMore = serverHasMore == true;
          _page = pageNum;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
      _fetchLock = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    if (!settings.hasPolicy('view_active_users')) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.lock, size: 48, color: PaceColors.getDimText(isDark).withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('ACCESS RESTRICTED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 2)),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildHeader(isDark),
        _buildSearchBox(isDark),
        _buildTableHeader(isDark),
        Expanded(
          child: _isLoading && _active.isEmpty
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 10))
            : RefreshIndicator(
                onRefresh: () => _fetchData(1),
                color: PaceColors.purple,
                child: _active.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: _active.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _active.length) {
                          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)));
                        }
                        return _buildUserRow(_active[index], isDark);
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.zap, color: PaceColors.purple, size: 20),
              const SizedBox(width: 8),
              Text(
                'LIVE CONNECTIONS', 
                style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'CURRENTLY ONLINE HOTSPOT SESSIONS', 
            style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)
          ),
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
        onChanged: (val) {
          setState(() => _search = val);
          _fetchData(1);
        },
      ),
    );
  }

  Widget _buildTableHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark),
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark))),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('PHONE / RECEIPT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
          Expanded(flex: 2, child: Text('PLAN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
          Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
        ],
      ),
    );
  }

  Widget _buildUserRow(dynamic u, bool isDark) {
    return InkWell(
      onTap: () => Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => CustomerHistoryScreen(phone: u['phone'].toString()))
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark), width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u['phone']?.toString() ?? 'N/A', 
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark), fontFamily: 'monospace')
                  ),
                  const SizedBox(height: 2),
                  Text(
                    u['mpesa_code']?.toString().toUpperCase() ?? 'VOUCHER', 
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), fontFamily: 'monospace')
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                u['plan']?.toString() ?? 'N/A', 
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark))
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: PaceColors.emerald.withOpacity(0.1), 
                      borderRadius: BorderRadius.circular(6)
                    ),
                    child: const Text(
                      'ONLINE', 
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.emerald, letterSpacing: 0.5)
                    ),
                  ),
                  const Spacer(),
                  Icon(LucideIcons.chevronRight, size: 16, color: PaceColors.getDimText(isDark).withOpacity(0.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.zapOff, size: 48, color: PaceColors.getDimText(isDark).withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            'NO ACTIVE SESSIONS', 
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)
          ),
        ],
      ),
    );
  }
}
