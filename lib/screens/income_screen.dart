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

  Future<void> _fetchIncome() async {
    final res = await _apiService.fetchData(slug: 'income', params: {
      'router': _activeRouterId,
      'dateRange': _selectedTimeline
    });
    if (mounted && res?['status'] == 'success') {
      setState(() {
        _incomeData = res;
        _isLoading = false;
      });
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
            Text('REVENUE ANALYTICS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
            Text('FINANCIAL PERFORMANCE & INSIGHTS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
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
        Expanded(child: Text(label, style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark)), overflow: TextOverflow.ellipsis)),
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
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: times.map((t) => ListTile(
          title: Text(t.toUpperCase(), style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold)),
          trailing: _selectedTimeline == t ? const Icon(LucideIcons.check, color: PaceColors.purple) : null,
          onTap: () { setState(() => _selectedTimeline = t); Navigator.pop(context); _fetchIncome(); },
        )).toList()),
      ),
    );
  }

  void _showRouterPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getBackground(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: const Text('ALL ROUTERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onTap: () { setState(() => _activeRouterId = 'all'); Navigator.pop(context); _fetchIncome(); },
          ),
          ..._routers.map((r) => ListTile(
            title: Text(r['router_name'].toString().toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onTap: () { setState(() => _activeRouterId = r['id'].toString()); Navigator.pop(context); _fetchIncome(); },
          )).toList(),
        ])),
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
        final num trend = c['t'] as num;
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
            Text(c['l'] as String, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
            Text('KES ${_currencyFormat.format(c['v'])}', style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.normal, color: PaceColors.getPrimaryText(isDark), letterSpacing: -0.5)),
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
        Text('INCOME TREND', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w800, color: PaceColors.getPrimaryText(isDark))),
        Text('DAILY REVENUE FOR SELECTED PERIOD', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        const SizedBox(height: 32),
        SizedBox(
          height: 200,
          child: LineChart(LineChartData(
             gridData: const FlGridData(show: false),
             titlesData: const FlTitlesData(show: false),
             borderData: FlBorderData(show: false),
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
        Text('PLAN DISTRIBUTION', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w800, color: PaceColors.getPrimaryText(isDark))),
        Text('REVENUE CONTRIBUTION BY DATA CATEGORY', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        const SizedBox(height: 32),
        ...distro.map((item) {
          final colorCode = item['color']?.toString().replaceAll('#', '0xFF') ?? '0xFF7C3AED';
          final color = Color(int.parse(colorCode));
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              const SizedBox(width: 8),
              Expanded(child: Text(item['name'].toString().toUpperCase(), style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark)))),
              Text('${item['value']}%', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ]),
          );
        }).toList(),
      ]),
    );
  }
}
