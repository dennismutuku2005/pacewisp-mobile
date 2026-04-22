import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/skeleton.dart';

class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  final ApiService _apiService = ApiService();
  final _currencyFormat = NumberFormat("#,###", "en_US");
  
  Map<String, dynamic>? _report;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
     setState(() => _isLoading = true);
     final res = await _apiService.getFinancialReport(
       month: _selectedDate.month,
       year: _selectedDate.year,
       forceRefresh: true
     );
     if (mounted && res != null && res['status'] == 'success') {
       setState(() {
         _report = res['report'];
         _isLoading = false;
       });
     } else {
       if (mounted) setState(() => _isLoading = false);
     }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + offset);
    });
    _fetchReport();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return RefreshIndicator(
      onRefresh: () => _fetchReport(),
      color: PaceColors.purple,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 24),
          _buildMonthNavigator(isDark),
          const SizedBox(height: 32),
          if (_isLoading && _report == null)
            const SkeletonGrid(count: 3)
          else ...[
            _buildMetrics(isDark),
            const SizedBox(height: 32),
            _buildTrendChart(isDark),
            const SizedBox(height: 32),
            _buildExpenseBreakdown(isDark),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('FINANCIAL REPORT', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
        Text('ANALYSIS OF INCOME AND OPERATIONAL COSTS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
    ]);
  }

  Widget _buildMonthNavigator(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: Row(children: [
        IconButton(onPressed: () => _changeMonth(-1), icon: Icon(Icons.chevron_left, color: PaceColors.getDimText(isDark))),
        Expanded(child: Center(child: Text(DateFormat('MMMM yyyy').format(_selectedDate).toUpperCase(), style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1.5)))),
        IconButton(onPressed: () => _changeMonth(1), icon: Icon(Icons.chevron_right, color: PaceColors.getDimText(isDark))),
      ]),
    );
  }

  Widget _buildMetrics(bool isDark) {
    final income = _report?['total_income'] ?? 0;
    final expenses = _report?['total_expenses'] ?? 0;
    final profit = _report?['net_profit'] ?? 0;
    final margin = _report?['margin'] ?? '0';

    return Column(children: [
      Row(children: [
        Expanded(child: _buildMetricCard('INCOME', income, Icons.trending_up_rounded, PaceColors.emerald, isDark)),
        const SizedBox(width: 12),
        Expanded(child: _buildMetricCard('EXPENSES', expenses, Icons.trending_down_rounded, Colors.red, isDark)),
      ]),
      const SizedBox(height: 12),
      _buildMetricCard('NET PROFIT', profit, Icons.account_balance_rounded, PaceColors.purple, isDark, subLabel: 'MARGIN: $margin%'),
    ]);
  }

  Widget _buildMetricCard(String label, dynamic value, IconData icon, Color color, bool isDark, {String? subLabel}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 16)),
          if (subLabel != null) Text(subLabel, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 16),
        Text(label, style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
        Text('KSH ${_currencyFormat.format(value)}', style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.normal, color: PaceColors.getPrimaryText(isDark), letterSpacing: -0.5)),
      ]),
    );
  }

  Widget _buildTrendChart(bool isDark) {
    final List<dynamic> trend = _report?['daily_trend'] ?? [];
    if (trend.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('DAILY TREND', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w800, color: PaceColors.getPrimaryText(isDark))),
        Text('INCOME VS EXPENSES', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
        const SizedBox(height: 32),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  color: PaceColors.emerald,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  spots: trend.map((e) => FlSpot((e['day'] as num).toDouble(), (e['income'] as num).toDouble())).toList(),
                ),
                LineChartBarData(
                  isCurved: true,
                  color: Colors.red,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  spots: trend.map((e) => FlSpot((e['day'] as num).toDouble(), (e['expenses'] as num).toDouble())).toList(),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildExpenseBreakdown(bool isDark) {
    final List<dynamic> breakdown = _report?['expense_breakdown'] ?? [];
    if (breakdown.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('EXPENSE BREAKDOWN', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w800, color: PaceColors.getPrimaryText(isDark))),
        Text('DISTRIBUTION ACROSS CATEGORIES', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
        const SizedBox(height: 24),
        ...breakdown.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: PaceColors.purple, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(child: Text(item['name'].toString().toUpperCase(), style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)))),
            Text('KSH ${_currencyFormat.format(item['value'])}', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
          ]),
        )).toList(),
      ]),
    );
  }
}
