import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
            const SnackBar(content: Text('This number is already in the block list.'), backgroundColor: Colors.orangeAccent)
          );
        }
        setState(() => _isProcessing = false);
        return;
      }

      // Block the number
      final res = await _apiService.blockNumber(phone, reason: reason.isEmpty ? 'Manual Block' : reason);
      if (res?['status'] == 'success') {
        _phoneController.clear();
        _reasonController.clear();
        await _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Number blocked successfully'), backgroundColor: Colors.redAccent)
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
    final confirm = await _showConfirm(
      'UNBLOCK ACCESS?', 
      'Allow $phone to make M-Pesa push requests again?'
    );
    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final res = await _apiService.unblockNumber(phone);
      if (res?['status'] == 'success') {
        await _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Number unblocked successfully'), backgroundColor: PaceColors.emerald)
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
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: PaceColors.purple)),
        content: Text(msg, style: TextStyle(fontSize: 12, color: PaceColors.getPrimaryText(isDark))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    if (!settings.hasPolicy('manage_customers')) {
       return Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(LucideIcons.lock, size: 48, color: PaceColors.getDimText(isDark).withOpacity(0.2)),
             const SizedBox(height: 16),
             Text('ACCESS RESTRICTED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 2)),
           ],
         ),
       );
    }

    final filtered = _blocked.where((u) => (u['phone'] ?? '').toString().contains(_search)).toList();

    return PaceOverlayLoader(
      isLoading: _isProcessing,
      message: 'Processing security action...',
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
                  _buildBlockForm(isDark),
                  const SizedBox(height: 32),
                  _buildListHeader(isDark),
                  if (_isLoading && _blocked.isEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: SkeletonList(count: 5))
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
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.fingerprint, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'STK SECURITY CONTROL', 
                style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'RESTRICT NUMBERS FROM INITIATING PUSH PAYMENTS', 
            style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)
          ),
        ],
      ),
    );
  }

  Widget _buildBlockForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaceColors.getBorder(isDark)),
        boxShadow: [
          if (!isDark)
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BLOCK NEW NUMBER', 
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 0.5)
          ),
          const SizedBox(height: 16),
          _inputField('Mobile Number (e.g. 0712345678)', _phoneController, LucideIcons.phone, isDark),
          const SizedBox(height: 12),
          _inputField('Reason (e.g. Fraudulent)', _reasonController, LucideIcons.alertTriangle, isDark),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleBlock,
              icon: const Icon(LucideIcons.ban, size: 16),
              label: const Text('CONFIRM BLOCK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(String hint, TextEditingController controller, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark), fontFamily: 'monospace'),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: PaceColors.getDimText(isDark).withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold),
          icon: Icon(icon, color: PaceColors.getDimText(isDark), size: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildListHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'BLOCKED NUMBERS', 
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 0.5)
        ),
        PaceBadge(label: '${_blocked.length} BLOCKED', variant: BadgeVariant.error),
      ],
    );
  }

  Widget _buildBlockedItem(dynamic item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16),
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
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: PaceColors.purple, fontFamily: 'monospace')
                ),
                const SizedBox(height: 4),
                Text(
                  'REASON: ${item['reason']?.toString().toUpperCase() ?? 'MANUAL BLOCK'}', 
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 0.5)
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _miniStat('TRIALS: ${item['trial_count'] ?? 0}', Colors.orangeAccent, isDark),
                    const SizedBox(width: 8),
                    _miniStat('BLOCKED: ${item['blocked_at'] ?? 'N/A'}', PaceColors.getDimText(isDark), isDark),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _handleUnblock(item['phone']),
            style: ElevatedButton.styleFrom(
              backgroundColor: PaceColors.emerald.withOpacity(0.1), 
              foregroundColor: PaceColors.emerald, 
              elevation: 0, 
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: PaceColors.emerald.withOpacity(0.2)),
            ),
            child: const Text('UNBLOCK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Text(
        label, 
        style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: color)
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(LucideIcons.shieldCheck, size: 48, color: PaceColors.getDimText(isDark).withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            'CLEAN BLACKLIST', 
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)
          ),
        ],
      ),
    );
  }
}
