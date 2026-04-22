import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

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
    final res = await _apiService.getMpesaTransactions(page: nextPage, search: _search, forceRefresh: true);
    if (mounted && res != null) {
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

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Column(
      children: [
        _buildHeader(isDark),
        _buildSearchBox(isDark),
        _buildStatsBar(isDark),
        Expanded(
          child: _isLoading && _transactions.isEmpty
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 10))
            : RefreshIndicator(
                onRefresh: () => _fetchCachedThenLive(),
                color: PaceColors.purple,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: _transactions.length + (_isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                  itemBuilder: (context, index) {
                    if (index == _transactions.length) {
                       return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)));
                    }
                    return _buildTransactionItem(_transactions[index], isDark);
                  },
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('M-PESA TRANSACTIONS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
              Text('AUTOMATED AUDIT & TRANSACTION LOGS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ],
          ),
          IconButton(onPressed: () {}, icon: const Icon(LucideIcons.download, color: PaceColors.purple, size: 20)),
        ],
      ),
    );
  }

  Widget _buildSearchBox(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
        child: TextField(
          onChanged: (val) { _search = val; _fetchCachedThenLive(); },
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
          decoration: InputDecoration(
            hintText: 'Search by phone, name or M-Pesa code...', 
            hintStyle: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 12), 
            icon: Icon(LucideIcons.search, color: PaceColors.getDimText(isDark), size: 20), 
            border: InputBorder.none, 
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.05), borderRadius: BorderRadius.circular(6), border: Border.all(color: PaceColors.purple.withOpacity(0.1))),
            child: Text('$_total RECORDS FOUND', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(dynamic txn, bool isDark) {
    final status = txn['status']?.toString().toLowerCase() ?? 'unknown';
    Color statusColor = PaceColors.emerald;
    if (status.contains('fail')) statusColor = Colors.red;
    if (status.contains('pending')) statusColor = Colors.amber;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn['mpesa_receipt_number'] ?? 'N/A', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: PaceColors.purple)),
                const SizedBox(height: 2),
                Text(txn['phone_number'] ?? 'N/A', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                const SizedBox(height: 4),
                Text(txn['transaction_date_formatted'] ?? txn['created_at'] ?? '', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('KES ${txn['amount']}', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark))),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(status.toUpperCase(), style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: statusColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
