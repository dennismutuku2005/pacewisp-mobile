import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
      _isLoading = true;
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
            const GridSkeleton(count: 3)
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FINANCIAL REPORT', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
            Text('INCOME AND OPERATIONAL COSTS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2)),
        ]),
        IconButton(onPressed: () {}, icon: const Icon(LucideIcons.printer, color: PaceColors.purple, size: 20)),
      ],
    );
  }

  Widget _buildMonthNavigator(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: Row(children: [
        IconButton(onPressed: () => _changeMonth(-1), icon: Icon(LucideIcons.chevronLeft, color: PaceColors.getDimText(isDark))),
        Expanded(child: Center(child: Text(DateFormat('MMMM yyyy').format(_selectedDate).toUpperCase(), style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w600, color: PaceColors.purple, letterSpacing: 1.5)))),
        IconButton(onPressed: () => _changeMonth(1), icon: Icon(LucideIcons.chevronRight, color: PaceColors.getDimText(isDark))),
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
        Expanded(child: _buildMetricCard('INCOME', income, LucideIcons.trendingUp, PaceColors.emerald, isDark)),
        const SizedBox(width: 12),
        Expanded(child: _buildMetricCard('EXPENSES', expenses, LucideIcons.trendingDown, Colors.red, isDark)),
      ]),
      const SizedBox(height: 12),
      _buildMetricCard('NET PROFIT', profit, LucideIcons.activity, PaceColors.purple, isDark, subLabel: 'MARGIN: $margin%'),
    ]);
  }

  Widget _buildMetricCard(String label, dynamic value, IconData icon, Color color, bool isDark, {String? subLabel}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 16)),
          if (subLabel != null) Text(subLabel, style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 24),
        Text(label, style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        Text('KSH ${_currencyFormat.format(value)}', style: GoogleFonts.figtree(fontSize: 20, fontWeight: FontWeight.normal, color: PaceColors.getPrimaryText(isDark), letterSpacing: -0.5)),
      ]),
    );
  }

  Widget _buildTrendChart(bool isDark) {
    final List<dynamic> trend = _report?['daily_trend'] ?? [];
    if (trend.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(28), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('DAILY TREND', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
        Text('INCOME VS OPERATIONAL EXPENSES', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
        const SizedBox(height: 32),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1000, getDrawingHorizontalLine: (v) => FlLine(color: PaceColors.getBorder(isDark), strokeWidth: 1, dashArray: [4, 4])),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Text(v >= 1000 ? '${(v/1000).toInt()}k' : v.toInt().toString(), style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 8, fontWeight: FontWeight.w600)))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 8, fontWeight: FontWeight.w600)))),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                   spots: trend.map((e) => FlSpot(double.parse(e['day'].toString()), double.parse(e['income'].toString()))).toList(),
                   isCurved: true,
                   color: PaceColors.emerald,
                   barWidth: 4,
                   isStrokeCapRound: true,
                   dotData: const FlDotData(show: false),
                   belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [PaceColors.emerald.withOpacity(0.1), PaceColors.emerald.withOpacity(0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                ),
                LineChartBarData(
                   spots: trend.map((e) => FlSpot(double.parse(e['day'].toString()), double.parse(e['expenses'].toString()))).toList(),
                   isCurved: true,
                   color: Colors.redAccent,
                   barWidth: 4,
                   isStrokeCapRound: true,
                   dotData: const FlDotData(show: false),
                   belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [Colors.redAccent.withOpacity(0.1), Colors.redAccent.withOpacity(0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('INCOME', PaceColors.emerald),
            const SizedBox(width: 24),
            _buildLegendItem('EXPENSES', Colors.redAccent),
          ],
        ),
      ]),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label, style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w600, color: color, letterSpacing: 1)),
    ]);
  }

  Widget _buildExpenseBreakdown(bool isDark) {
    final List<dynamic> breakdown = _report?['expense_breakdown'] ?? [];
    if (breakdown.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(28), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('EXPENSE BREAKDOWN', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
        Text('DISTRIBUTION ACROSS COST CATEGORIES', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
        const SizedBox(height: 32),
        ...breakdown.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: const BoxDecoration(color: PaceColors.purple, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(child: Text(item['name'].toString().toUpperCase(), style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark), letterSpacing: 0.5))),
            Text('KSH ${_currencyFormat.format(item['value'])}', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.purple)),
          ]),
        )).toList(),
      ]),
    );
  }
}
