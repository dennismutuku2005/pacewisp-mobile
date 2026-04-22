import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/skeleton.dart';

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
    _fetchCachedThenLive();
  }

  Future<void> _fetchCachedThenLive() async {
    final cached = await _apiService.getAccountDetails(forceRefresh: false);
    if (mounted && cached != null && _accountData == null) {
      setState(() {
        _accountData = cached['data'] ?? cached;
        _isLoading = false;
      });
    }

    final live = await _apiService.getAccountDetails(forceRefresh: true);
    if (mounted && live != null) {
      setState(() {
        _accountData = live['data'] ?? live;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    if (_isLoading && _accountData == null) return const Scaffold(body: SkeletonList());

    final billing = _accountData?['billing'];
    final sub = _accountData?['subscription'];

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: RefreshIndicator(
        onRefresh: () => _fetchCachedThenLive(),
        color: PaceColors.purple,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            _buildHeader(isDark, _accountData?['customer_id']?.toString() ?? ''),
            const SizedBox(height: 24),
            _buildMainBillCard(isDark, billing, sub),
            const SizedBox(height: 24),
            _buildCalculationDetail(isDark, billing),
            const SizedBox(height: 24),
            _buildSidebarStats(isDark, billing, sub),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, String customerId) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('YOUR BILL', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
        Text('LIVE USAGE CYCLE SUMMARY', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
      ]),
      Text('ACC ID: $customerId', style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
    ]);
  }

  Widget _buildMainBillCard(bool isDark, dynamic billing, dynamic sub) {
    final double progress = (billing?['cycle_progress'] ?? 0).toDouble() / 100.0;
    final int daysLeft = sub?['days_left'] ?? 0;
    final String cyclesubs = daysLeft < 0 ? 'CYCLE ENDED ${daysLeft.abs()} DAYS AGO' : 'CYCLE ENDS IN $daysLeft DAYS';

    return Container(
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5), borderAtTop: true, topBorderColor: PaceColors.purple),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
               Text('AMOUNT DUE TO DATE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
               const Icon(Icons.receipt_long_rounded, color: PaceColors.purple, size: 18),
            ]),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('KSH', style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
              const SizedBox(width: 8),
              Text(_currencyFormat.format(billing?['current_estimated_bill'] ?? 0), style: GoogleFonts.figtree(fontSize: 34, fontWeight: FontWeight.normal, color: PaceColors.getPrimaryText(isDark), letterSpacing: -1)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
               Icon(Icons.calendar_month_rounded, size: 12, color: PaceColors.getDimText(isDark)),
               const SizedBox(width: 6),
               Text(cyclesubs, style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
            ]),
          ]),
        ),
        Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: progress.clamp(0.0, 1.0), child: Container(color: PaceColors.purple)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Text('${(progress * 100).toInt()}% CYCLE PROGRESS', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1)),
        ),
      ]),
    );
  }

  Widget _buildCalculationDetail(bool isDark, dynamic billing) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CALCULATION DETAIL', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark), letterSpacing: 1)),
        const SizedBox(height: 20),
        _buildCalcRow('BASE', 'STARTER PLAN (PRO-RATED)', 'KSH 1,499 x ${billing?['cycle_progress']}% ELAPSED', 'KSH ${_currencyFormat.format(billing?['base_fee'] * billing?['cycle_progress'] / 100)}', isDark),
        const Divider(height: 24),
        _buildCalcRow('ADD', 'EXTRA CLIENTS SURCHARGE', '${billing?['additional_users']} CLIENTS ABOVE LIMIT', 'KSH ${_currencyFormat.format(billing?['extra_fee'])}', isDark, iconColor: Colors.orange),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
               Icon(Icons.info_outline_rounded, size: 14, color: PaceColors.getDimText(isDark)),
               const SizedBox(width: 8),
               Text('MONTHLY PROJECTION', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark))),
            ]),
            Text('KSH ${_currencyFormat.format(billing?['total_monthly_projection'] ?? 0)}', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.purple)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCalcRow(String tag, String title, String sub, String amount, bool isDark, {Color? iconColor}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: (iconColor ?? PaceColors.purple).withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Center(child: Text(tag, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: iconColor ?? PaceColors.purple)))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
        Text(sub, style: GoogleFonts.figtree(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.normal)),
      ])),
      Text(amount, style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
    ]);
  }

  Widget _buildSidebarStats(bool isDark, dynamic billing, dynamic sub) {
    return Column(children: [
       _buildSmallStatCard('CURRENT CLIENTS', '${billing?['user_count']} TOTAL', Icons.people_outline_rounded, isDark),
       const SizedBox(height: 12),
       _buildSmallStatCard('BILLING POLICY', 'KSH 1,499 (110 CLIENTS)\nKSH 8 PER EXTRA CLIENT', Icons.shield_outlined, isDark),
       const SizedBox(height: 12),
       _buildSmallStatCard('NEXT INVOICE', sub?['next_payment'] ?? '', Icons.calendar_today_rounded, isDark),
    ]);
  }

  Widget _buildSmallStatCard(String label, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1)),
      child: Row(children: [
        Icon(icon, size: 16, color: PaceColors.getDimText(isDark)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
          Text(value, style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
        ])),
      ]),
    );
  }
}

extension on BoxDecoration {
  static BoxDecoration? borderAtTop({required Color topBorderColor}) {
    return BoxDecoration(
      border: Border(top: BorderSide(color: topBorderColor, width: 4)),
    );
  }
}
