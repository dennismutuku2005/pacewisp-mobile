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
import '../components/search_bar.dart';
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
        title: Text(title, style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600, color: PaceColors.purple)),
        content: Text(msg, style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getPrimaryText(isDark))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.w600, color: PaceColors.purple))),
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
      child: Scaffold(
        backgroundColor: PaceColors.getBackground(isDark),
        body: Column(
          children: [
            _buildHeader(isDark),
            _buildQuickActions(isDark),
            Expanded(
              child: _isLoading && _blocked.isEmpty
                ? const Padding(padding: EdgeInsets.all(24.0), child: SkeletonList(count: 8))
                : Column(
                    children: [
                      _buildTableHeader(isDark),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _fetchData,
                          color: PaceColors.purple,
                          child: filtered.isEmpty 
                            ? SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: PaceEmptyState(onRetry: _fetchData, isDark: isDark, title: 'NO SECURITY RESTRICTIONS', subtitle: 'All numbers have full payment access. Slide down to refresh.'))
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark).withOpacity(0.4), height: 1),
                                itemBuilder: (context, index) => _buildBlockedRow(filtered[index], isDark),
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
                Text('STK SECURITY CONTROL', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
                Text('RESTRICT SUSPICIOUS NUMBERS FROM PAYMENTS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2)),
              ],
            ),
          ),
          IconButton(
            onPressed: _showBlockModal,
            icon: const Icon(LucideIcons.plusCircle, color: PaceColors.purple, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PaceSearchBar(
        hint: 'Search blocked numbers...', 
        isDark: isDark, 
        onChanged: (val) => setState(() => _search = val)
      ),
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
          Expanded(flex: 3, child: Text('RESTRICTED PHONE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
          Expanded(flex: 2, child: Text('TRIALS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
          Expanded(flex: 2, child: Text('ACTION', textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
        ],
      ),
    );
  }

  Widget _buildBlockedRow(dynamic item, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['phone']?.toString() ?? 'PRIVATE', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
                const SizedBox(height: 4),
                Text('REASON: ${item['reason']?.toString().toUpperCase() ?? 'MANUAL BLOCK'}', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
              child: Text('${item['trial_count'] ?? 0} ATTEMPTS', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.red)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _handleUnblock(item['phone']),
                  style: TextButton.styleFrom(
                    foregroundColor: PaceColors.emerald,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('ALLOW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockModal() {
    final isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: PaceColors.getBorder(isDark), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Icon(LucideIcons.shieldAlert, color: Colors.redAccent, size: 32),
              const SizedBox(height: 12),
              Text('ADD SECURITY RESTRICTION', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: PaceColors.purple, letterSpacing: 1.5)),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _modalInput('PHONE NUMBER', _phoneController, LucideIcons.phone, isDark),
                    const SizedBox(height: 16),
                    _modalInput('REASON', _reasonController, LucideIcons.alertTriangle, isDark),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleBlock();
                        },
                        icon: const Icon(LucideIcons.lock, size: 16),
                        label: const Text('CONFIRM RESTRICTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modalInput(String label, TextEditingController controller, IconData icon, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
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
            style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w500, color: PaceColors.getPrimaryText(isDark)),
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

}

