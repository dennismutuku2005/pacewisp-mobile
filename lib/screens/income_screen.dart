import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
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
  List<dynamic> _routerNames = ['All Routers'];
  
  bool _isLoading = true;
  String _selectedRouter = 'All Routers';
  String _selectedDateRange = 'This Month';
  final _currencyFormat = NumberFormat("#,###", "en_US");

  @override
  void initState() {
    super.initState();
    _fetchCachedThenLive();
    _loadRouters();
  }

  Future<void> _loadRouters() async {
    final res = await _apiService.getRouters(forceRefresh: true);
    if (res != null) {
      final dynamic raw = res['data'] ?? res['routers'];
      if (raw is List) {
        final Set<String> unique = {'All Routers'};
        for (var r in raw) {
          String? name = (r is Map) ? (r['name'] ?? r['router_name'] ?? r['router'])?.toString() : r.toString();
          if (name != null && name.isNotEmpty) unique.add(name);
        }
        if (mounted) setState(() => _routerNames = unique.toList());
      }
    }
  }

  Map<String, String> _parseDateRange(String range) {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd');
    String start = formatter.format(now), end = formatter.format(now);
    if (range == 'Yesterday') { final yest = now.subtract(const Duration(days: 1)); start = formatter.format(yest); end = formatter.format(yest); }
    else if (range == 'This Week') { start = formatter.format(now.subtract(const Duration(days: 6))); }
    else if (range == 'This Month') { start = formatter.format(DateTime(now.year, now.month, 1)); }
    else if (range == 'All Time') { start = '2020-01-01'; }
    return {'startDate': start, 'endDate': end};
  }

  Future<void> _fetchCachedThenLive() async {
    final filters = _parseDateRange(_selectedDateRange);
    final router = _selectedRouter == 'All Routers' ? null : _selectedRouter;

    // 1. SILENT CACHE LOAD
    final cached = await _apiService.getIncome(router: router, startDate: filters['startDate'], endDate: filters['endDate'], forceRefresh: false);
    if (mounted && cached != null) {
      setState(() {
        _incomeData = cached['data'] ?? cached;
        _isLoading = false;
      });
    }

    // 2. LIVE REFRESH
    final live = await _apiService.getIncome(router: router, startDate: filters['startDate'], endDate: filters['endDate'], forceRefresh: true);
    if (mounted && live != null) {
      setState(() {
        _incomeData = live['data'] ?? live;
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
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 24),
            _buildGlobalFilters(isDark),
            const SizedBox(height: 32),
            if (_isLoading && _incomeData == null) 
               const SkeletonGrid(count: 9)
            else ...[
              _buildMetricsGrid(isDark),
              const SizedBox(height: 32),
              _buildChartCard(isDark),
              const SizedBox(height: 32),
              _buildPlanDistribution(isDark),
              const SizedBox(height: 32),
              _buildTicketValue(isDark),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('REVENUE ANALYTICS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
      Text('FINANCIAL PERFORMANCE & GROWTH INSIGHTS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
    ]);
  }

  Widget _buildGlobalFilters(bool isDark) {
    return Row(children: [
      Expanded(child: _buildFilterButton(icon: Icons.router_rounded, label: _selectedRouter, onTap: () => _showRouterPicker(isDark), isDark: isDark)),
      const SizedBox(width: 12),
      Expanded(child: _buildFilterButton(icon: Icons.calendar_today_rounded, label: _selectedDateRange, onTap: () => _showDatePicker(isDark), isDark: isDark)),
    ]);
  }

  Widget _buildFilterButton({required IconData icon, required String label, required VoidCallback onTap, required bool isDark}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))]),
        child: Row(children: [Icon(icon, size: 16, color: PaceColors.getDimText(isDark)), const SizedBox(width: 10), Expanded(child: Text(label, style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark)), overflow: TextOverflow.ellipsis)), Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: PaceColors.getDimText(isDark))]),
      ),
    );
  }

  void _showRouterPicker(bool isDark) {
    showModalBottomSheet(context: context, backgroundColor: PaceColors.getCard(isDark), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))), builder: (context) => Container(padding: const EdgeInsets.symmetric(vertical: 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Text('SELECT STATION NODE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 2))), const SizedBox(height: 8), Flexible(child: ListView.builder(shrinkWrap: true, itemCount: _routerNames.length, itemBuilder: (context, index) { final r = _routerNames[index]; final isSelected = _selectedRouter == r; return _buildListTile(label: r, icon: Icons.router_outlined, isSelected: isSelected, isDark: isDark, onTap: () { setState(() => _selectedRouter = r); Navigator.pop(context); _fetchCachedThenLive(); }); }))])));
  }

  void _showDatePicker(bool isDark) {
    final ranges = ['All Time', 'Today', 'Yesterday', 'This Week', 'This Month'];
    showModalBottomSheet(context: context, backgroundColor: PaceColors.getCard(isDark), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))), builder: (context) => Container(padding: const EdgeInsets.symmetric(vertical: 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Text('SELECT PERFORMANCE CYCLE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 2))), const SizedBox(height: 8), ...ranges.map((range) { final isSelected = _selectedDateRange == range; return _buildListTile(label: range, icon: Icons.access_time_rounded, isSelected: isSelected, isDark: isDark, onTap: () { setState(() => _selectedDateRange = range); Navigator.pop(context); _fetchCachedThenLive(); }); }).toList()])));
  }

  Widget _buildListTile({required String label, required IconData icon, required bool isSelected, required bool isDark, required VoidCallback onTap}) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: ListTile(onTap: onTap, dense: true, selected: isSelected, selectedTileColor: PaceColors.purple.withOpacity(0.08), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), leading: Icon(icon, size: 18, color: isSelected ? PaceColors.purple : PaceColors.getDimText(isDark)), title: Text(label, style: GoogleFonts.figtree(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? PaceColors.purple : PaceColors.getPrimaryText(isDark))), trailing: isSelected ? const Icon(Icons.check_circle_rounded, size: 18, color: PaceColors.purple) : null));
  }

  Widget _buildMetricsGrid(bool isDark) {
    final m = _incomeData?['metrics'];
    if (m == null) return const SizedBox();

    final cardData = [
      {'label': "TODAY", 'value': m['today']?['value'] ?? 0, 'trend': m['today']?['trend'] ?? 0, 'icon': Icons.account_balance_wallet_rounded, 'color': PaceColors.purple},
      {'label': "THIS WEEK", 'value': m['week']?['value'] ?? 0, 'trend': m['week']?['trend'] ?? 0, 'icon': Icons.calendar_today_rounded, 'color': Colors.blue},
      {'label': "THIS MONTH", 'value': m['month']?['value'] ?? 0, 'trend': m['month']?['trend'] ?? 0, 'icon': Icons.trending_up_rounded, 'color': Colors.green},
      {'label': "LAST MONTH", 'value': m['last_month']?['value'] ?? 0, 'trend': 0, 'icon': Icons.history_rounded, 'color': Colors.orange},
      {'label': "THIS YEAR", 'value': m['year']?['value'] ?? 0, 'trend': m['year']?['trend'] ?? 0, 'icon': Icons.payments_rounded, 'color': Colors.teal},
      {'label': "LAST YEAR", 'value': m['last_year']?['value'] ?? 0, 'trend': 0, 'icon': Icons.arrow_downward_rounded, 'color': Colors.grey},
      {'label': "AVG DAILY", 'value': m['avg_daily'] ?? 0, 'trend': 0, 'icon': Icons.bar_chart_rounded, 'color': Colors.indigo},
      {'label': "AVG WEEKLY", 'value': m['avg_weekly'] ?? 0, 'trend': 0, 'icon': Icons.layers_rounded, 'color': Colors.pink},
      {'label': "AVG MONTHLY", 'value': m['avg_monthly'] ?? 0, 'trend': 0, 'icon': Icons.show_chart_rounded, 'color': Colors.deepPurple},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4),
      itemCount: cardData.length,
      itemBuilder: (context, index) {
        final d = cardData[index];
        final color = d['color'] as Color;
        final trendNum = d['trend'] as num;
        final bool isUp = trendNum >= 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
             Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
               Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(d['icon'] as IconData, color: color, size: 16)),
               if (trendNum != 0) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: (isUp ? Colors.green : Colors.red).withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text('${isUp ? '+' : ''}$trendNum%', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: isUp ? Colors.green : Colors.red))),
             ]),
             const Spacer(),
             Text(d['label'] as String, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
             Text('KSH ${_format(d['value'])}', style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.normal, color: PaceColors.getPrimaryText(isDark), letterSpacing: -0.5)),
          ]),
        );
      },
    );
  }

  Widget _buildChartCard(bool isDark) {
    final trend = _incomeData?['charts']?['revenue_trend'] ?? [];
    if (trend.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('INCOME TREND', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w800, color: PaceColors.purple)),
        Text('DAILY REVENUE FLOW LOGS', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 32),
        SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: _getInterval(trend), getDrawingHorizontalLine: (val) => FlLine(color: PaceColors.getBorder(isDark), strokeWidth: 1, dashArray: [4, 4])),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, m) {
                   int i = v.toInt();
                   if (i >= 0 && i < trend.length && i % (trend.length > 10 ? 3 : 1) == 0) {
                      return Text(trend[i]['day']?.toString().substring(0, 3).toUpperCase() ?? '', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 8, fontWeight: FontWeight.w900));
                   }
                   return const SizedBox();
                })),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45, getTitlesWidget: (v, m) {
                   if (v == 0) return const SizedBox();
                   return Text(v >= 1000 ? '${(v/1000).toStringAsFixed(0)}k' : v.toInt().toString(), style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 8, fontWeight: FontWeight.w900));
                })),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: trend.asMap().entries.map<FlSpot>((e) => FlSpot(e.key.toDouble(), double.tryParse(e.value['amount'].toString()) ?? 0)).toList(),
                  isCurved: true,
                  color: PaceColors.purple,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [PaceColors.purple.withOpacity(0.15), PaceColors.purple.withOpacity(0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildPlanDistribution(bool isDark) {
    final dist = _incomeData?['charts']?['plan_distribution'] ?? [];
    if (dist.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         Text('PLAN DISTRIBUTION', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w800, color: PaceColors.purple)),
         Text('REVENUE SHARE BY TIER', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
         const SizedBox(height: 32),
         Row(children: [
           SizedBox(width: 140, height: 140, child: PieChart(PieChartData(sectionsSpace: 4, centerSpaceRadius: 35, sections: dist.map<PieChartSectionData>((it) => PieChartSectionData(color: _parseColor(it['color']), value: double.tryParse(it['value'].toString()) ?? 0, title: '', radius: 20)).toList()))),
           const SizedBox(width: 24),
           Expanded(child: Column(children: dist.map<Widget>((it) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: _parseColor(it['color']), shape: BoxShape.circle)), const SizedBox(width: 8), Expanded(child: Text(it['name']?.toString().toUpperCase() ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark)), overflow: TextOverflow.ellipsis)), Text('${it['value']}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: PaceColors.purple))]))).toList())),
         ]),
      ]),
    );
  }

  Widget _buildTicketValue(bool isDark) {
    final trend = _incomeData?['charts']?['revenue_trend'] ?? [];
    if (trend.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         Text('TICKET VALUE', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w800, color: PaceColors.purple)),
         Text('AVG REVENUE PER TRANSACTION', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
         const SizedBox(height: 32),
         SizedBox(
           height: 200,
           child: BarChart(BarChartData(
             gridData: const FlGridData(show: false),
             titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
                   int i = v.toInt();
                   if (i >= 0 && i < trend.length && i % (trend.length > 10 ? 4 : 1) == 0) {
                      return Text(trend[i]['day']?.toString().substring(0, 3).toUpperCase() ?? '', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 8, fontWeight: FontWeight.w900));
                   }
                   return const SizedBox();
                })),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
             ), 
             borderData: FlBorderData(show: false),
             barGroups: trend.asMap().entries.map<BarChartGroupData>((e) {
               double amt = double.tryParse(e.value['amount'].toString()) ?? 0;
               double ent = double.tryParse(e.value['entries'].toString()) ?? 0;
               double avg = ent == 0 ? 0 : amt / ent;
               return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: avg, color: Colors.blue, width: 12, borderRadius: BorderRadius.circular(4))]);
             }).toList()
           ))),
      ]),
    );
  }

  double _getInterval(List<dynamic> trend) {
    double max = 0;
    for (var d in trend) {
      double v = double.tryParse(d['amount'].toString()) ?? 0;
      if (v > max) max = v;
    }
    if (max <= 0) return 1000;
    return (max / 4).clamp(1.0, double.infinity);
  }

  String _format(dynamic val) { if (val == null) return "0"; try { final double n = double.parse(val.toString()); return _currencyFormat.format(n.toInt()); } catch (e) { return val.toString(); } }
  
  Color _parseColor(dynamic c) {
    if (c == null) return PaceColors.purple;
    String s = c.toString();
    if (!s.startsWith('#')) return PaceColors.purple;
    try { return Color(int.parse(s.replaceFirst('#', '0xFF'))); } catch (e) { return PaceColors.purple; }
  }
}
