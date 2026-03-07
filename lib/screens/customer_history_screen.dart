import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _history = [];
  Map<String, dynamic>? _summary;
  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isBlocked = false;
  bool _isBlockLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSyncMemory();
    _fetchHistory();
    _checkBlockStatus();
    _scrollController.addListener(_onScroll);
  }

  void _loadSyncMemory() {
    final mem = _apiService.getMemoryCached('customer_history', params: {'phone': widget.phone, 'page': 1});
    if (mem != null) {
      _history = mem['data'] ?? [];
      _summary = mem['summary'];
      _isLoading = false;
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchMoreHistory();
      }
    }
  }

  Future<void> _fetchHistory({bool force = false}) async {
    if (!force) {
      // 1. SILENT CACHE LOAD
      final cached = await _apiService.getCustomerHistory(phone: widget.phone, page: 1, forceRefresh: false);
      if (mounted && cached != null && _history.isEmpty) {
        setState(() {
          _history = cached['data'] ?? [];
          _summary = cached['summary'];
          _isLoading = false;
        });
      }
    }

    // 2. LIVE REFRESH
    final live = await _apiService.getCustomerHistory(phone: widget.phone, page: 1, forceRefresh: true);
    if (mounted && live != null) {
      setState(() {
        _history = live['data'] ?? [];
        _summary = live['summary'];
        _hasMore = live['pagination']?['has_more'] ?? false;
        _isLoading = false;
        _page = 1;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMoreHistory() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final res = await _apiService.getCustomerHistory(phone: widget.phone, page: nextPage);
    if (mounted) {
      setState(() {
        final newItems = res?['data'] ?? [];
        _history.addAll(newItems);
        _hasMore = res?['pagination']?['has_more'] ?? false;
        _page = nextPage;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _checkBlockStatus() async {
    final res = await _apiService.checkBlockStatus(widget.phone);
    if (mounted && res != null) {
      setState(() => _isBlocked = res['is_blocked'] ?? false);
    }
  }

  Future<void> _handleBlockToggle() async {
    final action = _isBlocked ? 'Unblock' : 'Block';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action Customer?'),
        content: Text(_isBlocked 
          ? 'Allow ${widget.phone} to make STK push requests again?' 
          : 'Blacklist ${widget.phone} from making any M-Pesa payments on the portal?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(action.toUpperCase(), style: TextStyle(color: _isBlocked ? Colors.green : Colors.red))),
        ],
      )
    );

    if (confirm == true) {
      setState(() => _isBlockLoading = true);
      try {
        if (_isBlocked) {
          await _apiService.unblockNumber(widget.phone);
        } else {
          await _apiService.blockNumber(widget.phone);
        }
        await _checkBlockStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Customer ${widget.phone} ${_isBlocked ? 'blocked' : 'unblocked'} successfully'),
            backgroundColor: _isBlocked ? Colors.red : Colors.green,
          ));
        }
      } finally {
        if (mounted) setState(() => _isBlockLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      appBar: AppBar(
        title: Text('Customer History', style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: PaceColors.getBackground(isDark),
        foregroundColor: PaceColors.getPrimaryText(isDark),
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildUserInfoHeader(isDark),
          if (_summary != null) _buildSummaryCards(isDark),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('LOGS & TRANSACTIONS', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 2)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading && _history.isEmpty
              ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 8))
              : RefreshIndicator(
                  onRefresh: () => _fetchHistory(force: true),
                  color: PaceColors.purple,
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _history.length + (_isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                    itemBuilder: (context, index) {
                      if (index == _history.length) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)));
                      return _buildHistoryItem(_history[index], isDark);
                    },
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.phone, style: GoogleFonts.jetBrainsMono(fontSize: 22, fontWeight: FontWeight.w900, color: PaceColors.purple)),
              if (_isBlocked)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.withOpacity(0.2))),
                  child: Row(
                    children: [
                      const Icon(Icons.security_rounded, color: Colors.red, size: 10),
                      const SizedBox(width: 4),
                      Text('BLACKLISTED', style: GoogleFonts.figtree(color: Colors.red, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ],
                  ),
                ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _isBlockLoading ? null : _handleBlockToggle,
            icon: _isBlockLoading 
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(_isBlocked ? Icons.lock_open_rounded : Icons.lock_person_rounded, size: 16),
            label: Text(_isBlocked ? 'UNBLOCK' : 'BLOCK', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isBlocked ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              foregroundColor: _isBlocked ? Colors.green : Colors.red,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: (_isBlocked ? Colors.green : Colors.red).withOpacity(0.2))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
        children: [
          _buildSummaryCard('REVENUE', 'KES ${_summary?['total_spent']}', PaceColors.purple, isDark),
          _buildSummaryCard('SESSIONS', '${_summary?['sessions']}', Colors.indigo, isDark),
          _buildSummaryCard('LAST SEEN', '${_summary?['last_seen']}', PaceColors.emerald, isDark),
          _buildSummaryCard('LATEST MAC', '${_summary?['last_mac']}', Colors.blueGrey, isDark, isMono: true),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color, bool isDark, {bool isMono = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: GoogleFonts.figtree(color: color.withOpacity(0.6), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 2),
          Text(value, 
            style: isMono 
              ? GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: color)
              : GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(dynamic item, bool isDark) {
    final bool isActive = item['active'] == true || item['active'] == '1';
    final String code = item['code'] ?? 'N/A';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(code, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                  const SizedBox(height: 2),
                  Text(item['router']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'UNKNOWN ROUTER', 
                    style: GoogleFonts.figtree(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('KES ${item['amount']}', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w900, color: PaceColors.purple)),
                  PaceBadge(label: isActive ? 'ACTIVE' : 'EXPIRED', variant: isActive ? BadgeVariant.success : BadgeVariant.error),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 10, color: Colors.blueGrey),
                  const SizedBox(width: 4),
                  Text('IN: ${item['created']}', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.history_rounded, size: 10, color: Colors.redAccent),
                  const SizedBox(width: 4),
                  Text('EXP: ${item['expires']}', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
