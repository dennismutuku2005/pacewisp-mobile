import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
  String _statusFilter = 'all';

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

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
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
          child: _isLoading && _logs.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 8))
              : RefreshIndicator(
                  onRefresh: _fetchLogs,
                  color: PaceColors.purple,
                  child: filtered.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: PaceEmptyState(
                            title: 'No Audit Logs',
                            subtitle: 'System activity records will automatically be logged here.',
                            onRetry: _fetchLogs,
                            isDark: isDark,
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollCtrl,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                          itemCount: filtered.length + (_isLoadingMore ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            if (i == filtered.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2),
                                ),
                              );
                            }
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Logs',
            style: GoogleFonts.figtree(
              color: PaceColors.getPrimaryText(isDark),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Audit trail of administrator actions and system operations',
            style: GoogleFonts.figtree(
              color: PaceColors.getDimText(isDark),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: PaceSearchBar(
              hint: 'Search audit trail...',
              isDark: isDark,
              onChanged: (v) {
                _search = v;
                _fetchLogs();
              },
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: PaceColors.getCard(isDark),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PaceColors.getBorder(isDark)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                dropdownColor: PaceColors.getCard(isDark),
                items: [
                  DropdownMenuItem(value: 'all', child: Text('All Events', style: GoogleFonts.figtree(fontSize: 13))),
                  DropdownMenuItem(value: 'success', child: Text('Success', style: GoogleFonts.figtree(fontSize: 13))),
                  DropdownMenuItem(value: 'failed', child: Text('Errors', style: GoogleFonts.figtree(fontSize: 13))),
                ],
                style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.purple),
                onChanged: (v) => setState(() => _statusFilter = v!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(dynamic l, bool isDark) {
    final status = (l['status'] ?? '').toString().toLowerCase();
    final bool isFailed = status == 'failed' || status == 'error';
    final user = l['user']?.toString() ?? 'System';
    final action = l['action']?.toString() ?? 'Event';
    final description = l['description']?.toString() ?? '';
    final date = l['date']?.toString() ?? l['created_at']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isFailed ? Colors.red.withOpacity(0.1) : PaceColors.emerald.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFailed ? LucideIcons.alertCircle : LucideIcons.checkCircle2,
              color: isFailed ? Colors.red.shade600 : PaceColors.emerald,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user,
                      style: GoogleFonts.figtree(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: PaceColors.getPrimaryText(isDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PaceBadge(
                      label: action.replaceAll('_', ' ').toUpperCase(),
                      variant: isFailed ? BadgeVariant.danger : BadgeVariant.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark)),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark).withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
