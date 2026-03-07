import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/skeleton.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _incomeData;
  bool _isLoading = true;
  String _selectedRouter = 'All Routers';
  String _selectedRange = 'This Month';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData({bool force = false}) async {
    if (!force) setState(() => _isLoading = true);
    final res = await _apiService.getIncome(router: _selectedRouter, forceRefresh: force);
    if (mounted) {
      setState(() {
        _incomeData = res?['data'] ?? res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Container(
      color: PaceColors.getBackground(isDark),
      child: _isLoading 
        ? _buildSkeletonBody(isDark)
        : RefreshIndicator(
            onRefresh: () => _fetchData(force: true),
            color: PaceColors.purple,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 24),
                  _buildMetricsGrid(isDark),
                  const SizedBox(height: 32),
                  _buildChartSection(isDark),
                  const SizedBox(height: 32),
                  _buildPlanDistribution(isDark),
                  const SizedBox(height: 32),
                  _buildTicketValueSection(isDark),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSkeletonBody(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PaceSkeleton(height: 40, width: 220),
          const SizedBox(height: 24),
          const SkeletonGrid(count: 6),
          const SizedBox(height: 24),
          const PaceSkeleton(height: 350, borderRadius: 20),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('REVENUE ANALYTICS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        Text('FINANCIAL PERFORMANCE & GROWTH INSIGHTS', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ],
    );
  }

  Widget _buildMetricsGrid(bool isDark) {
    final metrics = _incomeData?['metrics'];
    if (metrics == null) return const SizedBox();

    final cardData = [
      {'label': 'TODAY', 'value': metrics['today']?['value'] ?? 0, 'trend': metrics['today']?['trend'] ?? 0, 'icon': Icons.account_balance_wallet_rounded, 'color': PaceColors.purple},
      {'label': 'THIS WEEK', 'value': metrics['week']?['value'] ?? 0, 'trend': metrics['week']?['trend'] ?? 0, 'icon': Icons.calendar_month_rounded, 'color': PaceColors.sapphire},
      {'label': 'THIS MONTH', 'value': metrics['month']?['value'] ?? 0, 'trend': metrics['month']?['trend'] ?? 0, 'icon': Icons.trending_up_rounded, 'color': PaceColors.emerald},
      {'label': 'LAST MONTH', 'value': metrics['last_month']?['value'] ?? 0, 'trend': 0, 'icon': Icons.history_rounded, 'color': Colors.orange},
      {'label': 'THIS YEAR', 'value': metrics['year']?['value'] ?? 0, 'trend': metrics['year']?['trend'] ?? 0, 'icon': Icons.payments_rounded, 'color': Colors.teal},
      {'label': 'AVG DAILY', 'value': metrics['avg_daily'] ?? 0, 'trend': 0, 'icon': Icons.bar_chart_rounded, 'color': Colors.indigo},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: cardData.length,
      itemBuilder: (context, index) {
        final data = cardData[index];
        final bool isUp = (data['trend'] as num) >= 0;
        final color = data['color'] as Color;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PaceColors.getCard(isDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                    child: Icon(data['icon'] as IconData, color: color, size: 18),
                  ),
                  if (data['trend'] != 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: (isUp ? Colors.green : Colors.red).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        children: [
                          Icon(isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 10, color: isUp ? Colors.green : Colors.red),
                          const SizedBox(width: 2),
                          Text('${data['trend']}%', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: isUp ? Colors.green : Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(data['label'] as String, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
              Text('KSH ${_format(data['value'])}', style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartSection(bool isDark) {
    final trend = _incomeData?['charts']?['revenue_trend'] ?? [];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INCOME TREND', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 0.5)),
          Text('DAILY REVENUE FLOW LOGS', style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 32),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: PaceColors.getBorder(isDark), strokeWidth: 1)),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (val, meta) {
                    if (trend.isEmpty || val % (trend.length / 5).ceil() != 0) return const SizedBox();
                    final index = val.toInt();
                    if (index >= trend.length) return const SizedBox();
                    return Text(trend[index]['day']?.toString().substring(0, 3).toUpperCase() ?? '', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 8, fontWeight: FontWeight.w900));
                  })),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (val, meta) => Text(_format(val), style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 8, fontWeight: FontWeight.w900)))),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['amount'] ?? 0).toDouble())).toList(),
                    isCurved: true,
                    color: PaceColors.purple,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [PaceColors.purple.withOpacity(0.2), PaceColors.purple.withOpacity(0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanDistribution(bool isDark) {
    final dist = _incomeData?['charts']?['plan_distribution'] ?? [];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(24),
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
                  Text('PLAN DISTRIBUTION', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 0.5)),
                  Text('REVENUE SHARE BY TIER', style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ],
              ),
              const Icon(Icons.pie_chart_rounded, color: PaceColors.purple, size: 24),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 40,
                    sections: dist.map<PieChartSectionData>((item) => PieChartSectionData(
                      color: _parseColor(item['color']),
                      value: (item['value'] ?? 0).toDouble(),
                      title: '',
                      radius: 25,
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: dist.map<Widget>((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: _parseColor(item['color']), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item['name']?.toUpperCase() ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark)))),
                        Text('${item['value']}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: PaceColors.purple, fontFamily: 'monospace')),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTicketValueSection(bool isDark) {
    final trend = _incomeData?['charts']?['revenue_trend'] ?? [];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(24),
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
                  Text('TICKET VALUE', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 0.5)),
                  Text('AVG REVENUE PER TRANSACTION', style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ],
              ),
              const Icon(Icons.leaderboard_rounded, color: PaceColors.sapphire, size: 24),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) {
                    if (trend.isEmpty) return const SizedBox();
                    final index = val.toInt();
                    if (index >= trend.length || index % (trend.length / 5).ceil() != 0) return const SizedBox();
                    return Text(trend[index]['day']?.toString().substring(0, 3).toUpperCase() ?? '', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 8, fontWeight: FontWeight.w900));
                  })),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: trend.asMap().entries.map((e) {
                  final amount = (e.value['amount'] ?? 0).toDouble();
                  final entries = (e.value['entries'] ?? 1).toDouble();
                  final avg = amount / (entries == 0 ? 1 : entries);
                  return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: avg, color: PaceColors.sapphire, width: 12, borderRadius: BorderRadius.circular(4))]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _format(dynamic val) {
    if (val == null) return "0";
    final num n = val is num ? val : num.tryParse(val.toString()) ?? 0;
    if (n >= 1000) return "${(n / 1000).toStringAsFixed(1)}K";
    return n.toStringAsFixed(0);
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null) return PaceColors.purple;
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (e) {
      return PaceColors.purple;
    }
  }
}
