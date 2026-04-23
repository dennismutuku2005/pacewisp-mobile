import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/skeleton.dart';
import '../components/search_bar.dart';
import '../components/overlay_loader.dart';

class MpesaTransactionsScreen extends StatefulWidget {
  const MpesaTransactionsScreen({super.key});

  @override
  State<MpesaTransactionsScreen> createState() => _MpesaTransactionsScreenState();
}

class _MpesaTransactionsScreenState extends State<MpesaTransactionsScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _transactions = [];
  int _page = 1;
  int _total = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isProcessing = false;
  bool _hasMore = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchCachedThenLive();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchMore();
      }
    }
  }

  Future<void> _fetchCachedThenLive() async {
    // 1. SILENT CACHE LOAD
    final cached = await _apiService.getMpesaTransactions(page: 1, search: _search, forceRefresh: false);
    if (mounted && cached != null && _transactions.isEmpty) {
      setState(() {
        _transactions = cached['data'] ?? [];
        _total = cached['pagination']?['total'] ?? 0;
        _hasMore = cached['pagination']?['has_more'] ?? false;
        _isLoading = false;
      });
    }

    // 2. LIVE REFRESH
    final live = await _apiService.getMpesaTransactions(page: 1, search: _search, forceRefresh: true);
    if (mounted && live != null) {
      setState(() {
        _transactions = live['data'] ?? [];
        _total = live['pagination']?['total'] ?? 0;
        _hasMore = live['pagination']?['has_more'] ?? false;
        _page = 1;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMore() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final currentSearch = _search;
    final res = await _apiService.getMpesaTransactions(page: nextPage, search: _search, forceRefresh: true);
    if (mounted && res != null && _search == currentSearch) {
      setState(() {
        _transactions.addAll(res['data'] ?? []);
        _hasMore = res['pagination']?['has_more'] ?? false;
        _page = nextPage;
        _isLoadingMore = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  void _showTransactionDetails(dynamic txn, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getBackground(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TRANSACTION DETAILS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: PaceColors.purple, letterSpacing: -0.5)),
                IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 20),
            _drawerRow('RECEIPT', txn['mpesa_receipt_number']?.toString() ?? 'N/A', isDark),
            _drawerRow('PHONE', txn['phone_number']?.toString() ?? 'N/A', isDark),
            _drawerRow('NAME', txn['full_name']?.toString() ?? 'N/A', isDark),
            _drawerRow('AMOUNT', 'KES ${txn['amount'] ?? '0'}', isDark),
            _drawerRow('STATUS', (txn['status']?.toString() ?? 'PENDING').toUpperCase(), isDark),
            _drawerRow('DATE', txn['transaction_date_formatted'] ?? txn['created_at'] ?? '-', isDark),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(LucideIcons.checkCircle, size: 16),
                label: const Text('CLOSE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PaceColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return PaceOverlayLoader(
      isLoading: _isProcessing,
      message: 'Processing...',
      child: Column(
        children: [
          _buildHeader(isDark),
          _buildSearchBox(isDark),
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark)))),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('RECEIPT / PHONE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
                Expanded(flex: 2, child: Text('AMOUNT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
                Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
              ],
            ),
          ),
          Expanded(
            child: _isLoading && _transactions.isEmpty
              ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 10))
              : RefreshIndicator(
                  onRefresh: () => _fetchCachedThenLive(),
                  color: PaceColors.purple,
                  child: _transactions.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(LucideIcons.creditCard, size: 48, color: PaceColors.getDimText(isDark).withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text('NO TRANSACTIONS FOUND', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
                      ]))
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: _transactions.length + (_isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                        itemBuilder: (context, index) {
                          if (index < _transactions.length) {
                            return _buildTransactionRow(_transactions[index], isDark);
                          }
                          if (index == _transactions.length && _isLoadingMore) {
                             return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)));
                          }
                          return const SizedBox.shrink();
                        },
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('M-PESA TRANSACTIONS', style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
              Text('AUTOMATED AUDIT LOGS', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2)),
            ],
          ),
          IconButton(onPressed: () {}, icon: const Icon(LucideIcons.download, color: PaceColors.purple, size: 20)),
        ],
      ),
    );
  }

  Widget _buildSearchBox(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: PaceSearchBar(
        hint: 'Search code, phone or name...',
        isDark: isDark,
        onChanged: (val) { 
          setState(() {
            _search = val;
            _isLoading = true;
            _transactions = []; // Clear current list to show skeleton
            _page = 1;
          });
          _fetchCachedThenLive(); 
        },
      ),
    );
  }

  Widget _buildTransactionRow(dynamic txn, bool isDark) {
    final status = txn['status']?.toString().toLowerCase() ?? 'unknown';
    Color statusColor = PaceColors.emerald;
    if (status.contains('fail')) statusColor = Colors.red;
    if (status.contains('pending')) statusColor = Colors.amber;

    return InkWell(
      onTap: () => _showTransactionDetails(txn, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txn['mpesa_receipt_number'] ?? 'N/A', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
                  const SizedBox(height: 2),
                  Text(txn['phone_number'] ?? 'N/A', style: TextStyle(fontSize: 10, color: PaceColors.getDimText(isDark))),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text('KES ${txn['amount']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(status.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: statusColor)),
                  ),
                  const Spacer(),
                  Icon(Icons.more_vert, size: 16, color: PaceColors.getDimText(isDark)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
