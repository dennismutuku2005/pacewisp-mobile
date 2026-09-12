import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
import '../components/empty_state.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final ApiService _apiService = ApiService();
  final _currencyFormat = NumberFormat("#,###", "en_US");

  List<dynamic> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getInvoices(forceRefresh: true);
      if (mounted) {
        setState(() {
          _invoices = res?['data'] ?? [];
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    final unpaidInvoices = _invoices.where((i) => i['status']?.toString().toLowerCase() != 'paid').toList();
    final totalDue = unpaidInvoices.fold<double>(0, (sum, i) => sum + (double.tryParse(i['amount']?.toString() ?? '0') ?? 0));

    return Column(
      children: [
        _buildHeader(isDark),
        _buildSummary(isDark, totalDue),
        Expanded(
          child: _isLoading && _invoices.isEmpty
              ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 6))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: PaceColors.purple,
                  child: _invoices.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: PaceEmptyState(
                            title: 'No Invoices Found',
                            subtitle: 'All billed service statements will be listed here.',
                            onRetry: _loadData,
                            isDark: isDark,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                          itemCount: _invoices.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _buildInvoiceCard(_invoices[index], isDark),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoices',
            style: GoogleFonts.figtree(
              color: PaceColors.purple,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Statements & monthly service fees',
            style: GoogleFonts.figtree(
              color: PaceColors.getDimText(isDark),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(bool isDark, double totalDue) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Outstanding Balance',
                style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark)),
              ),
              const SizedBox(height: 4),
              Text(
                'KES ${_currencyFormat.format(totalDue)}',
                style: GoogleFonts.figtree(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: totalDue > 0 ? Colors.red.shade600 : PaceColors.emerald,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(LucideIcons.receipt, color: PaceColors.purple, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(dynamic inv, bool isDark) {
    final status = inv['status']?.toString().toLowerCase() ?? 'pending';
    final isPaid = status == 'paid';
    final number = inv['invoice_number'] ?? 'INV';
    final dueDate = inv['due_date'] ?? inv['created_at'] ?? '';
    final amount = inv['amount']?.toString() ?? '0';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      number,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: PaceColors.getPrimaryText(isDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PaceBadge(
                      label: isPaid ? 'Paid' : 'Unpaid',
                      variant: isPaid ? BadgeVariant.success : BadgeVariant.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Due: $dueDate',
                  style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Text(
            'KES $amount',
            style: GoogleFonts.figtree(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isPaid ? PaceColors.emerald : Colors.red.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
