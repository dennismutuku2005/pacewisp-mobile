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
import '../components/overlay_loader.dart';

class CustomerHistoryScreen extends StatefulWidget {
  final String phone;
  const CustomerHistoryScreen({super.key, required this.phone});

  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isProcessing = false;
  
  Map<String, dynamic>? _summary;
  List<dynamic> _sessions = [];
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getHistory(widget.phone, forceRefresh: true);
      if (mounted && res != null) {
        setState(() {
          final rootData = res['data'] is Map ? res['data'] : null;
          _summary = res['summary'] ?? rootData?['summary'];
          _sessions = res['sessions'] ?? rootData?['sessions'] ?? (res['data'] is List ? res['data'] : []);
          _isBlocked = (res['is_blocked'] == true || rootData?['is_blocked'] == true);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSecurity() async {
    final bool didAuth = await _apiService.authenticateBiometric(
      reason: 'Confirm identity to update customer security status'
    );
    
    if (!didAuth) return;

    setState(() => _isProcessing = true);
    try {
      if (_isBlocked) {
        await _apiService.unblockNumber(widget.phone);
      } else {
        await _apiService.blockNumber(widget.phone, reason: 'Security toggle');
      }
      await _fetchData();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<SettingsProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: PaceOverlayLoader(
        isLoading: _isProcessing,
        message: 'Syncing security policy...',
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDark),
              _buildQuickStats(isDark),
              _buildTableHeader(isDark),
              Expanded(
                child: _isLoading 
                  ? const Padding(padding: EdgeInsets.all(16.0), child: TransactionSkeleton(count: 6))
                  : RefreshIndicator(
                      onRefresh: _fetchData,
                      color: PaceColors.purple,
                      child: _sessions.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: PaceEmptyState(
                              title: 'No Session Records',
                              subtitle: 'No payment or access sessions found for this customer.',
                              onRetry: _fetchData,
                              isDark: isDark,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: _sessions.length,
                            separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                            itemBuilder: (context, index) => _buildSessionRow(_sessions[index], isDark),
                          ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(LucideIcons.arrowLeft, color: PaceColors.getPrimaryText(isDark), size: 18),
            style: IconButton.styleFrom(
              backgroundColor: PaceColors.getSurface(isDark),
              padding: const EdgeInsets.all(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.phone,
                  style: GoogleFonts.jetBrainsMono(color: PaceColors.purple, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Customer History & Sessions',
                  style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _toggleSecurity,
            icon: Icon(
              _isBlocked ? LucideIcons.shieldAlert : LucideIcons.shieldCheck,
              color: _isBlocked ? PaceColors.red : PaceColors.green,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Total Spent', 'KES ${_summary?['total_spent'] ?? _summary?['total_amount'] ?? 0}', isDark),
          Container(width: 1, height: 28, color: PaceColors.getBorder(isDark)),
          _statItem('Sessions', '${_summary?['sessions'] ?? _summary?['total_visits'] ?? _sessions.length}', isDark),
          Container(width: 1, height: 28, color: PaceColors.getBorder(isDark)),
          _statItem('Status', _isBlocked ? 'Blocked' : 'Active', isDark, isBlocked: _isBlocked),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, bool isDark, {bool isBlocked = false}) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.figtree(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isBlocked ? PaceColors.red : PaceColors.getPrimaryText(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(bool isDark) {
    return Container(
      color: PaceColors.getSurface(isDark),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('SESSION CODE / NODE', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark), letterSpacing: 0.5))),
          Expanded(flex: 2, child: Text('STATUS', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark), letterSpacing: 0.5))),
          Expanded(flex: 2, child: Text('AMOUNT', textAlign: TextAlign.right, style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark), letterSpacing: 0.5))),
        ],
      ),
    );
  }

  Widget _buildSessionRow(dynamic s, bool isDark) {
    final bool isActive = (s['active'] == true || s['active']?.toString() == '1');
    final amount = s['amount'] ?? s['price'] ?? 0;
    final created = s['created'] ?? s['created_at'] ?? '---';
    final router = s['router'] ?? s['router_name'] ?? 'Mikrotik';
    final code = (s['code'] ?? s['mpesa_code'] ?? s['voucher'] ?? 'SESSION').toString().toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code,
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: PaceColors.getPrimaryText(isDark)),
                ),
                const SizedBox(height: 2),
                Text(
                  '$router • ${created.toString().split(' ')[0]}',
                  style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: PaceBadge(
                label: isActive ? 'Active' : 'Ended',
                variant: isActive ? BadgeVariant.success : BadgeVariant.secondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'KES $amount',
              textAlign: TextAlign.right,
              style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: PaceColors.green),
            ),
          ),
        ],
      ),
    );
  }
}
