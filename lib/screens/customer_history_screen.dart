import 'dart:async';
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
          _sessions = res['sessions'] ?? rootData?['sessions'] ?? res['data'] ?? [];
          _isBlocked = (res['is_blocked'] == true || rootData?['is_blocked'] == true);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSecurity() async {
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
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: PaceOverlayLoader(
        isLoading: _isProcessing,
        message: 'Syncing security policy...',
        child: Column(
          children: [
            _buildHeader(isDark),
            _buildQuickStats(isDark),
            Expanded(
              child: _isLoading 
                ? const Padding(padding: EdgeInsets.all(24.0), child: SkeletonList(count: 8))
                : Column(
                    children: [
                      _buildTableHeader(isDark),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _fetchData,
                          color: PaceColors.purple,
                          child: _sessions.isEmpty
                            ? SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: PaceEmptyState(onRetry: _fetchData, isDark: isDark))
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                                itemCount: _sessions.length,
                                separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark).withOpacity(0.4), height: 1),
                                itemBuilder: (context, index) => _buildSessionRow(_sessions[index], isDark),
                              ),
                        ),
                      ),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(LucideIcons.arrowLeft, color: PaceColors.getPrimaryText(isDark), size: 20),
            style: IconButton.styleFrom(
              backgroundColor: PaceColors.getSurface(isDark),
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.phone, style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
                Text('CUSTOMER USAGE & TRANSACTION LOGS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2)),
              ],
            ),
          ),
          IconButton(
            onPressed: _toggleSecurity,
            icon: Icon(_isBlocked ? LucideIcons.shieldAlert : LucideIcons.shieldCheck, color: _isBlocked ? Colors.red : PaceColors.emerald, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark).withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PaceColors.getBorder(isDark).withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('TOTAL SPENT', 'KES ${_summary?['total_spent'] ?? _summary?['total_amount'] ?? 0}', isDark),
          _statItem('ENTRIES', '${_summary?['sessions'] ?? _summary?['total_visits'] ?? 0}', isDark),
          _statItem('LAST SEEN', _summary?['last_seen']?.toString().split(',')[0] ?? 'N/A', isDark),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
      ],
    );
  }

  Widget _buildTableHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark).withOpacity(0.3),
        border: Border(
          top: BorderSide(color: PaceColors.getBorder(isDark).withOpacity(0.5)),
          bottom: BorderSide(color: PaceColors.getBorder(isDark).withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('TRANSACTION / NODE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
          Expanded(flex: 2, child: Text('USAGE STATUS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
          Expanded(flex: 2, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
        ],
      ),
    );
  }

  Widget _buildSessionRow(dynamic s, bool isDark) {
    final bool isActive = (s['active'] == true || s['active']?.toString() == '1');
    final bool isUsed = (s['used'] == true || s['used']?.toString() == '1');
    
    final amount = s['amount'] ?? s['price'] ?? 0;
    final created = s['created'] ?? s['created_at'] ?? 'N/A';
    final expires = s['expires'] ?? s['expire_time'] ?? 'N/A';
    final mac = s['mac'] ?? 'N/A';
    final router = s['router'] ?? s['router_name'] ?? 'SYSTEM';
    final code = (s['code'] ?? s['mpesa_code'] ?? s['voucher'] ?? 'SESSION').toString().toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(code, style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
                const SizedBox(height: 4),
                Text(router.toString().toUpperCase(), style: TextStyle(fontSize: 7, color: PaceColors.purple, fontWeight: FontWeight.w600, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(mac.toString().toUpperCase(), style: GoogleFonts.jetBrainsMono(fontSize: 8, color: PaceColors.getDimText(isDark))),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PaceBadge(
                      label: isActive ? 'ACTIVE' : 'EXPIRED', 
                      variant: isActive ? BadgeVariant.success : BadgeVariant.error,
                    ),
                    const SizedBox(width: 4),
                    if (isUsed) PaceBadge(label: 'USED', variant: BadgeVariant.secondary),
                  ],
                ),
                const SizedBox(height: 8),
                Text('IN: $created', style: TextStyle(fontSize: 7, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600)),
                Text('EX: $expires', style: TextStyle(fontSize: 7, color: PaceColors.purple.withOpacity(0.7), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('KES $amount', textAlign: TextAlign.right, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.emerald)),
          ),
        ],
      ),
    );
  }
}
