import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
  final _currencyFormat = NumberFormat("#,###", "en_US");
  
  Map<String, dynamic>? _incomeData;
  bool _isLoading = true;
  String _selectedTimeline = 'This Month';
  List<dynamic> _routers = [];
  String _activeRouterId = 'all';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getRouters(forceRefresh: true);
      if (res != null) {
        _routers = res['data'] ?? [];
        await _fetchIncome();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, String> _getDateRange() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd');
    switch (_selectedTimeline) {
      case 'Today':
        return {'startDate': formatter.format(now), 'endDate': formatter.format(now)};
      case 'Yesterday':
        final yest = now.subtract(const Duration(days: 1));
        return {'startDate': formatter.format(yest), 'endDate': formatter.format(yest)};
      case 'This Week':
        final startW = now.subtract(Duration(days: now.weekday - 1));
        return {'startDate': formatter.format(startW), 'endDate': formatter.format(now)};
      case 'This Month':
        final startM = DateTime(now.year, now.month, 1);
        return {'startDate': formatter.format(startM), 'endDate': formatter.format(now)};
      case 'All Time':
      default:
        return {'startDate': '', 'endDate': ''};
    }
  }

  Future<void> _fetchIncome() async {
    final dates = _getDateRange();
    final routerParam = _activeRouterId == 'all' ? '' : _activeRouterId;

    final res = await _apiService.getIncome(
      router: routerParam,
      startDate: dates['startDate'],
      endDate: dates['endDate'],
      forceRefresh: true,
    );
    final success = res?['status'] == 'success' || res?['status'] == 200 || res?['status'] == '200' || res?['success'] == true;
    if (mounted && success) {
      setState(() {
        _incomeData = res;
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

    return RefreshIndicator(
      onRefresh: () => _fetchIncome(),
      color: PaceColors.purple,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 24),
          _buildFilters(isDark),
          const SizedBox(height: 32),
          if (_isLoading && _incomeData == null)
            const SkeletonGrid(count: 6)
          else ...[
            _buildMetricsGrid(isDark),
            const SizedBox(height: 32),
            _buildTrendChart(isDark),
            const SizedBox(height: 32),
            _buildPlanDistribution(isDark),
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
            Text('REVENUE ANALYTICS', style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            Text('FINANCIAL PERFORMANCE & INSIGHTS', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ]),
        IconButton(
          onPressed: () {},
          icon: const Icon(LucideIcons.download, color: PaceColors.purple, size: 20),
        ),
      ],
    );
  }

  Widget _buildFilters(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _showTimelinePicker(isDark),
            child: _buildFilterChip(_selectedTimeline.toUpperCase(), LucideIcons.calendar, isDark),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () => _showRouterPicker(isDark),
            child: _buildFilterChip(_activeRouterId == 'all' ? 'ALL ROUTERS' : _routers.firstWhere((r)=>r['id'].toString()==_activeRouterId)['router_name'].toString().toUpperCase(), LucideIcons.router, isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: Row(children: [
        Icon(icon, size: 14, color: PaceColors.purple),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)), overflow: TextOverflow.ellipsis)),
        const Icon(LucideIcons.chevronDown, size: 12, color: Colors.grey),
      ]),
    );
  }

  void _showTimelinePicker(bool isDark) {
    final times = ['Today', 'Yesterday', 'This Week', 'This Month', 'All Time'];
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getBackground(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SELECT TIMELINE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: -0.5)),
                IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            ...times.map((t) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              trailing: _selectedTimeline == t ? const Icon(LucideIcons.check, color: PaceColors.purple) : null,
              onTap: () { setState(() => _selectedTimeline = t); Navigator.pop(context); _fetchIncome(); },
            )).toList(),
          ],
        ),
      ),
    );
  }

  void _showRouterPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getBackground(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SELECT ROUTER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: -0.5)),
                IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('ALL ROUTERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    trailing: _activeRouterId == 'all' ? const Icon(LucideIcons.check, color: PaceColors.purple) : null,
                    onTap: () { setState(() => _activeRouterId = 'all'); Navigator.pop(context); _fetchIncome(); },
                  ),
                  ..._routers.map((r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r['router_name'].toString().toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    trailing: _activeRouterId == r['id'].toString() ? const Icon(LucideIcons.check, color: PaceColors.purple) : null,
                    onTap: () { setState(() => _activeRouterId = r['id'].toString()); Navigator.pop(context); _fetchIncome(); },
                  )).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(bool isDark) {
    final m = _incomeData?['metrics'] ?? {};
    final cards = [
      {'l': 'TODAY', 'v': m['today']?['value'] ?? 0, 't': m['today']?['trend'] ?? 0, 'i': LucideIcons.wallet},
      {'l': 'THIS WEEK', 'v': m['week']?['value'] ?? 0, 't': m['week']?['trend'] ?? 0, 'i': LucideIcons.calendar},
      {'l': 'THIS MONTH', 'v': m['month']?['value'] ?? 0, 't': m['month']?['trend'] ?? 0, 'i': LucideIcons.trendingUp},
      {'l': 'YEAR TO DATE', 'v': m['year']?['value'] ?? 0, 't': m['year']?['trend'] ?? 0, 'i': LucideIcons.database},
      {'l': 'DAILY AVG', 'v': m['avg_daily'] ?? 0, 't': 0, 'i': LucideIcons.barChart3},
      {'l': 'MONTHLY AVG', 'v': m['avg_monthly'] ?? 0, 't': 0, 'i': LucideIcons.lineChart},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4),
      itemBuilder: (context, index) {
        final c = cards[index];
        final num trend = num.tryParse(c['t']?.toString() ?? '0') ?? 0;
        final num value = num.tryParse(c['v']?.toString() ?? '0') ?? 0;
        final bool up = trend >= 0;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Icon(c['i'] as IconData, size: 14, color: PaceColors.purple),
              if (trend != 0) Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: (up ? PaceColors.emerald : Colors.red).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Row(children: [
                  Icon(up ? LucideIcons.trendingUp : LucideIcons.trendingDown, size: 8, color: up ? PaceColors.emerald : Colors.red),
                  const SizedBox(width: 4),
                  Text('${up ? '+' : ''}$trend%', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: up ? PaceColors.emerald : Colors.red)),
                ]),
              ),
            ]),
            const Spacer(),
            Text(c['l'] as String, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
            Text('KES ${_currencyFormat.format(value)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark), letterSpacing: -0.5)),
          ]),
        );
      },
    );
  }

  Widget _buildTrendChart(bool isDark) {
    final List<dynamic> history = _incomeData?['charts']?['revenue_trend'] ?? [];
    if (history.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(28), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('INCOME TREND', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
        Text('DAILY REVENUE FOR SELECTED PERIOD', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        const SizedBox(height: 32),
        SizedBox(
          height: 200,
          child: LineChart(LineChartData(
             gridData: FlGridData(
               show: true,
               drawVerticalLine: false,
               horizontalInterval: history.isNotEmpty ? (history.map((e) => double.parse(e['amount'].toString())).reduce((a, b) => a > b ? a : b) / 4).clamp(1.0, double.infinity) : 1000,
               getDrawingHorizontalLine: (value) => FlLine(color: PaceColors.getBorder(isDark).withOpacity(0.5), strokeWidth: 1, dashArray: [4, 4]),
             ),
             titlesData: FlTitlesData(
               show: true,
               rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
               topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
               bottomTitles: AxisTitles(
                 sideTitles: SideTitles(
                   showTitles: true,
                   reservedSize: 24,
                   interval: 1,
                   getTitlesWidget: (value, meta) {
                     if (value.toInt() >= 0 && value.toInt() < history.length) {
                       final String dayStr = history[value.toInt()]['day']?.toString() ?? '';
                       // Try to show only a few labels if there are many days
                       if (history.length > 7 && value.toInt() % (history.length ~/ 5) != 0 && value.toInt() != history.length - 1) return const SizedBox();
                       return Padding(
                         padding: const EdgeInsets.only(top: 8.0),
                         child: Text(dayStr, style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold)),
                       );
                     }
                     return const SizedBox();
                   },
                 ),
               ),
               leftTitles: AxisTitles(
                 sideTitles: SideTitles(
                   showTitles: true,
                   reservedSize: 40,
                   getTitlesWidget: (value, meta) {
                     if (value == 0) return const SizedBox();
                     final str = value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0);
                     return Text(str, style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold));
                   },
                 ),
               ),
             ),
             borderData: FlBorderData(show: false),
             lineTouchData: LineTouchData(
               touchTooltipData: LineTouchTooltipData(
                 getTooltipColor: (touchedSpot) => PaceColors.getCard(isDark),
                 getTooltipItems: (touchedSpots) {
                   return touchedSpots.map((spot) {
                     return LineTooltipItem(
                       'KES ${_currencyFormat.format(spot.y)}',
                       TextStyle(color: PaceColors.getPrimaryText(isDark), fontWeight: FontWeight.bold, fontSize: 12),
                     );
                   }).toList();
                 },
               ),
             ),
             lineBarsData: [LineChartBarData(
               spots: history.map((e) => FlSpot(double.parse(history.indexOf(e).toString()), double.parse(e['amount'].toString()))).toList(),
               isCurved: true,
               color: PaceColors.purple,
               barWidth: 4,
               isStrokeCapRound: true,
               dotData: const FlDotData(show: false),
               belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [PaceColors.purple.withOpacity(0.15), PaceColors.purple.withOpacity(0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
             )],
          )),
        ),
      ]),
    );
  }

  Widget _buildPlanDistribution(bool isDark) {
    final List<dynamic> distro = _incomeData?['charts']?['plan_distribution'] ?? [];
    if (distro.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(28), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PLAN DISTRIBUTION', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
        Text('REVENUE CONTRIBUTION BY DATA CATEGORY', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        const SizedBox(height: 32),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: 200,
              child: AspectRatio(
                aspectRatio: 1,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 50,
                    sections: distro.map((item) {
                      final colorCode = item['color']?.toString().replaceAll('#', '0xFF') ?? '0xFF7C3AED';
                      final color = Color(int.parse(colorCode));
                      final value = double.tryParse(item['value']?.toString() ?? '0') ?? 0;
                      return PieChartSectionData(
                        color: color,
                        value: value,
                        title: '${value.toStringAsFixed(0)}%',
                        radius: 32,
                        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        showTitle: value > 5,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: distro.map((item) {
                final colorCode = item['color']?.toString().replaceAll('#', '0xFF') ?? '0xFF7C3AED';
                final color = Color(int.parse(colorCode));
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(item['name']?.toString().toUpperCase() ?? 'PLAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)), overflow: TextOverflow.ellipsis)),
                      Text('${item['value']}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
                    ],
                  ),
                );
              }).toList(),
            ),
            ],
          ),
      ]),
    );
  }
}
