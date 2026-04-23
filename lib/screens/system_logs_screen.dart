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

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollCtrl = ScrollController();
  List<dynamic> _logs = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  String _search = '';
  String _statusFilter = 'all'; // all | success | failed

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMore) _fetchMore();
      }
    });
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    final res = await _apiService.getLogs(search: _search, page: 1);
    if (mounted) {
      setState(() {
        _logs = res?['data'] ?? [];
        _page = 1;
        _hasMore = res?['pagination']?['has_more'] ?? false;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMore() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final res = await _apiService.getLogs(search: _search, page: nextPage);
    if (mounted) {
      setState(() {
        final newItems = res?['data'] ?? [];
        _logs.addAll(newItems);
        _page = nextPage;
        _hasMore = res?['pagination']?['has_more'] ?? false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;
    final filtered = _logs.where((l) {
      final s = (l['status'] ?? '').toString().toLowerCase();
      if (_statusFilter == 'success') return s != 'failed' && s != 'error';
      if (_statusFilter == 'failed') return s == 'failed' || s == 'error';
      return true;
    }).toList();

    return Column(
      children: [
        _buildHeader(isDark),
        _buildFilters(isDark),
        Expanded(
          child: _isLoading 
            ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList())
            : RefreshIndicator(
                onRefresh: _fetchLogs,
                color: PaceColors.purple,
                child: filtered.isEmpty
                  ? SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: PaceEmptyState(onRetry: _fetchLogs, isDark: isDark))
                  : ListView.separated(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      itemCount: filtered.length + (_isLoadingMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        if (i == filtered.length) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                        return _buildLogCard(filtered[i], isDark);
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SYSTEM LOGS', style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
        Text('COMPREHENSIVE AUDIT TRAIL', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2)),
      ]),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Row(children: [
        Expanded(child: PaceSearchBar(
          hint: 'Search audit trail...',
          isDark: isDark,
          onChanged: (v) { _search = v; _fetchLogs(); },
        )),
        const SizedBox(width: 12),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(12)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _statusFilter, dropdownColor: PaceColors.getCard(isDark), items: const [DropdownMenuItem(value: 'all', child: Text('ALL')), DropdownMenuItem(value: 'success', child: Text('OK')), DropdownMenuItem(value: 'failed', child: Text('FAIL'))], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: PaceColors.purple), onChanged: (v) => setState(() => _statusFilter = v!)))),
      ]),
    );
  }

  Widget _buildLogCard(dynamic l, bool isDark) {
    final status = (l['status'] ?? '').toString().toLowerCase();
    final bool isFailed = status == 'failed' || status == 'error';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: PaceColors.getBorder(isDark))),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: isFailed ? Colors.red.withOpacity(0.1) : PaceColors.emerald.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(isFailed ? LucideIcons.alertCircle : LucideIcons.checkCircle2, color: isFailed ? Colors.red : PaceColors.emerald, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(l['user']?.toString().toUpperCase() ?? 'SYSTEM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: PaceColors.getPrimaryText(isDark))),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(l['action']?.toString().toUpperCase() ?? 'LOG', style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: PaceColors.purple))),
            ]),
            const SizedBox(height: 4),
            Text(l['description'] ?? '', style: TextStyle(fontSize: 11, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(l['date']?.toString().split(' ')[0] ?? '', style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.w600)),
            Text(l['time'] ?? '', style: const TextStyle(fontSize: 8, color: Colors.grey)),
          ]),
        ],
      ),
    );
  }
}
