import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/skeleton.dart';

class CustomerHistoryScreen extends StatefulWidget {
  final String phone;
  const CustomerHistoryScreen({super.key, required this.phone});

  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _history = [];
  Map<String, dynamic>? _summary;
  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isBlocked = false;
  bool _fetchLock = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && !_fetchLock) {
        _loadMore();
      }
    }
  }

  /// Mirrors WispPortal: loadHistory(1) + checkBlockStatus() in parallel
  Future<void> _loadInitial() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _api.getCustomerHistory(phone: widget.phone, page: 1, forceRefresh: true),
      _api.checkBlockStatus(widget.phone),
    ]);

    final res = results[0];
    final blockRes = results[1];

    if (mounted) {
      setState(() {
        if (res != null && res['status'] == 'success') {
          // Backend: { data: [...history], summary: {...}, pagination: {...} }
          _history = res['data'] ?? [];
          _summary = res['summary'];
          _hasMore = res['pagination']?['has_more'] ?? false;
          _page = 1;
        }
        _isBlocked = blockRes?['is_blocked'] == true;
        _isLoading = false;
      });
    }
  }

  /// Mirrors WispPortal: loadHistory(page+1, true)
  Future<void> _loadMore() async {
    if (_fetchLock) return;
    _fetchLock = true;
    setState(() => _isLoadingMore = true);

    final nextPage = _page + 1;
    try {
      final res = await _api.getCustomerHistory(phone: widget.phone, page: nextPage, forceRefresh: true);
      if (mounted && res != null && res['status'] == 'success') {
        setState(() {
          final newItems = res['data'] ?? [];
          _history.addAll(newItems);
          _hasMore = res['pagination']?['has_more'] ?? false;
          _page = nextPage;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
      _fetchLock = false;
    }
  }

  Future<void> _toggleBlock() async {
    final action = _isBlocked ? 'Unblock' : 'Block';
    final confirm = await _showConfirm('$action CUSTOMER', 'Are you sure you want to ${action.toLowerCase()} STK for ${widget.phone}?');
    if (confirm != true) return;

    if (_isBlocked) {
      await _api.unblockNumber(widget.phone);
    } else {
      await _api.blockNumber(widget.phone);
    }
    // Re-check status
    final blockRes = await _api.checkBlockStatus(widget.phone);
    if (mounted) setState(() => _isBlocked = blockRes?['is_blocked'] == true);
  }

  Future<void> _purgeRecord() async {
    final confirm = await _showConfirm('PURGE ALL RECORDS', 'Delete entire history for ${widget.phone}? This cannot be undone.');
    if (confirm != true) return;

    final res = await _api.deleteCustomer(widget.phone);
    if (res?['status'] == 'success' && mounted) Navigator.pop(context);
  }

  Future<bool?> _showConfirm(String title, String msg) {
    final isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getBackground(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1)),
        content: Text(msg, style: const TextStyle(fontSize: 12)),
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

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: PaceColors.getCard(isDark),
        elevation: 0,
        title: Text('CUSTOMER HISTORY', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1.5)),
        actions: [
          IconButton(onPressed: _loadInitial, icon: const Icon(LucideIcons.refreshCw, size: 18)),
        ],
      ),
      body: _isLoading
        ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList())
        : RefreshIndicator(
            onRefresh: _loadInitial,
            color: PaceColors.purple,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                // Phone + Block badge
                _buildProfileHeader(isDark),
                const SizedBox(height: 16),

                // Summary Cards (mirrors WispPortal's 4 summary cards)
                if (_summary != null) _buildSummaryCards(isDark),
                const SizedBox(height: 16),

                // Action strip
                if (settings.hasPolicy('manage_customers')) _buildActionStrip(isDark),
                const SizedBox(height: 24),

                // History table header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark)))),
                  child: Row(children: [
                    Expanded(flex: 3, child: Text('M-PESA CODE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
                    Expanded(flex: 2, child: Text('AMOUNT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
                    Expanded(flex: 2, child: Text('DATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
                  ]),
                ),

                // History rows
                if (_history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: Column(children: [
                      Icon(LucideIcons.history, size: 40, color: PaceColors.getDimText(isDark).withOpacity(0.15)),
                      const SizedBox(height: 12),
                      Text('NO HISTORY FOUND', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
                    ])),
                  )
                else
                  ..._history.map((h) => _buildHistoryRow(h, isDark)),

                // Loading more indicator
                if (_isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)),
                  ),

                // End of history
                if (!_hasMore && _history.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('END OF HISTORY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark).withOpacity(0.4), letterSpacing: 1.5))),
                  ),

                const SizedBox(height: 100),
              ],
            ),
          ),
    );
  }

  Widget _buildProfileHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(LucideIcons.user, color: PaceColors.purple, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.phone, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark), letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(_summary?['last_mac']?.toString().toUpperCase() ?? 'NO MAC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
        ])),
        if (_isBlocked)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.2))),
            child: const Text('BLOCKED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.red, letterSpacing: 1)),
          ),
      ]),
    );
  }

  /// Mirrors WispPortal's 4 summary cards: Total Revenue, Total Entries, Last Seen, Latest MAC
  Widget _buildSummaryCards(bool isDark) {
    return Row(children: [
      _summaryCard('TOTAL REVENUE', 'KES ${_summary?['total_spent'] ?? '0'}', PaceColors.purple, isDark),
      const SizedBox(width: 8),
      _summaryCard('SESSIONS', '${_summary?['sessions'] ?? 0}', PaceColors.getPrimaryText(isDark), isDark),
      const SizedBox(width: 8),
      _summaryCard('LAST SEEN', _summary?['last_seen']?.toString() ?? 'Never', PaceColors.getDimText(isDark), isDark),
    ]);
  }

  Widget _summaryCard(String label, String value, Color valueColor, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: valueColor), overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _buildActionStrip(bool isDark) {
    return Row(children: [
      Expanded(child: _actionButton(_isBlocked ? 'UNBLOCK STK' : 'BLOCK STK', _isBlocked ? LucideIcons.shieldCheck : LucideIcons.shieldAlert, _isBlocked ? PaceColors.emerald : Colors.redAccent, isDark, _toggleBlock)),
      const SizedBox(width: 12),
      Expanded(child: _actionButton('PURGE RECORD', LucideIcons.trash2, Colors.orangeAccent, isDark, _purgeRecord)),
    ]);
  }

  Widget _actionButton(String label, IconData icon, Color color, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 1)),
        ]),
      ),
    );
  }

  /// Mirrors WispPortal's history table row: code, mac, amount, router, status, used, date
  Widget _buildHistoryRow(dynamic h, bool isDark) {
    final bool isActive = h['active'] == true;

    return InkWell(
      onTap: () => _showDetailDrawer(h, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark)))),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h['code']?.toString() ?? '---', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
              const SizedBox(height: 2),
              Text(h['router']?.toString().replaceAll('_', ' ') ?? '---', style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark))),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Text('KES ${h['amount'] ?? '0'}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.purple)),
          ),
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(h['created']?.toString() ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: (isActive ? PaceColors.emerald : Colors.redAccent).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(isActive ? 'ACTIVE' : 'EXPIRED', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: isActive ? PaceColors.emerald : Colors.redAccent)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _showDetailDrawer(dynamic h, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getBackground(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('SESSION DETAIL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.purple)),
            IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(ctx)),
          ]),
          const SizedBox(height: 16),
          _detailRow('M-PESA CODE', h['code']?.toString() ?? '---', isDark),
          _detailRow('MAC ADDRESS', h['mac']?.toString() ?? '---', isDark),
          _detailRow('AMOUNT', 'KES ${h['amount'] ?? '0'}', isDark),
          _detailRow('ROUTER', h['router']?.toString().replaceAll('_', ' ') ?? '---', isDark),
          _detailRow('CREATED', h['created']?.toString() ?? '---', isDark),
          _detailRow('EXPIRES', h['expires']?.toString() ?? '---', isDark),
          _detailRow('STATUS', h['active'] == true ? 'ACTIVE' : 'EXPIRED', isDark),
          _detailRow('USED', h['used'] == true ? 'YES' : 'NO', isDark),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
      ]),
    );
  }
}
