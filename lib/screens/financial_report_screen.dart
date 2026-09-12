import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
import '../components/empty_state.dart';

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
    try {
      final res = await _apiService.getFinancialReport(
        month: _selectedDate.month,
        year: _selectedDate.year,
        forceRefresh: true,
      );
      if (mounted && res != null && res['status'] == 'success') {
        setState(() {
          _report = res['report'];
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 16),
          _buildMonthNavigator(isDark),
          const SizedBox(height: 20),
          if (_isLoading && _report == null)
            const GridSkeleton(count: 3)
          else if (_report == null)
            PaceEmptyState(
              title: 'No Financial Data',
              subtitle: 'No financial transactions were recorded during this month.',
              onRetry: _fetchReport,
              isDark: isDark,
            )
          else ...[
            _buildMetrics(isDark),
            const SizedBox(height: 24),
            _buildTrendChart(isDark),
            const SizedBox(height: 24),
            _buildExpenseBreakdown(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Financial Statement',
          style: GoogleFonts.figtree(
            color: PaceColors.getPrimaryText(isDark),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Consolidated revenue, operating costs, and profit margin',
          style: GoogleFonts.figtree(
            color: PaceColors.getDimText(isDark),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthNavigator(bool isDark) {
    final label = DateFormat('MMMM yyyy').format(_selectedDate);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: Icon(LucideIcons.chevronLeft, size: 18, color: PaceColors.getDimText(isDark)),
          ),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.figtree(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: PaceColors.getPrimaryText(isDark),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _changeMonth(1),
            icon: Icon(LucideIcons.chevronRight, size: 18, color: PaceColors.getDimText(isDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics(bool isDark) {
    final income = _report?['total_income'] ?? 0;
    final expenses = _report?['total_expenses'] ?? 0;
    final profit = _report?['net_profit'] ?? 0;
    final margin = _report?['margin'] ?? '0';

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricCard('Total Revenue', income, LucideIcons.trendingUp, PaceColors.emerald, isDark)),
            const SizedBox(width: 10),
            Expanded(child: _buildMetricCard('Total Expenses', expenses, LucideIcons.trendingDown, Colors.red.shade600, isDark)),
          ],
        ),
        const SizedBox(height: 10),
        _buildMetricCard(
          'Net Profit',
          profit,
          LucideIcons.wallet,
          PaceColors.purple,
          isDark,
          badgeLabel: 'Margin $margin%',
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, dynamic value, IconData icon, Color color, bool isDark, {String? badgeLabel}) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark)),
              ),
              if (badgeLabel != null)
                PaceBadge(label: badgeLabel, variant: BadgeVariant.primary)
              else
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 14),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'KES ${_currencyFormat.format(value)}',
            style: GoogleFonts.figtree(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: PaceColors.getPrimaryText(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(bool isDark) {
    final List<dynamic> trend = _report?['daily_trend'] ?? [];
    if (trend.isEmpty) return const SizedBox();

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
            'Daily Performance Trend',
            style: GoogleFonts.figtree(fontSize: 15, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: PaceColors.getBorder(isDark).withOpacity(0.5), strokeWidth: 1),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: trend.asMap().entries.map((e) {
                      final val = double.tryParse(e.value['income']?.toString() ?? '0') ?? 0;
                      return FlSpot(e.key.toDouble(), val);
                    }).toList(),
                    isCurved: true,
                    color: PaceColors.purple,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: PaceColors.purple.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseBreakdown(bool isDark) {
    final List<dynamic> categories = _report?['expense_categories'] ?? [];
    if (categories.isEmpty) return const SizedBox();

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
            'Expense Category Breakdown',
            style: GoogleFonts.figtree(fontSize: 15, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
          ),
          const SizedBox(height: 12),
          ...categories.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      c['category']?.toString().toUpperCase() ?? 'OTHER',
                      style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'KES ${_currencyFormat.format(c['amount'] ?? 0)}',
                      style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
