import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Instant Recall memory cache
  static List<dynamic> _cache = [];

  List<dynamic> _logs = [];
  List<dynamic> _filteredLogs = [];
  int _page = 1;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _search = '';
  String _statusFilter = 'all'; // all | success | failed
  Timer? _debounce;

  late AnimationController _refreshController;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    
    // Instant Recall
    if (_cache.isNotEmpty) {
      _logs = List.from(_cache);
      _applyFilter();
      _isLoading = false;
    }

    _fetchLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _refreshController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) _fetchMoreLogs();
    }
  }

  void _applyFilter() {
    setState(() {
      _filteredLogs = _logs.where((log) {
        final status = (log['status'] ?? '').toString().toLowerCase();
        if (_statusFilter == 'success') return status != 'failed' && status != 'error';
        if (_statusFilter == 'failed') return status == 'failed' || status == 'error';
        return true;
      }).toList();
    });
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _search = val);
      _fetchLogs();
    });
  }

  Future<void> _fetchLogs({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = _cache.isEmpty);
    setState(() => _isRefreshing = true);
    _refreshController.repeat();

    final res = await _apiService.getLogs(search: _search, page: 1);
    if (mounted) {
      final fresh = _extractLogs(res);
      _cache = fresh;
      setState(() {
        _logs = fresh;
        _hasMore = res?['pagination']?['has_more'] ?? false;
        _page = 1;
        _isLoading = false;
        _isRefreshing = false;
      });
      _refreshController.stop();
      _refreshController.reset();
      _applyFilter();
    }
  }

  List<dynamic> _extractLogs(Map<String, dynamic>? res) {
    if (res == null) return [];
    if (res['data'] is List) return res['data'];
    if (res['data'] is Map) return res['data']['logs'] ?? res['data']['data'] ?? [];
    return [];
  }

  Future<void> _fetchMoreLogs() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final res = await _apiService.getLogs(search: _search, page: nextPage);
    if (mounted) {
      final newItems = _extractLogs(res);
      setState(() {
        _logs.addAll(newItems);
        _cache = List.from(_logs);
        _hasMore = res?['pagination']?['has_more'] ?? false;
        _page = nextPage;
        _isLoadingMore = false;
      });
      _applyFilter();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(isDark),
        _buildToolbar(isDark),
        Expanded(
          child: _isLoading
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 8))
            : RefreshIndicator(
                onRefresh: _fetchLogs,
                color: PaceColors.purple,
                child: _filteredLogs.isEmpty
                  ? _buildEmpty(isDark)
                  : Column(
                      children: [
                        _buildTableHeader(isDark),
                        Expanded(
                          child: ListView.separated(
                            controller: _scrollController,
                            padding: EdgeInsets.zero,
                            itemCount: _filteredLogs.length + (_isLoadingMore ? 1 : 0),
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: PaceColors.getBorder(isDark),
                              indent: 16,
                              endIndent: 16,
                            ),
                            itemBuilder: (context, index) {
                              if (index == _filteredLogs.length) {
                                return const Center(child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2),
                                ));
                              }
                              return _buildLogRow(_filteredLogs[index], isDark);
                            },
                          ),
                        ),
                      ],
                    ),
              ),
        ),
        _buildFooter(isDark),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SYSTEM LOGS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text('ACTIVITY TRACKING & AUDIT TRAIL', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: PaceColors.getSurface(isDark),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: PaceColors.getBorder(isDark)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                decoration: InputDecoration(
                  hintText: 'Search logs...',
                  hintStyle: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 11),
                  prefixIcon: Icon(Icons.search_rounded, color: PaceColors.purple.withOpacity(0.5), size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Status filter pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: PaceColors.getSurface(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PaceColors.getBorder(isDark)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                isDense: true,
                icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: PaceColors.getDimText(isDark)),
                dropdownColor: PaceColors.getCard(isDark),
                style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('ALL ENTRIES')),
                  DropdownMenuItem(value: 'success', child: Text('SUCCESS')),
                  DropdownMenuItem(value: 'failed', child: Text('FAILED')),
                ],
                onChanged: (val) {
                  setState(() => _statusFilter = val ?? 'all');
                  _applyFilter();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Refresh button
          GestureDetector(
            onTap: _isRefreshing ? null : () => _fetchLogs(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: PaceColors.purple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: RotationTransition(
                turns: _refreshController,
                child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogRow(dynamic log, bool isDark) {
    final String status = (log['status'] ?? '').toString().toLowerCase();
    final bool isFailed = status == 'failed' || status == 'error';
    final String user = log['user']?.toString() ?? 'SYSTEM';
    final String initial = user.isNotEmpty ? user[0].toUpperCase() : 'S';
    final String message = log['description'] ?? log['message'] ?? 'Event recorded';
    final String timestamp = log['time'] ?? log['created_at'] ?? 'N/A';
    final String action = log['action']?.toString().toUpperCase() ?? 'LOG';
    final String ip = log['ip'] ?? '0.0.0.0';
    final Color statusColor = isFailed ? Colors.red : PaceColors.emerald;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFailed ? Colors.red.withOpacity(0.15) : PaceColors.getBorder(isDark),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Avatar Initial
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PaceColors.purple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PaceColors.getBorder(isDark)),
            ),
            alignment: Alignment.center,
            child: Text(initial, style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.purple)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(user.toUpperCase(), style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                    ),
                    Text(timestamp, style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(message, style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark), height: 1.4)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    PaceBadge(label: action, variant: isFailed ? BadgeVariant.error : BadgeVariant.standard),
                    const SizedBox(width: 8),
                    Text(ip, style: GoogleFonts.jetBrainsMono(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(status.toUpperCase(), style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: statusColor, letterSpacing: 0.5)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: ListView(
        shrinkWrap: true,
        children: [
          Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: PaceColors.getSurface(isDark), shape: BoxShape.circle),
                child: const Icon(Icons.manage_history_rounded, color: PaceColors.purple, size: 28),
              ),
              const SizedBox(height: 16),
              Text('NO ACTIVITY FOUND', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
              const SizedBox(height: 6),
              Text('No events match your current filter', style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark),
        border: Border(top: BorderSide(color: PaceColors.getBorder(isDark))),
      ),
      child: Row(
        children: [
          Text(
            'TOTAL TRACE: ${_filteredLogs.length} RECORDS',
            style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5),
          ),
          const Spacer(),
          if (_isRefreshing)
            SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(color: PaceColors.purple.withOpacity(0.5), strokeWidth: 1.5),
            ),
        ],
      ),
    );
  }
}
