import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
import '../components/empty_state.dart';
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
  bool _hasMore = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchMore();
      }
    }
  }

  Future<void> _fetchTransactions({bool forceRefresh = true}) async {
    try {
      final res = await _apiService.getMpesaTransactions(page: 1, search: _search, forceRefresh: forceRefresh);
      if (mounted && res != null) {
        setState(() {
          _transactions = res['data'] ?? [];
          _total = res['pagination']?['total'] ?? 0;
          _hasMore = res['pagination']?['has_more'] ?? false;
          _page = 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
    final receipt = txn['mpesa_receipt_number']?.toString() ?? 'N/A';
    final status = txn['status']?.toString().toLowerCase() ?? 'completed';

    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction Details',
                      style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                    ),
                    Text(
                      'KES ${txn['amount'] ?? '0'}',
                      style: GoogleFonts.figtree(fontSize: 15, fontWeight: FontWeight.bold, color: PaceColors.emerald),
                    ),
                  ],
                ),
                IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 20),
            _detailRow('Receipt Number', receipt, isDark, canCopy: true),
            _detailRow('Customer Phone', txn['phone_number']?.toString() ?? 'N/A', isDark),
            _detailRow('Customer Name', txn['full_name']?.toString() ?? 'Hotspot Guest', isDark),
            _detailRow('Amount Paid', 'KES ${txn['amount'] ?? '0'}', isDark),
            _detailRow('Status', status.toUpperCase(), isDark),
            _detailRow('Transaction Date', txn['transaction_date_formatted'] ?? txn['created_at'] ?? '-', isDark),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: receipt));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Receipt $receipt copied to clipboard', style: GoogleFonts.figtree()), backgroundColor: PaceColors.purple),
                  );
                },
                icon: const Icon(LucideIcons.copy, size: 16),
                label: Text('Copy Receipt Code', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PaceColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isDark, {bool canCopy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getDimText(isDark))),
          Row(
            children: [
              Text(
                value,
                style: GoogleFonts.figtree(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PaceColors.getPrimaryText(isDark),
                ),
              ),
              if (canCopy) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied $value', style: GoogleFonts.figtree()), duration: const Duration(seconds: 1)),
                    );
                  },
                  child: const Icon(LucideIcons.copy, size: 14, color: PaceColors.purple),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Column(
      children: [
        _buildHeader(isDark),
        _buildSearchBox(isDark),
        Expanded(
          child: _isLoading && _transactions.isEmpty
              ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 8))
              : RefreshIndicator(
                  onRefresh: () => _fetchTransactions(forceRefresh: true),
                  color: PaceColors.purple,
                  child: _transactions.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: PaceEmptyState(
                            title: 'No Transactions Found',
                            subtitle: 'Incoming M-Pesa receipts will automatically be recorded here.',
                            onRetry: () => _fetchTransactions(forceRefresh: true),
                            isDark: isDark,
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                          itemCount: _transactions.length + (_isLoadingMore ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index < _transactions.length) {
                              return _buildTransactionCard(_transactions[index], isDark);
                            }
                            if (index == _transactions.length && _isLoadingMore) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'M-Pesa Transactions',
                style: GoogleFonts.figtree(
                  color: PaceColors.getPrimaryText(isDark),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Gateway payment receipts and verification audit',
                style: GoogleFonts.figtree(
                  color: PaceColors.getDimText(isDark),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (_total > 0)
            PaceBadge(
              label: '$_total Total',
              variant: BadgeVariant.primary,
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBox(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: PaceSearchBar(
        hint: 'Search receipt code, phone or name...',
        isDark: isDark,
        onChanged: (val) {
          setState(() {
            _search = val;
            _isLoading = true;
            _transactions = [];
            _page = 1;
          });
          _fetchTransactions();
        },
      ),
    );
  }

  Widget _buildTransactionCard(dynamic txn, bool isDark) {
    final status = txn['status']?.toString().toLowerCase() ?? 'completed';
    final isSuccess = status.contains('success') || status.contains('complete') || status == '1';
    final isFailed = status.contains('fail') || status.contains('cancel') || status == '0';
    final receipt = txn['mpesa_receipt_number'] ?? 'N/A';
    final phone = txn['phone_number'] ?? 'N/A';
    final amount = txn['amount']?.toString() ?? '0';
    final date = txn['transaction_date_formatted'] ?? txn['created_at'] ?? '';

    BadgeVariant badgeVariant = BadgeVariant.success;
    if (isFailed) {
      badgeVariant = BadgeVariant.danger;
    } else if (!isSuccess) {
      badgeVariant = BadgeVariant.warning;
    }

    return InkWell(
      onTap: () => _showTransactionDetails(txn, isDark),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PaceColors.getBorder(isDark)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: PaceColors.emerald.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.arrowDownLeft, size: 18, color: PaceColors.emerald),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        receipt,
                        style: GoogleFonts.figtree(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: PaceColors.getPrimaryText(isDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PaceBadge(
                        label: isSuccess ? 'Completed' : (isFailed ? 'Failed' : 'Pending'),
                        variant: badgeVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$phone • $date',
                    style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'KES $amount',
                  style: GoogleFonts.figtree(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isFailed ? Colors.red.shade600 : PaceColors.emerald,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(LucideIcons.chevronRight, size: 14, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
