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
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 800,
                        child: Column(
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

  Widget _buildTableHeader(bool isDark) {
    final headerStyle = GoogleFonts.figtree(
      fontSize: 8, fontWeight: FontWeight.bold,
      color: PaceColors.getDimText(isDark), letterSpacing: 1.5,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
        border: Border(
          top: BorderSide(color: PaceColors.getBorder(isDark)),
          bottom: BorderSide(color: PaceColors.getBorder(isDark)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text('USER', style: headerStyle)),
          SizedBox(width: 80, child: Text('ACTION', style: headerStyle)),
          const SizedBox(width: 8),
          Expanded(child: Text('DESCRIPTION', style: headerStyle)),
          SizedBox(width: 72, child: Text('IP', style: headerStyle)),
          SizedBox(width: 58, child: Text('STATUS', style: headerStyle, textAlign: TextAlign.right)),
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
    final String action = log['action']?.toString().toUpperCase() ?? 'LOG';
    final String ip = log['ip'] ?? '0.0.0.0';
    final Color statusColor = isFailed ? Colors.red : PaceColors.emerald;

    return InkWell(
      onTap: () => _showLogDetailsModal(log, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        color: isFailed ? Colors.red.withOpacity(0.02) : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // User name
            SizedBox(
              width: 70,
              child: Text(user, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
            ),
            // Action badge
            SizedBox(
              width: 80,
              child: Align(
                alignment: Alignment.centerLeft,
                child: PaceBadge(label: action, variant: isFailed ? BadgeVariant.error : BadgeVariant.standard),
              ),
            ),
            const SizedBox(width: 8),
            // Description
            Expanded(
              child: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark))),
            ),
            // IP
            SizedBox(
              width: 72,
              child: Text(ip,
                style: GoogleFonts.jetBrainsMono(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
            ),
            // Status
            SizedBox(
              width: 58,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(status.isEmpty ? 'OK' : status.toUpperCase(),
                    style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: statusColor, letterSpacing: 0.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogDetailsModal(dynamic log, bool isDark) {
    final String status = (log['status'] ?? '').toString().toLowerCase();
    final bool isFailed = status == 'failed' || status == 'error';
    final String user = log['user']?.toString() ?? 'SYSTEM';
    final String message = log['description'] ?? log['message'] ?? 'Event recorded';
    final String time = log['time'] ?? log['created_at'] ?? 'No time provided';
    final String action = log['action']?.toString().toUpperCase() ?? 'LOG';
    final String ip = log['ip'] ?? 'Unknown Location / IP';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: (isFailed ? Colors.red : PaceColors.purple).withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(isFailed ? Icons.error_outline_rounded : Icons.info_outline_rounded, 
                      color: isFailed ? Colors.red : PaceColors.purple, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AUDIT TRACE DETAILS', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
                        const SizedBox(height: 2),
                        Text(action, style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark), letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: PaceColors.getDimText(isDark)),
                  )
                ],
              ),
              const SizedBox(height: 24),
              // Content Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PaceColors.getSurface(isDark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PaceColors.getBorder(isDark)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DESCRIPTION', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
                    const SizedBox(height: 6),
                    Text(message, style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getPrimaryText(isDark), height: 1.5)),
                    
                    const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
                    
                    Row(
                      children: [
                        Expanded(child: _buildModalStat('ACTOR / USER', user, Icons.person_outline_rounded, isDark)),
                        Expanded(child: _buildModalStat('STATUS', status.toUpperCase(), isFailed ? Icons.warning_rounded : Icons.check_circle_outline_rounded, isDark, 
                          color: isFailed ? Colors.red : PaceColors.emerald)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildModalStat('TIMESTAMP', time, Icons.schedule_rounded, isDark)),
                        Expanded(child: _buildModalStat('NETWORK IP', ip, Icons.public_rounded, isDark)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalStat(String label, String value, IconData icon, bool isDark, {Color? color}) {
    final c = color ?? PaceColors.getPrimaryText(isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(icon, size: 14, color: c.withOpacity(0.7)),
            const SizedBox(width: 6),
            Expanded(child: Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: c), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ],
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
