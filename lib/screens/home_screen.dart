import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/dashboard_chart.dart';
import '../components/skeleton.dart';
import '../components/badge.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onGenerateVoucher;
  const HomeScreen({super.key, this.onGenerateVoucher});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _widgets;
  List<dynamic> _charts = [];
  List<dynamic> _transactions = [];
  List<dynamic> _routerNames = ['All Routers'];
  List<dynamic> _routerStatus = [];
  
  String _selectedRouter = 'All Routers';
  String _selectedDateRange = 'Today';
  
  bool _isLoading = true;
  bool _isRevenueBlurred = true;
  final _currencyFormat = NumberFormat("#,###", "en_US");

  @override
  void initState() {
    super.initState();
    _fetchCachedThenLive();
    _loadInitialFilters();
  }

  Future<void> _loadInitialFilters() async {
    try {
      final res = await _apiService.getRouters(forceRefresh: true);
      if (res != null) {
        debugPrint("API: Routers Response received: ${res.keys}");
        final List<dynamic> fetched = _extractData(res, 'routers') ?? [];
        debugPrint("API: Fetched ${fetched.length} routers");
        if (mounted) {
          setState(() {
            _routerNames = ['All Routers', ...fetched.map((r) => r['name']?.toString() ?? r['router_name']?.toString() ?? r.toString())];
          });
        }
      } else {
        debugPrint("API: Routers Response was NULL");
      }
    } catch (e) {
      debugPrint("API: Failed to load routers: $e");
    }
  }

  Map<String, String> _parseDateRange(String range) {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd');
    
    String start = formatter.format(now);
    String end = formatter.format(now);

    if (range == 'Yesterday') {
      final yest = now.subtract(const Duration(days: 1));
      start = formatter.format(yest);
      end = formatter.format(yest);
    } else if (range == 'This Week') {
      final lastWeek = now.subtract(const Duration(days: 6));
      start = formatter.format(lastWeek);
    } else if (range == 'This Month') {
      final firstDay = DateTime(now.year, now.month, 1);
      start = formatter.format(firstDay);
    } else if (range == 'All Time') {
      start = '2020-01-01'; // Default far start
    }

    return {'startDate': start, 'endDate': end};
  }

  Future<void> _fetchCachedThenLive() async {
    final filters = _parseDateRange(_selectedDateRange);
    final router = _selectedRouter == 'All Routers' ? null : _selectedRouter;

    // 1. SILENT CACHE LOAD
    final cached = await Future.wait([
      _apiService.getSummaryWidgets(router: router, startDate: filters['startDate'], endDate: filters['endDate'], forceRefresh: false),
      _apiService.getSummaryCharts(router: router, startDate: filters['startDate'], endDate: filters['endDate'], forceRefresh: false),
      _apiService.getRecentTransactions(router: router, startDate: filters['startDate'], endDate: filters['endDate'], limit: 5, forceRefresh: false),
      _apiService.getRouterStatus(limit: 4, forceRefresh: false),
    ]);

    if (mounted) {
      setState(() {
        _widgets = _extractData(cached[0], 'widgets');
        _charts = cached[1]?['data']?['charts']?['revenue_over_time'] ?? cached[1]?['charts']?['revenue_over_time'] ?? cached[1]?['data']?['revenue_over_time'] ?? [];
        _transactions = _extractData(cached[2], 'recent_transactions') ?? [];
        _routerStatus = _extractData(cached[3], 'router_status') ?? [];
        if (_widgets != null) _isLoading = false;
      });
    }

    // 2. SILENT LIVE LOAD
    final live = await Future.wait([
      _apiService.getSummaryWidgets(router: router, startDate: filters['startDate'], endDate: filters['endDate'], forceRefresh: true),
      _apiService.getSummaryCharts(router: router, startDate: filters['startDate'], endDate: filters['endDate'], forceRefresh: true),
      _apiService.getRecentTransactions(router: router, startDate: filters['startDate'], endDate: filters['endDate'], limit: 5, forceRefresh: true),
      _apiService.getRouterStatus(limit: 4, forceRefresh: true),
    ]);

    if (mounted) {
      setState(() {
        _widgets = _extractData(live[0], 'widgets');
        _charts = live[1]?['data']?['charts']?['revenue_over_time'] ?? live[1]?['charts']?['revenue_over_time'] ?? live[1]?['data']?['revenue_over_time'] ?? [];
        _transactions = _extractData(live[2], 'recent_transactions') ?? [];
        _routerStatus = _extractData(live[3], 'router_status') ?? [];
        _isLoading = false;
      });
    }
  }

  dynamic _extractData(Map<String, dynamic>? res, String key) {
    if (res == null) return null;
    return res['data']?[key] ?? res[key] ?? res['data'];
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
            _buildMetricsGrid(isDark),
            const SizedBox(height: 40),
            _buildQuickAccessGrid(isDark),
            const SizedBox(height: 40),
            _buildChartCard(isDark),
            const SizedBox(height: 40),
            _buildRecentActivity(isDark),
            const SizedBox(height: 40),
            _buildRouterHealthList(isDark),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DASHBOARD', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 20, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
        Text('PERFORMANCE SUMMARY', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
      ],
    );
  }

  Widget _buildGlobalFilters(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildFilterButton(
            icon: Icons.router_rounded,
            label: _selectedRouter,
            onTap: () => _showRouterPicker(isDark),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFilterButton(
            icon: Icons.calendar_today_rounded,
            label: _selectedDateRange,
            onTap: () => _showDatePicker(isDark),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton({required IconData icon, required String label, required VoidCallback onTap, required bool isDark}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: PaceColors.getDimText(isDark)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: PaceColors.getDimText(isDark)),
          ],
        ),
      ),
    );
  }

  void _showRouterPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text('SELECT STATION NODE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 2)),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _routerNames.length,
                itemBuilder: (context, index) {
                  final r = _routerNames[index];
                  final isSelected = _selectedRouter == r;
                  return ListActionTile(
                    label: r,
                    icon: Icons.router_outlined,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() => _selectedRouter = r);
                      Navigator.pop(context);
                      _fetchCachedThenLive();
                    },
                    isDark: isDark,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDatePicker(bool isDark) {
    final ranges = ['All Time', 'Today', 'Yesterday', 'This Week', 'This Month'];
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text('SELECT PERFORMANCE CYCLE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 2)),
            ),
            const SizedBox(height: 8),
            ...ranges.map((range) {
              final isSelected = _selectedDateRange == range;
              return ListActionTile(
                label: range,
                icon: Icons.access_time_rounded,
                isSelected: isSelected,
                onTap: () {
                  setState(() => _selectedDateRange = range);
                  Navigator.pop(context);
                  _fetchCachedThenLive();
                },
                isDark: isDark,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(bool isDark) {
    if (_isLoading && _widgets == null) return const SkeletonGrid(count: 6);
    final data = _widgets;
    if (data == null) return const SizedBox();

    final metrics = [
      {'label': "TODAY'S EARNINGS", 'value': "KSH ${_format(data['todays_earnings']?['value'])}", 'icon': Icons.account_balance_wallet_rounded, 'color': PaceColors.purple, 'bg': PaceColors.purple.withOpacity(0.08), 'blur': false},
      {'label': "MONTH REVENUE", 'value': "KSH ${_format(data['month_revenue']?['value'])}", 'icon': Icons.credit_card_rounded, 'color': const Color(0xFF3B82F6), 'bg': const Color(0xFF3B82F6).withOpacity(0.08), 'blur': true},
      {'label': "ENTRIES", 'value': "${data['active_users']?['value'] ?? 0}", 'icon': Icons.bolt_rounded, 'color': const Color(0xFF22C55E), 'bg': const Color(0xFF22C55E).withOpacity(0.08), 'blur': false},
      {'label': "MONTH CUSTOMERS", 'value': "${data['customers_month']?['value'] ?? 0}", 'icon': Icons.people_rounded, 'color': PaceColors.getDimText(isDark), 'bg': PaceColors.getSurface(isDark), 'blur': false},
      {'label': "ONLINE USERS", 'value': "${data['online_customers']?['value'] ?? 0}", 'icon': Icons.wifi_rounded, 'color': const Color(0xFF10B981), 'bg': const Color(0xFF10B981).withOpacity(0.08), 'blur': false},
      {'label': "SYSTEM HEALTH", 'value': "${data['system_health']?['value'] ?? '98%'}", 'icon': Icons.lan_rounded, 'color': const Color(0xFFF59E0B), 'bg': const Color(0xFFF59E0B).withOpacity(0.08), 'blur': false},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final m = metrics[index];
        final bool blurIt = m['blur'] as bool && _isRevenueBlurred;
        return InkWell(
          onTap: m['blur'] as bool ? () => setState(() => _isRevenueBlurred = !_isRevenueBlurred) : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: m['bg'] as Color, borderRadius: BorderRadius.circular(10)), child: Icon(m['icon'] as IconData, color: m['color'] as Color, size: 16)),
                const Spacer(),
                if (blurIt)
                  ClipRect(child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), child: Text("KSH 88,888", style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.normal, color: PaceColors.getPrimaryText(isDark), letterSpacing: -0.5))))
                else
                  Text(m['value'] as String, style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.normal, color: PaceColors.purple, letterSpacing: -0.5)),
                const SizedBox(height: 2),
                Text(m['label'] as String, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickAccessGrid(bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _buildActionItem(Icons.confirmation_num_rounded, 'GENERATE ASSETS', 'Prepaid production', PaceColors.purple, isDark, widget.onGenerateVoucher),
        _buildActionItem(Icons.tag_rounded, 'ACTIVE PLANS', 'Bandwidth tiers', Colors.blue, isDark, () {}),
        _buildActionItem(Icons.lan_rounded, 'STATION NODE', 'Hardware portal', Colors.orange, isDark, () {}),
        _buildActionItem(Icons.analytics_rounded, 'SMART LOGGER', 'Internal events', PaceColors.getDimText(isDark), isDark, () {}),
      ],
    );
  }

  Widget _buildActionItem(IconData icon, String title, String sub, Color color, bool isDark, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(title, style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark), letterSpacing: -0.2)),
              Text(sub, style: GoogleFonts.figtree(fontSize: 7, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
            ])),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ACTIVITY & GROWTH', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.purple)),
                Text('NETWORK UTILIZATION TRENDS', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ]),
              Row(children: [_buildLegend(PaceColors.purple, 'REVENUE'), const SizedBox(width: 12), _buildLegend(const Color(0xFF22C55E), 'ACTIVITY')]),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(height: 200, child: DashboardChart(chartData: _charts)),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) => Row(children: [Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 4), Text(label, style: GoogleFonts.figtree(fontSize: 7, fontWeight: FontWeight.bold, color: PaceColors.getDimText(true), letterSpacing: 1))]);

  Widget _buildRecentActivity(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('RECENT ACTIVITY', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
      const SizedBox(height: 16),
      Container(
        decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
        child: _transactions.isEmpty
          ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('NO TRANSACTIONS DISCOVERED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))))
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transactions.length,
              separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
              itemBuilder: (context, index) {
                final tx = _transactions[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.smartphone_rounded, color: PaceColors.purple, size: 14)),
                  title: Text(tx['user_phone'] ?? 'SYSTEM', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                  subtitle: Row(children: [Text(tx['plan_name']?.toString().split('_')[0].toUpperCase() ?? 'PREPAID', style: GoogleFonts.figtree(fontSize: 7, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))), const SizedBox(width: 8), Icon(Icons.access_time_rounded, size: 8, color: PaceColors.getDimText(isDark)), const SizedBox(width: 2), Text(tx['time_ago'] ?? 'Now', style: GoogleFonts.figtree(fontSize: 7, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold))]),
                  trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('KES ${_format(tx['amount'])}', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.purple)),
                    const SizedBox(height: 2),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(4)), child: Text(tx['mpesa_code'] ?? 'PENDING', style: GoogleFonts.jetBrainsMono(fontSize: 7, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark)))),
                  ]),
                );
              },
            ),
      ),
    ]);
  }

  Widget _buildRouterHealthList(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('NETWORK STATIONS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
      const SizedBox(height: 16),
      Container(
        decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
        child: _routerStatus.isEmpty
          ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('NO STATIONS ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))))
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _routerStatus.length,
              separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
              itemBuilder: (context, index) {
                final r = _routerStatus[index];
                bool isOnline = r['status']?.toString().toLowerCase() == 'up' || r['status']?.toString().toLowerCase() == 'online';
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.router_rounded, color: PaceColors.purple, size: 14)),
                  title: Text(r['name']?.toUpperCase() ?? 'ROUTER', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                  subtitle: Text(r['ip'] ?? '0.0.0.0', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: PaceColors.getDimText(isDark))),
                  trailing: PaceBadge(label: isOnline ? 'ONLINE' : 'OFFLINE', variant: isOnline ? BadgeVariant.success : BadgeVariant.error),
                );
              },
            ),
      ),
    ]);
  }

  String _format(dynamic val) {
    if (val == null) return "0";
    try {
      final double n = double.parse(val.toString());
      return _currencyFormat.format(n.toInt());
    } catch (e) { return val.toString(); }
  }
}

class ListActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  const ListActionTile({super.key, required this.label, required this.icon, required this.isSelected, required this.onTap, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: ListTile(onTap: onTap, dense: true, selected: isSelected, selectedTileColor: PaceColors.purple.withOpacity(0.08), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), leading: Icon(icon, size: 18, color: isSelected ? PaceColors.purple : PaceColors.getDimText(isDark)), title: Text(label, style: GoogleFonts.figtree(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? PaceColors.purple : PaceColors.getPrimaryText(isDark))), trailing: isSelected ? const Icon(Icons.check_circle_rounded, size: 18, color: PaceColors.purple) : null));
  }
}
