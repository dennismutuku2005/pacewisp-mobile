import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/dashboard_chart.dart';
import '../components/skeleton.dart';
import '../components/badge.dart';
import '../components/empty_state.dart';
import '../services/widget_service.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onGenerateVoucher;
  final VoidCallback? onNavigateToRouters;
  const HomeScreen({super.key, this.onGenerateVoucher, this.onNavigateToRouters});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final PageController _chartPageController = PageController();
  
  Map<String, dynamic>? _widgets;
  List<dynamic> _charts = [];
  List<dynamic> _transactions = [];
  List<dynamic> _routerNames = ['All Routers'];
  List<dynamic> _routerStatus = [];
  
  String _selectedRouter = 'All Routers';
  String _selectedDateRange = 'Today';
  int _currentChartIndex = 0;
  
  bool _isLoading = true;
  bool _isRevenueBlurred = true;
  final _currencyFormat = NumberFormat("#,###", "en_US");
  Timer? _widgetTimer;

  @override
  void initState() {
    super.initState();
    _loadRouters();
    _fetchLiveDashboard();
    _startWidgetTimer();
  }

  void _startWidgetTimer() {
    _widgetTimer?.cancel();
    _widgetTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _fetchLiveDashboard(isSilent: true);
    });
  }

  @override
  void dispose() {
    _widgetTimer?.cancel();
    _chartPageController.dispose();
    super.dispose();
  }

  Future<void> _loadRouters() async {
    try {
      final res = await _apiService.getRouters(forceRefresh: true);
      if (res != null) {
        final dynamic raw = res['data'] ?? res['routers'];
        List<dynamic> fetched = [];
        if (raw is List) fetched = raw;
        else if (raw is Map && raw['routers'] is List) fetched = raw['routers'];

        if (mounted) {
          setState(() {
            final Set<String> unique = {'All Routers'};
            for (var r in fetched) {
              String? name;
              if (r is String) name = r.trim();
              else if (r is Map) name = (r['name'] ?? r['router_name'] ?? r['router'])?.toString().trim();
              if (name != null && name.isNotEmpty) {
                final lower = name.toLowerCase();
                if (lower != 'all routers' && lower != 'all' && lower != 'any') unique.add(name);
              }
            }
            _routerNames = unique.toList();
          });
        }
      }
    } catch (e) {
      debugPrint("API: Failed to load routers: $e");
    }
  }

  Map<String, String> _parseDateRange(String range) {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd');
    String start = formatter.format(now), end = formatter.format(now);
    if (range == 'Yesterday') {
      final yest = now.subtract(const Duration(days: 1));
      start = formatter.format(yest);
      end = formatter.format(yest);
    } else if (range == 'This Week') {
      start = formatter.format(now.subtract(const Duration(days: 6)));
    } else if (range == 'This Month') {
      start = formatter.format(DateTime(now.year, now.month, 1));
    } else if (range == 'All Time') {
      start = '2020-01-01';
    }
    return {'startDate': start, 'endDate': end};
  }

  Future<void> _fetchLiveDashboard({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoading = true);
    final filters = _parseDateRange(_selectedDateRange);
    final router = _selectedRouter == 'All Routers' ? null : _selectedRouter;

    try {
      final live = await Future.wait<Map<String, dynamic>?>([
        _apiService.getSummaryWidgets(router: router, startDate: filters['startDate'], endDate: filters['endDate'], forceRefresh: true),
        _apiService.getSummaryCharts(router: router, startDate: filters['startDate'], endDate: filters['endDate'], forceRefresh: true),
        _apiService.getRecentTransactions(router: router, startDate: filters['startDate'], endDate: filters['endDate'], limit: 5, forceRefresh: true),
        _apiService.getRouterStatus(limit: 5, forceRefresh: true),
      ]);

      if (mounted) {
        setState(() {
          _widgets = _extractData(live[0], 'widgets');
          _charts = live[1]?['data']?['charts']?['revenue_over_time'] ??
              live[1]?['charts']?['revenue_over_time'] ??
              live[1]?['data']?['revenue_over_time'] ??
              [];
          _transactions = _extractData(live[2], 'recent_transactions', isList: true) ?? [];

          final fetchedRouters = _extractData(live[3], 'router_status', isList: true) ?? [];
          _routerStatus = fetchedRouters.map((r) => {...(r is Map ? r : {}), 'isPinging': false}).toList();
          _isLoading = false;
        });

        _refreshWidgetData();
      }
    } catch (e) {
      debugPrint("Error fetching dashboard data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pingDashboardRouter(int index) async {
    if (index >= _routerStatus.length) return;
    final r = _routerStatus[index];
    final ip = r['ip']?.toString().trim();
    if (ip == null || ip.isEmpty || ip == '0.0.0.0') {
      if (mounted && index < _routerStatus.length) {
        setState(() {
          _routerStatus[index] = {
            ..._routerStatus[index],
            'isPinging': false,
            'status': 'Offline',
            'uptime': 'Disconnected',
          };
        });
      }
      return;
    }

    setState(() {
      _routerStatus[index] = {
        ..._routerStatus[index],
        'isPinging': true,
      };
    });

    try {
      final res = await _apiService.pingRouter(ip, r['winbox_port'] ?? 8728);
      final stats = res?['data'] ?? res;
      final bool isOnline = stats?['status'] == 'online' || stats?['cpu'] != null || stats?['success'] == true;
      if (mounted && index < _routerStatus.length) {
        setState(() {
          _routerStatus[index] = {
            ..._routerStatus[index],
            'uptime': isOnline ? (stats?['uptime'] ?? 'Running') : 'Disconnected',
            'status': isOnline ? 'Online' : 'Offline',
            'isPinging': false
          };
        });
      }
    } catch (_) {
      if (mounted && index < _routerStatus.length) {
        setState(() {
          _routerStatus[index] = {
            ..._routerStatus[index],
            'isPinging': false,
            'status': 'Offline',
            'uptime': 'Disconnected'
          };
        });
      }
    }
  }

  void _refreshWidgetData() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final wAcc = settings.widgetAccount;
    final aAcc = settings.activeAccount;

    if (wAcc?.subdomain == aAcc?.subdomain && _widgets != null) {
      final income = _widgets!['todays_earnings']?['value'] ?? "0";
      final entries = _widgets!['active_users']?['value'] ?? "0";

      WidgetService.updateWidgetData(
        accountName: aAcc?.accountName ?? "PaceWISP Admin",
        income: income.toString(),
        entries: entries.toString(),
        isBlurred: settings.isWidgetBlurred,
      );
    }
  }

  dynamic _extractData(Map<String, dynamic>? res, String key, {bool isList = false}) {
    if (res == null || res['status'] == 'error') return isList ? [] : null;
    final dynamic data = res['data'];
    dynamic result;
    if (data is Map) result = data[key] ?? data;
    else result = res[key] ?? data;

    if (isList && result is! List) return [];
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;
    final canSeeIncome = settings.hasPolicy('view_income');

    return RefreshIndicator(
      onRefresh: () => _fetchLiveDashboard(),
      color: PaceColors.purple,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isDark, settings),
            const SizedBox(height: 16),
            _buildGlobalFilters(isDark),
            const SizedBox(height: 20),
            if (_isLoading && _widgets == null)
              const GridSkeleton(count: 6)
            else if (_widgets != null) ...[
              _buildMetricsGrid(isDark, canSeeIncome),
              const SizedBox(height: 24),
              _buildQuickAccessGrid(isDark),
              const SizedBox(height: 24),
              _buildSectionHeader('Revenue & Activity Trends', isDark, isChart: true),
              _buildChartCard(isDark),
              const SizedBox(height: 24),
              _buildSectionHeader('Recent Live Activity', isDark),
              _buildActivityTable(isDark),
              const SizedBox(height: 24),
              _buildSectionHeader('Your Mikrotik Nodes', isDark, isStation: true),
              _buildStationTable(isDark),
            ] else ...[
              PaceEmptyState(
                onRetry: () => _fetchLiveDashboard(),
                isDark: isDark,
                title: 'Dashboard Unavailable',
                subtitle: 'Could not fetch dashboard metrics. Pull down to refresh.',
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, SettingsProvider settings) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard',
              style: GoogleFonts.figtree(
                color: PaceColors.purple,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Performance Summary',
              style: GoogleFonts.figtree(
                color: PaceColors.getDimText(isDark),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (settings.hasPolicy('create_voucher'))
          ElevatedButton.icon(
            onPressed: widget.onGenerateVoucher,
            icon: const Icon(LucideIcons.plus, size: 14),
            label: Text(
              'New Voucher',
              style: GoogleFonts.figtree(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: PaceColors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
      ],
    );
  }

  Widget _buildGlobalFilters(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildFilterButton(
            icon: LucideIcons.router,
            label: _selectedRouter,
            onTap: () => _showRouterPicker(isDark),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildFilterButton(
            icon: LucideIcons.calendar,
            label: _selectedDateRange,
            onTap: () => _showDatePicker(isDark),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
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
                style: GoogleFonts.figtree(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PaceColors.getPrimaryText(isDark),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(LucideIcons.chevronDown, size: 14, color: PaceColors.getDimText(isDark)),
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
              child: Text(
                'Select Mikrotik Station',
                style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w700, color: PaceColors.getPrimaryText(isDark)),
              ),
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _routerNames.length,
                itemBuilder: (context, index) {
                  final r = _routerNames[index];
                  final isSelected = _selectedRouter == r;
                  return ListTile(
                    dense: true,
                    leading: Icon(LucideIcons.router, size: 16, color: isSelected ? PaceColors.purple : PaceColors.getDimText(isDark)),
                    title: Text(
                      r,
                      style: GoogleFonts.figtree(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? PaceColors.purple : PaceColors.getPrimaryText(isDark),
                      ),
                    ),
                    trailing: isSelected ? const Icon(LucideIcons.check, size: 16, color: PaceColors.purple) : null,
                    onTap: () {
                      setState(() => _selectedRouter = r);
                      Navigator.pop(context);
                      _fetchLiveDashboard();
                    },
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
    final ranges = ['Today', 'Yesterday', 'This Week', 'This Month', 'All Time'];
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
              child: Text(
                'Select Date Cycle',
                style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w700, color: PaceColors.getPrimaryText(isDark)),
              ),
            ),
            const Divider(),
            ...ranges.map((range) {
              final isSelected = _selectedDateRange == range;
              return ListTile(
                dense: true,
                leading: Icon(LucideIcons.calendar, size: 16, color: isSelected ? PaceColors.purple : PaceColors.getDimText(isDark)),
                title: Text(
                  range,
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? PaceColors.purple : PaceColors.getPrimaryText(isDark),
                  ),
                ),
                trailing: isSelected ? const Icon(LucideIcons.check, size: 16, color: PaceColors.purple) : null,
                onTap: () {
                  setState(() => _selectedDateRange = range);
                  Navigator.pop(context);
                  _fetchLiveDashboard();
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(bool isDark, bool canSeeIncome) {
    final data = _widgets ?? {};
    final metrics = canSeeIncome
        ? [
            {
              'label': "Today's Earnings",
              'value': "KSH ${_format(data['todays_earnings']?['value'])}",
              'note': 'Last 24 hours',
              'icon': LucideIcons.wallet,
              'color': PaceColors.purple,
              'bg': PaceColors.purple.withOpacity(0.08)
            },
            {
              'label': "Month Revenue",
              'value': "KSH ${_format(data['month_revenue']?['value'])}",
              'note': 'Current cycle',
              'icon': LucideIcons.creditCard,
              'color': const Color(0xFF3B82F6),
              'bg': const Color(0xFF3B82F6).withOpacity(0.08)
            },
            {
              'label': "Entries",
              'value': "${data['active_users']?['value'] ?? 0}",
              'note': 'Today entries',
              'icon': LucideIcons.activity,
              'color': PaceColors.green,
              'bg': PaceColors.green.withOpacity(0.08)
            },
            {
              'label': "Avg Entries",
              'value': "${data['customers_month']?['value'] ?? 0}",
              'note': 'Daily average',
              'icon': LucideIcons.barChart2,
              'color': PaceColors.getDimText(isDark),
              'bg': PaceColors.getSurface(isDark)
            },
            {
              'label': "Online Customers",
              'value': "${data['online_customers']?['value'] ?? 0}",
              'note': 'Live now',
              'icon': LucideIcons.wifi,
              'color': const Color(0xFF10B981),
              'bg': const Color(0xFF10B981).withOpacity(0.08)
            },
            {
              'label': "Total Users",
              'value': "${data['monthly_users']?['value'] ?? 0}",
              'note': 'Network scale',
              'icon': LucideIcons.network,
              'color': const Color(0xFFF59E0B),
              'bg': const Color(0xFFF59E0B).withOpacity(0.08)
            },
          ]
        : [
            {
              'label': "Live Entries",
              'value': "${data['active_users']?['value'] ?? 0}",
              'note': 'Today entries',
              'icon': LucideIcons.activity,
              'color': PaceColors.green,
              'bg': PaceColors.green.withOpacity(0.08)
            },
            {
              'label': "Online Customers",
              'value': "${data['online_customers']?['value'] ?? 0}",
              'note': 'Live now',
              'icon': LucideIcons.wifi,
              'color': const Color(0xFF10B981),
              'bg': const Color(0xFF10B981).withOpacity(0.08)
            },
            {
              'label': "Total Users",
              'value': "${data['monthly_users']?['value'] ?? 0}",
              'note': 'Network scale',
              'icon': LucideIcons.network,
              'color': const Color(0xFFF59E0B),
              'bg': const Color(0xFFF59E0B).withOpacity(0.08)
            },
            {
              'label': "Avg Entries",
              'value': "${data['customers_month']?['value'] ?? 0}",
              'note': 'Daily average',
              'icon': LucideIcons.barChart2,
              'color': PaceColors.getDimText(isDark),
              'bg': PaceColors.getSurface(isDark)
            },
          ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.6,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final m = metrics[index];
        final bool isRevenue = m['label'] == "Month Revenue";
        final bool blurIt = isRevenue && _isRevenueBlurred;

        return InkWell(
          onTap: isRevenue ? () => setState(() => _isRevenueBlurred = !_isRevenueBlurred) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
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
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: m['bg'] as Color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(m['icon'] as IconData, color: m['color'] as Color, size: 14),
                    ),
                    if (isRevenue)
                      Icon(
                        _isRevenueBlurred ? LucideIcons.eyeOff : LucideIcons.eye,
                        size: 14,
                        color: PaceColors.getDimText(isDark),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (blurIt)
                      ClipRect(
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Text(
                            "KSH 88,888",
                            style: GoogleFonts.figtree(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: PaceColors.getPrimaryText(isDark),
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        m['value'] as String,
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
                      m['label'] as String,
                      style: GoogleFonts.figtree(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: PaceColors.getDimText(isDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickAccessGrid(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionItem(
            icon: LucideIcons.ticket,
            title: 'Vouchers',
            subtitle: 'Prepaid codes',
            color: PaceColors.purple,
            isDark: isDark,
            onTap: widget.onGenerateVoucher,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickActionItem(
            icon: LucideIcons.router,
            title: 'Mikrotiks',
            subtitle: 'Router health',
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            onTap: widget.onNavigateToRouters,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PaceColors.getBorder(isDark)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w700, color: PaceColors.getPrimaryText(isDark)),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark)),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.arrowUpRight, size: 14, color: PaceColors.getDimText(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark, {bool isChart = false, bool isStation = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.figtree(
              color: PaceColors.getPrimaryText(isDark),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (isChart)
            InkWell(
              onTap: () {
                final next = (_currentChartIndex + 1) % 2;
                _chartPageController.animateToPage(next, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: PaceColors.purple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.repeat, size: 12, color: PaceColors.purple),
                    const SizedBox(width: 4),
                    Text(
                      'Swap View',
                      style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w600, color: PaceColors.purple),
                    ),
                  ],
                ),
              ),
            )
          else if (isStation)
            InkWell(
              onTap: widget.onNavigateToRouters,
              child: Text(
                'View All →',
                style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w600, color: PaceColors.purple),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChartCard(bool isDark) {
    if (_charts.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PaceColors.getBorder(isDark)),
        ),
        child: Center(
          child: Text(
            'No chart analytics available for this cycle',
            style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: SizedBox(
        height: 220,
        child: PageView(
          controller: _chartPageController,
          onPageChanged: (idx) => setState(() => _currentChartIndex = idx),
          children: [
            DashboardChart(chartData: _charts, type: ChartType.line),
            DashboardChart(chartData: _charts, type: ChartType.bar),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTable(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Column(
        children: [
          _buildTableHeader(['Client', 'Plan', 'Amount', 'Status'], isDark),
          if (_isLoading && _transactions.isEmpty)
            const TransactionSkeleton(count: 4)
          else if (_transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No recent activity recorded',
                  style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark)),
                ),
              ),
            )
          else
            ..._transactions.map((tx) => _buildTxRow(tx, isDark)).toList(),
        ],
      ),
    );
  }

  Widget _buildTxRow(dynamic tx, bool isDark) {
    final phone = tx['user_phone']?.toString() ?? 'Hotspot Client';
    final plan = tx['plan_name']?.toString().split('_')[0] ?? 'Access';
    final amount = tx['amount'] != null ? 'KES ${_format(tx['amount'])}' : '---';
    final mpesa = tx['mpesa_code']?.toString().toUpperCase() ?? '';
    final timeAgo = tx['time_ago'] ?? tx['created_at'] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark))),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: PaceColors.getSurface(isDark),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(LucideIcons.smartphone, size: 14, color: PaceColors.getDimText(isDark)),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phone,
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: PaceColors.purple),
                ),
                Text(
                  timeAgo,
                  style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              plan,
              style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w700, color: PaceColors.purple),
                ),
                if (mpesa.isNotEmpty)
                  Text(
                    mpesa,
                    style: GoogleFonts.jetBrainsMono(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationTable(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Column(
        children: [
          _buildTableHeader(['Mikrotik Node', 'IP Address', 'Status'], isDark),
          if (_routerStatus.isEmpty && _isLoading)
            const TransactionSkeleton(count: 3)
          else if (_routerStatus.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No Mikrotik nodes configured',
                  style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark)),
                ),
              ),
            )
          else
            ..._routerStatus.map((r) => _buildStationRow(r, isDark)).toList(),
        ],
      ),
    );
  }

  Widget _buildStationRow(dynamic r, bool isDark) {
    final bool isPinging = r['isPinging'] == true;
    final bool isOnline = r['status']?.toString().toLowerCase() == 'online';
    final name = r['name'] ?? r['router_name'] ?? 'Mikrotik';
    final ip = r['ip'] ?? '0.0.0.0';
    final uptime = r['uptime'] ?? (isOnline ? 'Running' : 'Offline');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
                ),
                Text(
                  uptime,
                  style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              ip,
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: PaceColors.getSecondaryText(isDark)),
            ),
          ),
          SizedBox(
            width: 75,
            child: isPinging
                ? const Center(child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: PaceColors.purple)))
                : PaceBadge(
                    label: isOnline ? 'Online' : 'Offline',
                    variant: isOnline ? BadgeVariant.success : BadgeVariant.error,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(List<String> titles, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark))),
      ),
      child: Row(
        children: titles.asMap().entries.map((e) {
          final bool last = e.key == titles.length - 1;
          return Expanded(
            flex: e.key == 0 ? 3 : 2,
            child: Text(
              e.value.toUpperCase(),
              textAlign: last ? TextAlign.right : TextAlign.left,
              style: GoogleFonts.figtree(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: PaceColors.getDimText(isDark),
                letterSpacing: 0.5,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _format(dynamic val) {
    if (val == null) return "0";
    try {
      final double n = double.parse(val.toString());
      return _currencyFormat.format(n.toInt());
    } catch (_) {
      return val.toString();
    }
  }
}
