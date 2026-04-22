import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/skeleton.dart';
import '../components/badge.dart';
import '../components/overlay_loader.dart';

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
  bool _fetchLock = false;
  bool _isBlocked = false;
  bool _isProcessing = false;

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

  Future<void> _loadInitial() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _api.getCustomerHistory(phone: widget.phone, page: 1, forceRefresh: true),
        _api.getBlockedNumbers(phone: widget.phone),
      ]);

      final historyRes = results[0];
      final blockRes = results[1];

      if (mounted) {
        setState(() {
          if (historyRes != null && historyRes['status'] == 'success') {
            _history = historyRes['data'] ?? [];
            _summary = historyRes['summary'];
            _hasMore = historyRes['pagination']?['has_more'] ?? false;
            _page = 1;
          }
          _isBlocked = blockRes?['is_blocked'] == true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
    final action = _isBlocked ? 'UNBLOCK' : 'BLOCK';
    final confirm = await _showConfirm(
      '$action CUSTOMER?',
      _isBlocked 
        ? 'Allow this number to make STK push requests again?' 
        : 'Prevent this number from making any M-Pesa payments on the portal?'
    );
    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      if (_isBlocked) {
        await _api.unblockNumber(widget.phone);
      } else {
        await _api.blockNumber(widget.phone);
      }
      
      // Re-verify status
      final blockRes = await _api.getBlockedNumbers(phone: widget.phone);
      if (mounted) {
        setState(() {
          _isBlocked = blockRes?['is_blocked'] == true;
          _isProcessing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Customer ${widget.phone} has been ${_isBlocked ? 'blocked' : 'unblocked'}.'),
            backgroundColor: _isBlocked ? Colors.redAccent : PaceColors.emerald,
          )
        );
      }
    } catch (e) {
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
        title: Text(
          title, 
          style: TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.w900, 
            color: PaceColors.purple, 
            letterSpacing: 0.5
          )
        ),
        content: Text(msg, style: TextStyle(fontSize: 12, color: PaceColors.getPrimaryText(isDark))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), 
            child: Text('CANCEL', style: TextStyle(color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold, fontSize: 11))
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('CONFIRM', style: TextStyle(color: PaceColors.purple, fontWeight: FontWeight.w900, fontSize: 11))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<SettingsProvider>(context).isDarkMode;

    return PaceOverlayLoader(
      isLoading: _isProcessing,
      message: 'Updating security status...',
      child: Scaffold(
        backgroundColor: PaceColors.getBackground(isDark),
        appBar: AppBar(
          backgroundColor: PaceColors.getBackground(isDark),
          elevation: 0,
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: PaceColors.getPrimaryText(isDark)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'CUSTOMER HISTORY',
            style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w900, 
              color: PaceColors.getPrimaryText(isDark),
              letterSpacing: 1.5,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _loadInitial, 
              icon: Icon(LucideIcons.refreshCw, size: 18, color: PaceColors.purple)
            ),
          ],
        ),
        body: _isLoading
          ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList())
          : RefreshIndicator(
              onRefresh: _loadInitial,
              color: PaceColors.purple,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildProfileHeader(isDark),
                        const SizedBox(height: 20),
                        if (_summary != null) _buildSummaryCards(isDark),
                        const SizedBox(height: 20),
                        _buildActionStrip(isDark),
                        const SizedBox(height: 32),
                        _buildTableHeader(isDark),
                      ]),
                    ),
                  ),
                  if (_history.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(isDark),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == _history.length) {
                              return const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)),
                              );
                            }
                            return _buildHistoryRow(_history[index], isDark);
                          },
                          childCount: _history.length + (_isLoadingMore ? 1 : 0),
                        ),
                      ),
                    ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isDark) {
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PaceColors.purple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.user, color: PaceColors.purple, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.phone,
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.w900, 
                    color: PaceColors.getPrimaryText(isDark),
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _summary?['last_mac']?.toString().toUpperCase() ?? 'NO MAC RECORDED',
                  style: TextStyle(
                    fontSize: 9, 
                    fontWeight: FontWeight.w900, 
                    color: PaceColors.getDimText(isDark),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          if (_isBlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.fingerprint, size: 10, color: Colors.red),
                  const SizedBox(width: 4),
                  const Text(
                    'BLOCKED', 
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.red, letterSpacing: 0.5)
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            _summaryCard('TOTAL REVENUE', 'KES ${_summary?['total_spent'] ?? '0'}', PaceColors.purple, isDark),
            const SizedBox(width: 12),
            _summaryCard('SESSIONS', '${_summary?['sessions'] ?? 0}', PaceColors.getPrimaryText(isDark), isDark),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _summaryCard('LAST SEEN', _summary?['last_seen']?.toString().toUpperCase() ?? 'NEVER', PaceColors.getDimText(isDark), isDark),
            const SizedBox(width: 12),
            _summaryCard('STATUS', _history.isNotEmpty && _history[0]['active'] == true ? 'ACTIVE' : 'IDLE', PaceColors.emerald, isDark),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard(String label, String value, Color valColor, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PaceColors.getBorder(isDark)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label, 
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1)
            ),
            const SizedBox(height: 6),
            Text(
              value, 
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: valColor),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionStrip(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            _isBlocked ? 'UNBLOCK STK' : 'BLOCK STK', 
            _isBlocked ? LucideIcons.unlock : LucideIcons.ban, 
            _isBlocked ? PaceColors.emerald : Colors.redAccent, 
            isDark, 
            _toggleBlock
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionButton(
            'PURGE RECORD', 
            LucideIcons.trash2, 
            Colors.orangeAccent, 
            isDark, 
            () => _showConfirm('PURGE RECORDS', 'Delete entire history for ${widget.phone}? This cannot be undone.')
          ),
        ),
      ],
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              label, 
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 1)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('SESSION INFO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 0.5))),
          Expanded(flex: 2, child: Text('AMOUNT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 0.5))),
          Expanded(flex: 2, child: Text('VISIBILITY', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 0.5))),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(dynamic h, bool isDark) {
    final bool isActive = h['active'] == true;
    final bool isUsed = h['used'] == true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h['code']?.toString() ?? 'VOUCHER', 
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark), fontFamily: 'monospace')
                ),
                const SizedBox(height: 2),
                Text(
                  h['router']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'UNKNOWN', 
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KES ${h['amount'] ?? '0'}', 
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: PaceColors.purple)
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    PaceBadge(label: isUsed ? 'USED' : 'UNUSED', variant: isUsed ? BadgeVariant.success : BadgeVariant.standard),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  h['created']?.toString().toUpperCase() ?? '', 
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark))
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: (isActive ? PaceColors.emerald : Colors.redAccent).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4)
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'EXPIRED', 
                    style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: isActive ? PaceColors.emerald : Colors.redAccent)
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.history, size: 40, color: PaceColors.getDimText(isDark).withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            'NO HISTORY FOUND', 
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)
          ),
        ],
      ),
    );
  }
}
