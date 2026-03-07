import 'package:flutter/material.dart';
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

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _logs = [];
  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchMoreLogs();
      }
    }
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    final res = await _apiService.getLogs(search: _search, page: 1);
    if (mounted) {
      setState(() {
        _logs = res?['data']?['logs'] ?? res?['data'] ?? [];
        _hasMore = res?['pagination']?['has_more'] ?? res?['data']?['pagination']?['has_more'] ?? false;
        _page = 1;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMoreLogs() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final res = await _apiService.getLogs(search: _search, page: nextPage);
    if (mounted) {
      setState(() {
        final newItems = res?['data']?['logs'] ?? res?['data'] ?? [];
        _logs.addAll(newItems);
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
        _buildSearchBox(isDark),
        Expanded(
          child: _isLoading 
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 8))
            : RefreshIndicator(
                onRefresh: _fetchLogs,
                color: PaceColors.purple,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length + (_isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                  itemBuilder: (context, index) {
                    if (index == _logs.length) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)));
                    return _buildLogItem(_logs[index], isDark);
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SYSTEM LOGS', style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              Icon(Icons.security_rounded, color: PaceColors.purple, size: 24),
            ],
          ),
          Text('AUDIT TRAIL & SECURITY EVENT MONITORING', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ],
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
          onChanged: (val) { setState(() => _search = val); _fetchLogs(); },
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
          decoration: InputDecoration(
            hintText: 'Filter events or users...', 
            hintStyle: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 12), 
            prefixIcon: Icon(Icons.manage_search_rounded, color: PaceColors.purple.withOpacity(0.5), size: 20), 
            border: InputBorder.none, 
            contentPadding: const EdgeInsets.symmetric(vertical: 14)
          ),
        ),
      ),
    );
  }

  Widget _buildLogItem(dynamic log, bool isDark) {
    final String status = (log['status'] ?? '').toString().toLowerCase();
    final bool isCritical = status == 'failed' || status == 'critical' || status == 'error';
    final String user = log['user']?.toString().toUpperCase() ?? 'SYSTEM';
    final String message = log['description'] ?? log['message'] ?? 'Event Recorded';
    final String timestamp = log['time'] ?? 'N/A';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10), 
            decoration: BoxDecoration(
              color: (isCritical ? Colors.redAccent : PaceColors.purple).withOpacity(0.08), 
              borderRadius: BorderRadius.circular(12)
            ), 
            child: Icon(
              isCritical ? Icons.report_problem_rounded : Icons.history_edu_rounded, 
              color: isCritical ? Colors.redAccent : PaceColors.purple, 
              size: 22
            )
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(user, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 0.5)),
                    Text(timestamp, style: TextStyle(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(message, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark), height: 1.4)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    PaceBadge(label: log['action']?.toUpperCase() ?? 'LOG', variant: isCritical ? BadgeVariant.error : BadgeVariant.standard),
                    const SizedBox(width: 8),
                    Text(log['ip'] ?? '0.0.0.0', style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900, letterSpacing: 1, fontFamily: 'monospace')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
