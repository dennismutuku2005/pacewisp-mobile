import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/dashboard_chart.dart';
import '../components/skeleton.dart';
import '../components/badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _widgets;
  List<dynamic> _charts = [];
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  bool _isRevenueVisible = false;

  @override
  void initState() {
    super.initState();
    _fetchCachedThenLive();
  }

  Future<void> _fetchCachedThenLive() async {
    // 1. Silent loading from cache first
    final cachedWidgets = await _apiService.getSummaryWidgets(forceRefresh: false);
    final cachedCharts = await _apiService.getSummaryCharts(forceRefresh: false);
    final cachedTxs = await _apiService.getRecentTransactions(limit: 5, forceRefresh: false);

    if (mounted) {
      setState(() {
        _widgets = cachedWidgets?['data']?['widgets'] ?? cachedWidgets?['widgets'] ?? cachedWidgets?['data'];
        _charts = cachedCharts?['data']?['charts']?['revenue_over_time'] ?? cachedCharts?['charts']?['revenue_over_time'] ?? cachedCharts?['data']?['revenue_over_time'] ?? [];
        _transactions = cachedTxs?['data']?['recent_transactions'] ?? cachedTxs?['recent_transactions'] ?? cachedTxs?['data'] ?? [];
        if (_widgets != null) _isLoading = false;
      });
    }

    // 2. Fetch live data silently
    final results = await Future.wait([
      _apiService.getSummaryWidgets(forceRefresh: true),
      _apiService.getSummaryCharts(forceRefresh: true),
      _apiService.getRecentTransactions(limit: 5, forceRefresh: true),
    ]);

    if (mounted) {
      setState(() {
        final res0 = results[0];
        final res1 = results[1];
        final res2 = results[2];
        _widgets = res0?['data']?['widgets'] ?? res0?['widgets'] ?? res0?['data'];
        _charts = res1?['data']?['charts']?['revenue_over_time'] ?? res1?['charts']?['revenue_over_time'] ?? res1?['data']?['revenue_over_time'] ?? [];
        _transactions = res2?['data']?['recent_transactions'] ?? res2?['recent_transactions'] ?? res2?['data'] ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return RefreshIndicator(
      onRefresh: () => _fetchCachedThenLive(),
      color: PaceColors.purple,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopHeader(isDark),
                  const SizedBox(height: 24),
                  _buildMetricsScroller(isDark),
                  const SizedBox(height: 32),
                  _buildQuickGenerate(isDark),
                  const SizedBox(height: 32),
                  _buildChartSection(isDark),
                  const SizedBox(height: 32),
                  _buildRecentActivity(isDark),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DASHBOARD OVERVIEW', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            Text('FINANCIAL & NETWORK ANALYTICS', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ],
        ),
        IconButton(
          onPressed: () => setState(() => _isRevenueVisible = !_isRevenueVisible),
          icon: Icon(_isRevenueVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: PaceColors.purple),
          style: IconButton.styleFrom(backgroundColor: PaceColors.purple.withOpacity(0.05)),
        )
      ],
    );
  }

  Widget _buildMetricsScroller(bool isDark) {
    if (_isLoading && _widgets == null) {
      return const SkeletonGrid(count: 4);
    }

    final metrics = [
      {'label': "TODAY'S EARNINGS", 'value': _widgets?['todays_earnings']?['value'] ?? 0, 'icon': Icons.account_balance_wallet_rounded, 'color': PaceColors.purple, 'blur': false},
      {'label': "MONTH REVENUE", 'value': _widgets?['month_revenue']?['value'] ?? 0, 'icon': Icons.payments_rounded, 'color': const Color(0xFF3B82F6), 'blur': true},
      {'label': "DAILY ENTRIES", 'value': _widgets?['active_users']?['value'] ?? 0, 'icon': Icons.bolt_rounded, 'color': Colors.amber, 'blur': false},
      {'label': "MONTH USERS", 'value': _widgets?['total_customers']?['value'] ?? 0, 'icon': Icons.groups_rounded, 'color': PaceColors.emerald, 'blur': true},
    ];

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: metrics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final m = metrics[index];
          final color = m['color'] as Color;
          final bool blurIt = m['blur'] as bool && !_isRevenueVisible;
          
          return Container(
            width: 170,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PaceColors.getCard(isDark),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                      child: Icon(m['icon'] as IconData, color: color, size: 18),
                    ),
                    const Spacer(),
                    Text(m['label'] as String, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
                    const SizedBox(height: 2),
                    if (blurIt)
                      ClipRect(child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), child: Text('KSH 88,888', style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark)))))
                    else
                      Text(
                        m['label'].toString().contains('REVENUE') || m['label'].toString().contains('EARNINGS') 
                          ? 'KSH ${_format(m['value'])}' 
                          : _format(m['value']),
                        style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark)),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickGenerate(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [PaceColors.purple, PaceColors.purple.withBlue(255)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: PaceColors.purple.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.confirmation_num_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('QUICK GENERATE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.8), letterSpacing: 2)),
                const SizedBox(height: 4),
                Text('VOUCHER ASSETS', style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // Trigger modal in Vouchers
            },
            icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
            style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), padding: const EdgeInsets.all(16)),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('REVENUE FLOW', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 0.5)),
                  Text('NETWORK GROWTH TRAJECTORY', style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ],
              ),
              const Icon(Icons.trending_up_rounded, color: PaceColors.purple, size: 24),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(height: 200, child: DashboardChart(chartData: _charts)),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text('RECENT NETWORK ENTRIES', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ),
        Container(
          decoration: BoxDecoration(
            color: PaceColors.getCard(isDark),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5),
          ),
          child: _transactions.isEmpty
            ? const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No recent activity')))
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _transactions.length,
                separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                itemBuilder: (context, index) {
                  final tx = _transactions[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.flash_on_rounded, color: PaceColors.purple, size: 18),
                    ),
                    title: Text(tx['user_phone'] ?? 'System', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                    subtitle: Text(tx['time_ago'] ?? 'Just now', style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    trailing: Text('KES ${tx['amount']}', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w900, color: PaceColors.purple)),
                  );
                },
              ),
        ),
      ],
    );
  }

  String _format(dynamic val) {
    if (val == null) return "0";
    try {
      final double n = double.parse(val.toString());
      if (n >= 1000) return "${(n / 1000).toStringAsFixed(1)}K";
      return n.toStringAsFixed(0);
    } catch (e) {
      return "0";
    }
  }
}
