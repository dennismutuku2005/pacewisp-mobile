import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
import '../components/empty_state.dart';

class MyBillScreen extends StatefulWidget {
  const MyBillScreen({super.key});

  @override
  State<MyBillScreen> createState() => _MyBillScreenState();
}

class _MyBillScreenState extends State<MyBillScreen> {
  final ApiService _apiService = ApiService();
  final _currencyFormat = NumberFormat("#,###", "en_US");

  Map<String, dynamic>? _accountData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAccountDetails();
  }

  Future<void> _fetchAccountDetails() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getAccountDetails(forceRefresh: true);
      if (mounted && res != null) {
        setState(() {
          _accountData = res['data'] ?? res;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    if (_isLoading && _accountData == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: SkeletonList(count: 6),
      );
    }

    if (_accountData == null) {
      return RefreshIndicator(
        onRefresh: _fetchAccountDetails,
        color: PaceColors.purple,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            alignment: Alignment.center,
            child: PaceEmptyState(
              title: 'Account Billing Unavailable',
              subtitle: 'We could not load your subscription and usage information.',
              onRetry: _fetchAccountDetails,
              isDark: isDark,
            ),
          ),
        ),
      );
    }

    final billing = _accountData?['billing'];
    final sub = _accountData?['subscription'];

    return RefreshIndicator(
      onRefresh: _fetchAccountDetails,
      color: PaceColors.purple,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 16),
          _buildMainBillCard(isDark, billing, sub),
          const SizedBox(height: 16),
          _buildUsageBreakdown(isDark, billing),
          const SizedBox(height: 16),
          _buildSubscriptionDetails(isDark, sub),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Bill',
          style: GoogleFonts.figtree(
            color: PaceColors.purple,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Platform usage estimation & recurring cycle',
          style: GoogleFonts.figtree(
            color: PaceColors.getDimText(isDark),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMainBillCard(bool isDark, dynamic billing, dynamic sub) {
    final int daysLeft = sub?['days_left'] ?? 0;
    final String cycleStatus = daysLeft < 0 ? 'Ended ${daysLeft.abs()} days ago' : 'Renews in $daysLeft days';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimated Current Bill',
                style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark)),
              ),
              PaceBadge(label: cycleStatus, variant: daysLeft < 3 ? BadgeVariant.warning : BadgeVariant.primary),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'KES ',
                style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.purple),
              ),
              Text(
                _currencyFormat.format(billing?['current_estimated_bill'] ?? 0),
                style: GoogleFonts.figtree(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: PaceColors.getPrimaryText(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: PaceColors.getBorder(isDark), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Billing Cycle',
                style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark)),
              ),
              Text(
                sub?['current_period_end'] ?? 'Active Period',
                style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsageBreakdown(bool isDark, dynamic billing) {
    final double revenue = double.tryParse(billing?['cycle_revenue']?.toString() ?? '0') ?? 0;
    final int transactions = billing?['transaction_count'] ?? 0;
    final String rate = billing?['platform_rate']?.toString() ?? 'Standard';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Usage Metrics',
            style: GoogleFonts.figtree(fontSize: 15, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
          ),
          const SizedBox(height: 12),
          _rowItem('Gross Hotspot Revenue', 'KES ${_currencyFormat.format(revenue)}', isDark),
          _rowItem('Total Transactions', transactions.toString(), isDark),
          _rowItem('Service Tier Rate', rate, isDark),
        ],
      ),
    );
  }

  Widget _buildSubscriptionDetails(bool isDark, dynamic sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subscription Plan',
            style: GoogleFonts.figtree(fontSize: 15, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
          ),
          const SizedBox(height: 12),
          _rowItem('Plan Name', sub?['plan_name'] ?? 'WISP Enterprise', isDark),
          _rowItem('Status', (sub?['status'] ?? 'Active').toString().toUpperCase(), isDark),
          _rowItem('Next Invoice Date', sub?['next_invoice_date'] ?? sub?['current_period_end'] ?? '-', isDark),
        ],
      ),
    );
  }

  Widget _rowItem(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getDimText(isDark))),
          Text(value, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
        ],
      ),
    );
  }
}
