import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/skeleton.dart';
import '../components/empty_state.dart';

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
        _routers = res['data'] ?? res['routers'] ?? [];
      }
      await _fetchIncome();
    } catch (_) {
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

    try {
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
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _fetchIncome(),
          color: PaceColors.purple,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 16),
              _buildFilters(isDark),
              const SizedBox(height: 20),
              if (_isLoading && _incomeData == null)
                const GridSkeleton(count: 6)
              else if (_incomeData == null)
                PaceEmptyState(
                  onRetry: _fetchIncome,
                  isDark: isDark,
                  title: 'Revenue Data Unavailable',
                  subtitle: 'Could not load your financial analytics. Please check your connection and retry.',
                )
              else ...[
                _buildMetricsGrid(isDark),
                const SizedBox(height: 24),
                _buildTrendChart(isDark),
                const SizedBox(height: 24),
                _buildPlanDistribution(isDark),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue Analytics',
              style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Financial performance & data distribution',
              style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        IconButton(
          onPressed: () => _fetchIncome(),
          icon: const Icon(LucideIcons.refreshCw, color: PaceColors.purple, size: 16),
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
            child: _buildFilterChip(_selectedTimeline, LucideIcons.calendar, isDark),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () => _showRouterPicker(isDark),
            child: _buildFilterChip(
              _activeRouterId == 'all'
                  ? 'All Mikrotiks'
                  : (_routers.firstWhere((r) => r['id'].toString() == _activeRouterId, orElse: () => {})['router_name'] ?? 'Selected'),
              LucideIcons.router,
              isDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: PaceColors.getDimText(isDark)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(LucideIcons.chevronDown, size: 12, color: Colors.grey),
        ],
      ),
    );
  }

  void _showTimelinePicker(bool isDark) {
    final times = ['Today', 'Yesterday', 'This Week', 'This Month', 'All Time'];
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text('Select Timeline', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w700, color: PaceColors.getPrimaryText(isDark))),
            ),
            const Divider(),
            ...times.map((t) => ListTile(
              dense: true,
              leading: Icon(LucideIcons.calendar, size: 16, color: _selectedTimeline == t ? PaceColors.purple : PaceColors.getDimText(isDark)),
              title: Text(t, style: GoogleFonts.figtree(fontSize: 13, fontWeight: _selectedTimeline == t ? FontWeight.w700 : FontWeight.w500, color: _selectedTimeline == t ? PaceColors.purple : PaceColors.getPrimaryText(isDark))),
              trailing: _selectedTimeline == t ? const Icon(LucideIcons.check, color: PaceColors.purple, size: 16) : null,
              onTap: () {
                setState(() => _selectedTimeline = t);
                Navigator.pop(context);
                _fetchIncome();
              },
            )).toList(),
          ],
        ),
      ),
    );
  }

  void _showRouterPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text('Select Mikrotik Station', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w700, color: PaceColors.getPrimaryText(isDark))),
            ),
            const Divider(),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    dense: true,
                    leading: Icon(LucideIcons.router, size: 16, color: _activeRouterId == 'all' ? PaceColors.purple : PaceColors.getDimText(isDark)),
                    title: Text('All Mikrotiks', style: GoogleFonts.figtree(fontSize: 13, fontWeight: _activeRouterId == 'all' ? FontWeight.w700 : FontWeight.w500, color: _activeRouterId == 'all' ? PaceColors.purple : PaceColors.getPrimaryText(isDark))),
                    trailing: _activeRouterId == 'all' ? const Icon(LucideIcons.check, color: PaceColors.purple, size: 16) : null,
                    onTap: () {
                      setState(() => _activeRouterId = 'all');
                      Navigator.pop(context);
                      _fetchIncome();
                    },
                  ),
                  ..._routers.map((r) {
                    final id = r['id'].toString();
                    final isSel = _activeRouterId == id;
                    return ListTile(
                      dense: true,
                      leading: Icon(LucideIcons.router, size: 16, color: isSel ? PaceColors.purple : PaceColors.getDimText(isDark)),
                      title: Text(r['router_name'] ?? 'Node', style: GoogleFonts.figtree(fontSize: 13, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? PaceColors.purple : PaceColors.getPrimaryText(isDark))),
                      trailing: isSel ? const Icon(LucideIcons.check, color: PaceColors.purple, size: 16) : null,
                      onTap: () {
                        setState(() => _activeRouterId = id);
                        Navigator.pop(context);
                        _fetchIncome();
                      },
                    );
                  }).toList(),
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
      {'l': 'Today', 'v': m['today']?['value'] ?? 0, 't': m['today']?['trend'] ?? 0, 'i': LucideIcons.wallet},
      {'l': 'This Week', 'v': m['week']?['value'] ?? 0, 't': m['week']?['trend'] ?? 0, 'i': LucideIcons.calendar},
      {'l': 'This Month', 'v': m['month']?['value'] ?? 0, 't': m['month']?['trend'] ?? 0, 'i': LucideIcons.trendingUp},
      {'l': 'Year to Date', 'v': m['year']?['value'] ?? 0, 't': m['year']?['trend'] ?? 0, 'i': LucideIcons.database},
      {'l': 'Daily Average', 'v': m['avg_daily'] ?? 0, 't': 0, 'i': LucideIcons.barChart2},
      {'l': 'Monthly Average', 'v': m['avg_monthly'] ?? 0, 't': 0, 'i': LucideIcons.activity},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.6,
      ),
      itemBuilder: (context, index) {
        final c = cards[index];
        final num trend = num.tryParse(c['t']?.toString() ?? '0') ?? 0;
        final num value = num.tryParse(c['v']?.toString() ?? '0') ?? 0;
        final bool up = trend >= 0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PaceColors.getCard(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PaceColors.getBorder(isDark)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: PaceColors.purple.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(c['i'] as IconData, size: 14, color: PaceColors.purple),
                  ),
                  if (trend != 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: (up ? PaceColors.green : PaceColors.red).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${up ? '+' : ''}$trend%',
                        style: GoogleFonts.figtree(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: up ? PaceColors.green : PaceColors.red,
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KES ${_currencyFormat.format(value)}',
                    style: GoogleFonts.figtree(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: PaceColors.purple,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c['l'] as String,
                    style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrendChart(bool isDark) {
    final List<dynamic> history = _incomeData?['charts']?['revenue_trend'] ?? [];
    if (history.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Income Trend', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w700, color: PaceColors.getPrimaryText(isDark))),
          Text('Daily revenue cycle', style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark))),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: PaceColors.getBorder(isDark).withOpacity(0.4), strokeWidth: 1, dashArray: [4, 4]),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: history.map((e) => FlSpot(double.parse(history.indexOf(e).toString()), double.parse(e['amount'].toString()))).toList(),
                    isCurved: true,
                    color: PaceColors.purple,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [PaceColors.purple.withOpacity(0.18), PaceColors.purple.withOpacity(0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
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

  Widget _buildPlanDistribution(bool isDark) {
    final List<dynamic> distro = _incomeData?['charts']?['plan_distribution'] ?? [];
    if (distro.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plan Distribution', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w700, color: PaceColors.getPrimaryText(isDark))),
          Text('Revenue contribution by data category', style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark))),
          const SizedBox(height: 16),
          Column(
            children: distro.map((item) {
              final colorCode = item['color']?.toString().replaceAll('#', '0xFF') ?? '0xFF7C3AED';
              final color = Color(int.parse(colorCode));
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item['name']?.toString() ?? 'Plan',
                        style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${item['value']}%', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w700, color: PaceColors.purple)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
