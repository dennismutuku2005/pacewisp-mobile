import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
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
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 24),
            _buildLogsContainer(isDark),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SMS LOGS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 20, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
            Text('TRANSMISSION HISTORY', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 2)),
          ],
        ),
        IconButton(
          icon: Icon(LucideIcons.refreshCw, size: 18, color: PaceColors.getDimText(isDark)),
          onPressed: _fetchLogs,
        ),
      ],
    );
  }

  Widget _buildLogsContainer(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2),
      ),
      child: Column(
        children: [
          _buildTableHeader(['RECIPIENT', 'CONTENT', 'STATUS'], isDark),
          if (_isLoading && _logs.isEmpty)
             const TransactionSkeleton(count: 8)
          else if (_logs.isEmpty)
            const Padding(padding: EdgeInsets.all(60), child: Center(child: Text('NO TRANSMISSIONS FOUND', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.grey))))
          else
            ..._logs.map((log) => _buildLogItem(log, isDark)).toList(),
          
          if (_isMoreLoading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: CircularProgressIndicator(strokeWidth: 2, color: PaceColors.purple)),
          
          if (!_hasMore && _logs.isNotEmpty)
             Padding(
               padding: const EdgeInsets.symmetric(vertical: 24),
               child: Center(
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Container(width: 24, height: 1, color: PaceColors.getBorder(isDark)),
                     const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(LucideIcons.checkCircle2, size: 12, color: PaceColors.emerald)),
                     Container(width: 24, height: 1, color: PaceColors.getBorder(isDark)),
                   ],
                 ),
               ),
             ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLogItem(dynamic log, bool isDark) {
    bool isSuccess = log['status'] == 'success';
    DateTime date = DateTime.parse(log['created_at']);

    return InkWell(
      onTap: () => _showLogDetail(log, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark).withOpacity(0.4)))),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: PaceColors.getSurface(isDark),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PaceColors.getBorder(isDark), width: 1),
              ),
              child: Icon(LucideIcons.smartphone, size: 14, color: PaceColors.getDimText(isDark)),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3, 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(log['phone'] ?? 'UNKNOWN', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.purple)), 
                  Text(DateFormat('MMM dd, HH:mm').format(date).toUpperCase(), style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600)),
                ]
              )
            ),
            Expanded(
              flex: 4, 
              child: Text(log['message'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.figtree(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600, letterSpacing: -0.2)),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              child: PaceBadge(label: isSuccess ? 'SENT' : 'FAIL', variant: isSuccess ? BadgeVariant.success : BadgeVariant.error),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(List<String> titles, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
      decoration: BoxDecoration(color: PaceColors.getSurface(isDark).withOpacity(0.5), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))), 
      child: Row(children: titles.asMap().entries.map((e) {
        final bool last = e.key == titles.length - 1;
        return Expanded(flex: e.key == 0 ? 3 : e.key == 1 ? 4 : 2, child: Text(e.value, textAlign: last ? TextAlign.right : TextAlign.left, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 0.5)));
      }).toList())
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
                  Text(log['phone'], style: GoogleFonts.figtree(fontSize: 20, fontWeight: FontWeight.normal, color: PaceColors.purple, letterSpacing: -0.5)),
                  Text('RECIPIENT NUMBER', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
                ],
              ),
              PaceBadge(label: isSuccess ? 'DELIVERED' : 'FAILED', variant: isSuccess ? BadgeVariant.success : BadgeVariant.error),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: PaceColors.getBackground(isDark),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: PaceColors.getBorder(isDark)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MESSAGE CONTENT', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
                const SizedBox(height: 12),
                Text(log['message'] ?? '', style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getPrimaryText(isDark), height: 1.6, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildInfoBox('DATE', DateFormat('MMMM dd, yyyy').format(date).toUpperCase(), LucideIcons.calendar, isDark),
              const SizedBox(width: 12),
              _buildInfoBox('TIME', DateFormat('hh:mm a').format(date).toUpperCase(), LucideIcons.clock, isDark),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoBox('GATEWAY', log['response_code']?.toString() ?? 'N/A', LucideIcons.server, isDark),
              const SizedBox(width: 12),
              _buildInfoBox('REF ID', (log['message_id?'] ?? 'INTERNAL').toString(), LucideIcons.shieldCheck, isDark),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: PaceColors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('DISMISS REPORT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String label, String value, IconData icon, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: PaceColors.getBorder(isDark), width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: PaceColors.purple),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.figtree(fontSize: 7, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
                  Text(value, style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
