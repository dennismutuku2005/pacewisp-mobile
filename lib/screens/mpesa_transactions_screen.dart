import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/api_service.dart';
import '../services/settings_provider.dart';
import 'package:provider/provider.dart';
import '../theme/pace_theme.dart';

class MpesaTransactionsScreen extends StatefulWidget {
  const MpesaTransactionsScreen({super.key});

  @override
  State<MpesaTransactionsScreen> createState() => _MpesaTransactionsScreenState();
}

class _MpesaTransactionsScreenState extends State<MpesaTransactionsScreen> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  String _search = '';
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
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
        _loadMore();
      }
    }
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getMpesaTransactions(page: 1, search: _search, forceRefresh: forceRefresh);
      if (res != null && res['status'] == 'success') {
        setState(() {
          _transactions = res['data'] ?? [];
          _total = res['pagination']?['total'] ?? 0;
          _hasMore = res['pagination']?['has_more'] ?? false;
          _page = 1;
        });
      }
    } catch (e) {
      debugPrint("M-Pesa load error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final res = await _api.getMpesaTransactions(page: nextPage, search: _search);
      if (res != null && res['status'] == 'success') {
        setState(() {
          _transactions.addAll(res['data'] ?? []);
          _hasMore = res['pagination']?['has_more'] ?? false;
          _page = nextPage;
        });
      }
    } catch (e) {
      debugPrint("M-Pesa load more error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Color _getStatusColor(String status) {
    status = status.toLowerCase();
    if (status.contains('success')) return Colors.emerald;
    if (status.contains('fail')) return Colors.red;
    return Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaceColors.bgSubtle,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "M-PESA TRANSACTIONS",
              style: GoogleFonts.figtree(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: PaceColors.purple,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              "Automated Transaction Audit",
              style: GoogleFonts.figtree(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey[400],
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _loadData(forceRefresh: true),
            icon: Icon(LucideIcons.refreshCw, size: 18, color: PaceColors.purple),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PaceColors.outline),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (v) {
                  setState(() => _search = v);
                  _loadData();
                },
                style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "Search by phone or M-Pesa code...",
                  hintStyle: GoogleFonts.figtree(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.normal),
                  prefixIcon: const Icon(LucideIcons.search, size: 18, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Total Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: PaceColors.purple.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: PaceColors.purple.withOpacity(0.1)),
                  ),
                  child: Text(
                    "$_total RECORDS",
                    style: GoogleFonts.jetbrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: PaceColors.purple,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: PaceColors.outline)),
            ),
            child: Row(
              children: [
                Expanded(child: _headerText("CODE / PHONE")),
                Expanded(child: _headerText("AMOUNT", textAlign: TextAlign.right)),
                const SizedBox(width: 20),
                SizedBox(width: 80, child: _headerText("STATUS", textAlign: TextAlign.center)),
              ],
            ),
          ),

          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadData(forceRefresh: true),
              color: PaceColors.purple,
              child: _isLoading && _transactions.isEmpty
                  ? _buildShimmer()
                  : _transactions.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: _transactions.length + (_isLoadingMore ? 1 : 0),
                          separatorBuilder: (c, i) => Divider(height: 1, color: PaceColors.outline),
                          itemBuilder: (context, index) {
                            if (index == _transactions.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            }

                            final txn = _transactions[index];
                            final status = txn['status']?.toString() ?? 'Unknown';

                            return Container(
                              color: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          txn['mpesa_receipt_number'] ?? 'N/A',
                                          style: GoogleFonts.jetbrainsMono(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: PaceColors.purple,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          txn['phone_number'] ?? 'N/A',
                                          style: GoogleFonts.figtree(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          txn['transaction_date_formatted'] ?? '',
                                          style: GoogleFonts.figtree(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      "KES ${double.tryParse(txn['amount'].toString())?.toStringAsFixed(2) ?? '0.00'}",
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.figtree(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  SizedBox(
                                    width: 80,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.figtree(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: _getStatusColor(status),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerText(String text, {TextAlign textAlign = TextAlign.left}) {
    return Text(
      text,
      textAlign: textAlign,
      style: GoogleFonts.figtree(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: Colors.grey[400],
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.search, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "NO TRANSACTIONS FOUND",
            style: GoogleFonts.figtree(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey[400],
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.separated(
      itemCount: 8,
      separatorBuilder: (c, i) => Divider(height: 1, color: PaceColors.outline),
      itemBuilder: (c, i) => Container(
        height: 80,
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 12, width: 100, color: Colors.grey[100]),
                  const SizedBox(height: 4),
                  Container(height: 10, width: 80, color: Colors.grey[50]),
                ],
              ),
            ),
            Container(height: 14, width: 60, color: Colors.grey[100]),
            const SizedBox(width: 20),
            Container(height: 20, width: 70, decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(6))),
          ],
        ),
      ),
    );
  }
}
