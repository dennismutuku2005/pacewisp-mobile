import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
    if (_accountData == null) return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: RefreshIndicator(
        onRefresh: () => _fetchCachedThenLive(),
        color: PaceColors.purple,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.8,
            child: PaceEmptyState(onRetry: () => _fetchCachedThenLive(), isDark: isDark, title: 'ACCOUNT DATA UNAVAILABLE', subtitle: 'We couldn\'t load your billing information. Please check your connection and retry.'),
          ),
        ),
      ),
    );

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
        Text('LIVE USAGE CYCLE SUMMARY', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2)),
      ]),
      IconButton(
        onPressed: () {},
        icon: const Icon(LucideIcons.printer, color: PaceColors.purple, size: 20),
      ),
    ]);
  }

  Widget _buildMainBillCard(bool isDark, dynamic billing, dynamic sub) {
    final double progress = (billing?['cycle_progress'] ?? 0).toDouble() / 100.0;
    final int daysLeft = sub?['days_left'] ?? 0;
    final String cyclesubs = daysLeft < 0 ? 'CYCLE ENDED ${daysLeft.abs()} DAYS AGO' : 'CYCLE ENDS IN $daysLeft DAYS';

    return Container(
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark), 
        borderRadius: BorderRadius.circular(28), 
        border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5),
        boxShadow: isDark ? [] : [BoxShadow(color: PaceColors.purple.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 10))]
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [PaceColors.purple, PaceColors.purple.withOpacity(0.8)]),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('CURRENT SERVICE PERIOD', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
                Text(_formatDate(sub?['current_period_end']), style: GoogleFonts.jetBrainsMono(fontSize: 8, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('ESTIMATED ACCRUAL', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
                Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(LucideIcons.activity, color: PaceColors.purple, size: 14)),
              ]),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('KES', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.purple.withOpacity(0.5))),
                const SizedBox(width: 8),
                Text(_currencyFormat.format(billing?['current_estimated_bill'] ?? 0), style: GoogleFonts.figtree(fontSize: 42, fontWeight: FontWeight.normal, color: PaceColors.getPrimaryText(isDark), letterSpacing: -1.5)),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Icon(LucideIcons.calendar, size: 12, color: PaceColors.getDimText(isDark)),
                const SizedBox(width: 8),
                Text(cyclesubs, style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
              ]),
            ]),
          ),
          Container(
            height: 6,
            width: double.infinity,
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: progress.clamp(0.0, 1.0), child: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [PaceColors.purple, Colors.blueAccent])))),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationDetail(bool isDark, dynamic billing) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(28), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ALGORITHMIC BREAKDOWN', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark), letterSpacing: 1.5)),
        const SizedBox(height: 24),
        _buildCalcRow('BASE', 'STARTER PLAN (PRO-RATED)', 'KSH 1,499 x ${billing?['cycle_progress']}% ELAPSED', 'KSH ${_currencyFormat.format(billing?['base_fee'] * (billing?['cycle_progress'] ?? 0) / 100)}', isDark),
        const Divider(height: 32),
        _buildCalcRow('ADD', 'CLIENT SURCHARGE', '${billing?['additional_users']} CLIENTS ABOVE TIER 1', 'KSH ${_currencyFormat.format(billing?['extra_fee'])}', isDark, iconColor: Colors.orangeAccent),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.purple.withOpacity(0.1))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
                Icon(LucideIcons.info, size: 14, color: PaceColors.purple),
                const SizedBox(width: 10),
                Text('MONTHLY PROJECTION', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w600, color: PaceColors.purple, letterSpacing: 0.5)),
            ]),
            Text('KSH ${_currencyFormat.format(billing?['total_monthly_projection'] ?? 0)}', style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w600, color: PaceColors.purple)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCalcRow(String tag, String title, String sub, String amount, bool isDark, {Color? iconColor}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: (iconColor ?? PaceColors.purple).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(tag, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w600, color: iconColor ?? PaceColors.purple)))),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
        Text(sub, style: GoogleFonts.figtree(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      ])),
      Text(amount, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
    ]);
  }

  Widget _buildSidebarStats(bool isDark, dynamic billing, dynamic sub) {
    return Column(children: [
        _buildSmallStatCard('CLIENT DENSITY', '${billing?['user_count']} ACTIVE NODES', LucideIcons.users, isDark, PaceColors.purple),
        const SizedBox(height: 12),
        _buildSmallStatCard('BILLING POLICY', 'KSH 1,499 BASE TIER', LucideIcons.shieldCheck, isDark, Colors.blueAccent),
        const SizedBox(height: 12),
        _buildSmallStatCard('NEXT INVOICE', _formatDate(sub?['next_payment']), LucideIcons.calendar, isDark, Colors.orangeAccent),
    ]);
  }

  String _formatDate(String? date) {
    if (date == null) return 'PENDING';
    try {
      final d = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(d).toUpperCase();
    } catch (_) {
      return date.toUpperCase();
    }
  }

  Widget _buildSmallStatCard(String label, String value, IconData icon, bool isDark, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark), width: 1)),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
          Text(value, style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
        ])),
      ]),
    );
  }
}
