import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

class CustomerHistoryScreen extends StatefulWidget {
  final String phone;
  const CustomerHistoryScreen({super.key, required this.phone});

  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  List<dynamic> _history = [];
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final res = await _apiService.getCustomerHistory(phone: widget.phone, forceRefresh: true);
    final blockStatus = await _apiService.checkBlockStatus(widget.phone);
    
    if (mounted && res != null) {
      setState(() {
        _profile = res['data'];
        _history = res['data']?['history'] ?? [];
        _isBlocked = blockStatus?['is_blocked'] == true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: PaceColors.getCard(isDark),
        elevation: 0,
        title: Text('CUSTOMER PROFILE', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1.5)),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(LucideIcons.refreshCw, size: 18)),
        ],
      ),
      body: _isLoading 
        ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList())
        : RefreshIndicator(
            onRefresh: _loadData,
            color: PaceColors.purple,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                _buildProfileHeader(isDark),
                const SizedBox(height: 32),
                _buildActionStrip(isDark, settings),
                const SizedBox(height: 32),
                _buildHistorySection(isDark),
                const SizedBox(height: 100),
              ],
            ),
          ),
    );
  }

  Widget _buildProfileHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(32), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(LucideIcons.user, color: PaceColors.purple, size: 40),
          ),
          const SizedBox(height: 20),
          Text(widget.phone, style: GoogleFonts.jetBrainsMono(fontSize: 22, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark))),
          Text(_profile?['mac']?.toString().toUpperCase() ?? 'NONE DETECTED', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric('TOTAL SPENT', 'KES ${_profile?['totalSpent'] ?? 0}'),
              _buildMetric('SESSIONS', '${_profile?['sessions'] ?? 0}'),
              _buildMetric('STATUS', _profile?['status']?.toString().toUpperCase() ?? 'OFFLINE', color: _profile?['status'] == 'Active' ? PaceColors.emerald : Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  Widget _buildActionStrip(bool isDark, SettingsProvider settings) {
    if (!settings.hasPolicy('manage_customers')) return const SizedBox();

    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            _isBlocked ? 'UNBLOCK STK' : 'BLOCK STK',
            _isBlocked ? LucideIcons.shieldCheck : LucideIcons.shieldAlert,
            _isBlocked ? PaceColors.emerald : Colors.redAccent,
            isDark,
            _toggleBlock,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            'PURGE RECORD',
            LucideIcons.trash2,
            Colors.orangeAccent,
            isDark,
            _purgeRecord,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 1)),
        ]),
      ),
    );
  }

  Future<void> _toggleBlock() async {
    final bool? confirm = await _showConfirm(_isBlocked ? 'UNBLOCK USER' : 'BLOCK USER', 'Are you sure you want to ${_isBlocked ? 'unblock' : 'block'} STK prompts for ${widget.phone}?');
    if (confirm != true) return;

    if (_isBlocked) {
      await _apiService.unblockNumber(widget.phone);
    } else {
      await _apiService.blockNumber(widget.phone);
    }
    _loadData();
  }

  Future<void> _purgeRecord() async {
    final bool? confirm = await _showConfirm('PURGE ALL RECORDS', 'Delete entire connection and financial history for ${widget.phone}? This cannot be undone.');
    if (confirm != true) return;

    final res = await _apiService.deleteCustomer(widget.phone);
    if (res?['status'] == 'success') {
      Navigator.pop(context);
    }
  }

  Future<bool?> _showConfirm(String title, String msg) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getBackground(Provider.of<SettingsProvider>(context).isDarkMode),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w900, color: PaceColors.purple)),
        content: Text(msg, style: GoogleFonts.figtree(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildHistorySection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CONNECTION HISTORY', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 2)),
        const SizedBox(height: 16),
        if (_history.isEmpty)
           Container(padding: const EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('NO RECORDED ACTIVITY', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))))
        else
          ..._history.map((h) => _buildHistoryItem(h, isDark)).toList(),
      ],
    );
  }

  Widget _buildHistoryItem(dynamic h, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: const Icon(LucideIcons.wifi, color: PaceColors.purple, size: 16)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h['plan_name'] ?? 'UNKNOWN PLAN', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold)),
            Text(h['date_created'] ?? h['created_at'] ?? '', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
          ])),
          Text('KES ${h['amount']}', style: GoogleFonts.jetbrainsMono(fontSize: 12, fontWeight: FontWeight.w900, color: PaceColors.purple)),
        ],
      ),
    );
  }
}
