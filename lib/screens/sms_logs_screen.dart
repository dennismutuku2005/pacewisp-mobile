import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
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
      setState(() => _isLoading = false);
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
      setState(() => _isMoreLoading = false);
    }
  }

  void _showLogDetail(dynamic log, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDetailSheet(log, isDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: _isLoading 
              ? _buildSkeleton()
              : _logs.isEmpty 
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                      onRefresh: _fetchLogs,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: _logs.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _logs.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          }
                          return _buildLogItem(_logs[index], isDark);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transmission History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
              Text('REAL-TIME GATEWAY LOGS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.2)),
            ],
          ),
          IconButton(
            icon: Icon(LucideIcons.refreshCw, size: 18, color: PaceColors.getSecondaryText(isDark)),
            onPressed: _fetchLogs,
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(dynamic log, bool isDark) {
    bool isSuccess = log['status'] == 'success';
    DateTime date = DateTime.parse(log['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaceColors.getBorder(isDark).withOpacity(0.5)),
      ),
      child: ListTile(
        onTap: () => _showLogDetail(log, isDark),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (isSuccess ? Colors.emerald : Colors.red).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isSuccess ? LucideIcons.checkCircle2 : LucideIcons.xCircle,
            color: isSuccess ? Colors.emerald : Colors.redAccent,
            size: 18,
          ),
        ),
        title: Text(log['phone'] ?? 'Unknown', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
        subtitle: Text(log['message'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: PaceColors.getDimText(isDark))),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(DateFormat('HH:mm').format(date), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getSecondaryText(isDark))),
            Text(DateFormat('MMM dd').format(date).toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSheet(dynamic log, bool isDark) {
    bool isSuccess = log['status'] == 'success';
    DateTime date = DateTime.parse(log['created_at']);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: PaceColors.getBorder(isDark), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log['phone'], style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                  Text('RECIPIENT NUMBER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSuccess ? Colors.emerald : Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isSuccess ? 'DELIVERED' : 'FAILED',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: PaceColors.getBackground(isDark),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MESSAGE CONTENT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
                const SizedBox(height: 12),
                Text(log['message'] ?? '', style: TextStyle(fontSize: 14, color: PaceColors.getPrimaryText(isDark), height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildInfoBox('DATE', DateFormat('MMMM dd, yyyy').format(date), LucideIcons.calendar, isDark),
              const SizedBox(width: 12),
              _buildInfoBox('TIME', DateFormat('hh:mm a').format(date), LucideIcons.clock, isDark),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoBox('RESPONSE', log['response_code']?.toString() ?? 'N/A', LucideIcons.server, isDark),
              const SizedBox(width: 12),
              _buildInfoBox('REF ID', (log['message_id?'] ?? 'INTERNAL').toString(), LucideIcons.shieldCheck, isDark),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.slate[900],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('DISMISS REPORT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String label, String value, IconData icon, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: PaceColors.getBorder(isDark).withOpacity(0.5)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: PaceColors.getSecondaryText(isDark)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
                  Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)), overflow: TextOverflow.ellipsis),
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
          Icon(LucideIcons.messageSquare, size: 48, color: PaceColors.getDimText(isDark).withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('No transmission history found', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark))),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 10,
      itemBuilder: (context, index) => Container(
        height: 70,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
