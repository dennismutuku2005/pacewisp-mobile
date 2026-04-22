import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
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
          // Robust mapping to handle different API response structures
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
      appBar: AppBar(
        backgroundColor: PaceColors.getBackground(isDark),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: PaceColors.getPrimaryText(isDark), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.phone, style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
        actions: [
          IconButton(
            icon: Icon(_isBlocked ? LucideIcons.shieldAlert : LucideIcons.shieldCheck, color: _isBlocked ? Colors.red : PaceColors.emerald, size: 20),
            onPressed: _toggleSecurity,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PaceOverlayLoader(
        isLoading: _isProcessing,
        message: 'Syncing security policy...',
        child: _isLoading 
          ? const Padding(padding: EdgeInsets.all(24.0), child: SkeletonList(count: 8))
          : RefreshIndicator(
              onRefresh: _fetchData,
              color: PaceColors.purple,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  _buildQuickStats(isDark),
                  const SizedBox(height: 32),
                  Text('TRANSACTION HISTORY', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  if (_sessions is! List || (_sessions as List).isEmpty)
                    _buildEmptyState(isDark)
                  else
                    ...(_sessions as List).map((s) => _buildSessionItem(s, isDark)),
                  const SizedBox(height: 100),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildQuickStats(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark).withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('SPENT', 'KES ${_summary?['total_amount'] ?? 0}', isDark),
          _statItem('SESSIONS', '${_summary?['total_visits'] ?? 0}', isDark),
          _statItem('LAST SEEN', _summary?['last_bought']?.toString().split(' ')[0] ?? 'N/A', isDark),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.purple)),
      ],
    );
  }

  Widget _buildSessionItem(dynamic s, bool isDark) {
    final bool isUsed = (s['used']?.toString() == '1');
    final amount = s['amount'] ?? 0;
    final date = s['created'] ?? s['created_at'] ?? 'N/A';
    final plan = s['plan'] ?? 'HOTSPOT PLAN';

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark).withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(s['mpesa_code']?.toString().toUpperCase() ?? 'VOUCHER', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                    const SizedBox(width: 8),
                    if (isUsed) PaceBadge(label: 'USED', variant: BadgeVariant.success)
                    else PaceBadge(label: 'UNUSED', variant: BadgeVariant.standard),
                  ],
                ),
                const SizedBox(height: 6),
                Text('$plan • $date', style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text('KES $amount', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(LucideIcons.history, size: 40, color: PaceColors.getDimText(isDark).withOpacity(0.1)),
          const SizedBox(height: 16),
          Text('NO HISTORY RECORDED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        ],
      ),
    );
  }
}
