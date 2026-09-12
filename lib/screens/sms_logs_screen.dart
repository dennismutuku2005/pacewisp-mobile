import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
import '../components/empty_state.dart';
import 'package:intl/intl.dart';

class SmsLogsScreen extends StatefulWidget {
  const SmsLogsScreen({super.key});

  @override
  State<SmsLogsScreen> createState() => _SmsLogsScreenState();
}

class _SmsLogsScreenState extends State<SmsLogsScreen> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isMoreLoading = false;
  List<dynamic> _logs = [];
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isMoreLoading && _hasMore) {
        _fetchMoreLogs();
      }
    }
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _logs = [];
    });

    try {
      final res = await _api.getSmsLogs(page: 1);
      if (res != null && res['status'] == 'success') {
        setState(() {
          _logs = res['data'] ?? [];
          _hasMore = res['pagination']?['hasMore'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching logs: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMoreLogs() async {
    setState(() => _isMoreLoading = true);
    try {
      final nextPage = _currentPage + 1;
      final res = await _api.getSmsLogs(page: nextPage);
      if (res != null && res['status'] == 'success') {
        final List newLogs = res['data'] ?? [];
        setState(() {
          _logs.addAll(newLogs);
          _currentPage = nextPage;
          _hasMore = res['pagination']?['hasMore'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching more logs: $e');
    } finally {
      if (mounted) setState(() => _isMoreLoading = false);
    }
  }

  void _showLogDetail(dynamic log, bool isDark) {
    bool isSuccess = log['status'] == 'success';
    DateTime date = DateTime.tryParse(log['created_at'] ?? '') ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log['phone'] ?? 'Phone',
                      style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                    ),
                    Text(
                      'SMS Delivery Report',
                      style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark)),
                    ),
                  ],
                ),
                PaceBadge(
                  label: isSuccess ? 'Delivered' : 'Failed',
                  variant: isSuccess ? BadgeVariant.success : BadgeVariant.danger,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              width: double.infinity,
              decoration: BoxDecoration(
                color: PaceColors.getSurface(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PaceColors.getBorder(isDark)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Message Body', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark))),
                  const SizedBox(height: 6),
                  Text(
                    log['message'] ?? '',
                    style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getPrimaryText(isDark), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _infoItem('Timestamp', DateFormat('MMM dd, yyyy HH:mm').format(date), LucideIcons.clock, isDark),
                const SizedBox(width: 10),
                _infoItem('Gateway Code', log['response_code']?.toString() ?? 'OK', LucideIcons.server, isDark),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PaceColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text('Close', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value, IconData icon, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PaceColors.getSurface(isDark),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: PaceColors.getBorder(isDark)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: PaceColors.purple),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark))),
                  Text(
                    value,
                    style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Column(
      children: [
        _buildHeader(isDark),
        Expanded(
          child: _isLoading && _logs.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 8))
              : RefreshIndicator(
                  onRefresh: _fetchLogs,
                  color: PaceColors.purple,
                  child: _logs.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: PaceEmptyState(
                            title: 'No SMS Logs',
                            subtitle: 'Outgoing SMS notifications and broadcast records will be listed here.',
                            onRetry: _fetchLogs,
                            isDark: isDark,
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                          itemCount: _logs.length + (_isMoreLoading ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            if (i == _logs.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2),
                                ),
                              );
                            }
                            return _buildLogCard(_logs[i], isDark);
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SMS Logs',
                style: GoogleFonts.figtree(
                  color: PaceColors.getPrimaryText(isDark),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Delivery history and SMS gateway responses',
                style: GoogleFonts.figtree(
                  color: PaceColors.getDimText(isDark),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            onPressed: _fetchLogs,
            tooltip: 'Refresh Logs',
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(dynamic log, bool isDark) {
    bool isSuccess = log['status'] == 'success';
    DateTime date = DateTime.tryParse(log['created_at'] ?? '') ?? DateTime.now();

    return InkWell(
      onTap: () => _showLogDetail(log, isDark),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PaceColors.getBorder(isDark)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSuccess ? PaceColors.emerald.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSuccess ? LucideIcons.messageSquare : LucideIcons.alertCircle,
                size: 16,
                color: isSuccess ? PaceColors.emerald : Colors.red.shade600,
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
                        log['phone'] ?? 'Recipient',
                        style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                      ),
                      const SizedBox(width: 8),
                      PaceBadge(
                        label: isSuccess ? 'Delivered' : 'Failed',
                        variant: isSuccess ? BadgeVariant.success : BadgeVariant.danger,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    log['message'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('MMM dd, HH:mm').format(date),
              style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark)),
            ),
          ],
        ),
      ),
    );
  }
}
