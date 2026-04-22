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

class BlockStkScreen extends StatefulWidget {
  const BlockStkScreen({super.key});

  @override
  State<BlockStkScreen> createState() => _BlockStkScreenState();
}

class _BlockStkScreenState extends State<BlockStkScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  List<dynamic> _blocked = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getBlockedNumbers();
      if (mounted && res != null) {
        setState(() {
          _blocked = res['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBlock() async {
    final phone = _phoneController.text.trim();
    final reason = _reasonController.text.trim();

    if (phone.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      // Check if already blocked (as done in WispPortal)
      final check = await _apiService.getBlockedNumbers(phone: phone);
      if (check?['is_blocked'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This number is already restricted.'), backgroundColor: Colors.orangeAccent)
          );
        }
        setState(() => _isProcessing = false);
        return;
      }

      final res = await _apiService.blockNumber(phone, reason: reason.isEmpty ? 'Manual Security Block' : reason);
      if (res?['status'] == 'success') {
        _phoneController.clear();
        _reasonController.clear();
        await _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Number restricted successfully'), backgroundColor: Colors.redAccent)
          );
        }
      }
    } catch (e) {
      debugPrint('Block Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleUnblock(String phone) async {
    final confirmed = await _showConfirm(
      'UNBLOCK ACCESS?', 
      'Allow $phone to initiate payment requests again?'
    );
    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final res = await _apiService.unblockNumber(phone);
      if (res?['status'] == 'success') {
        await _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restriction removed successfully'), backgroundColor: PaceColors.emerald)
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<bool?> _showConfirm(String title, String msg) {
    final isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getBackground(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w900, color: PaceColors.purple)),
        content: Text(msg, style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getPrimaryText(isDark))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold, color: PaceColors.purple))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    final filtered = _blocked.where((u) => (u['phone'] ?? '').toString().contains(_search)).toList();

    return PaceOverlayLoader(
      isLoading: _isProcessing,
      message: 'Processing security policy...',
      child: Container(
        color: PaceColors.getBackground(isDark),
        child: Column(
          children: [
            _buildHeader(isDark),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchData,
                color: PaceColors.purple,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    _buildForm(isDark),
                    const SizedBox(height: 32),
                    _buildListHeader(isDark),
                    const SizedBox(height: 16),
                    if (_isLoading && _blocked.isEmpty)
                      const SkeletonList(count: 5)
                    else if (filtered.isEmpty) 
                      _buildEmptyState(isDark)
                    else
                      ...filtered.map((item) => _buildBlockedItem(item, isDark)),
                  ],
                ),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.shieldAlert, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Text('STK SECURITY CONTROL', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            ],
          ),
          Text('PREVENT SUSPICIOUS NUMBERS FROM INITIATING PUSH PAYMENTS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: PaceColors.getBorder(isDark)),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ADD RESTRICTION', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1.5)),
          const SizedBox(height: 20),
          _inputField('PHONE NUMBER', _phoneController, LucideIcons.phone, isDark),
          const SizedBox(height: 12),
          _inputField('REASON', _reasonController, LucideIcons.alertTriangle, isDark),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleBlock,
              icon: const Icon(LucideIcons.lock, size: 16),
              label: const Text('CONFIRM RESTRICTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(String label, TextEditingController controller, IconData icon, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: PaceColors.getSurface(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PaceColors.getBorder(isDark)),
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
            decoration: InputDecoration(
              icon: Icon(icon, color: PaceColors.getDimText(isDark), size: 14),
              border: InputBorder.none,
              hintText: label == 'REASON' ? 'Optional reason...' : 'e.g. 0712...',
              hintStyle: TextStyle(fontSize: 11, color: PaceColors.getDimText(isDark).withOpacity(0.3)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('RESTRICTED LIST', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        PaceBadge(label: '${_blocked.length} ACTIVE', variant: BadgeVariant.error),
      ],
    );
  }

  Widget _buildBlockedItem(dynamic item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['phone']?.toString() ?? 'PRIVATE', 
                  style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))
                ),
                const SizedBox(height: 4),
                Text(
                  'REASON: ${item['reason']?.toString().toUpperCase() ?? 'MANUAL BLOCK'}', 
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 0.5)
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _miniStat('TRIALS: ${item['trial_count'] ?? 0}', Colors.orangeAccent, isDark),
                    const SizedBox(width: 8),
                    _miniStat('SINCE: ${item['blocked_at']?.toString().split(' ')[0] ?? 'N/A'}', PaceColors.getDimText(isDark), isDark),
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => _handleUnblock(item['phone']),
            style: OutlinedButton.styleFrom(
              foregroundColor: PaceColors.emerald,
              side: BorderSide(color: PaceColors.emerald.withOpacity(0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('ALLOW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Text(label, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(LucideIcons.shieldCheck, size: 48, color: PaceColors.getDimText(isDark).withOpacity(0.1)),
            const SizedBox(height: 16),
            Text('NO SECURITY RESTRICTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}
