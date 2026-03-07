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

  @override
  void initState() {
    super.initState();
    _loadSyncMemory();
    _loadRouters();
    _fetchCachedThenLive();
  }

  void _loadSyncMemory() {
    final filters = _parseDateRange(_selectedDateRange);
    final router = _selectedRouter == 'All Routers' ? null : _selectedRouter;
    
    final wMem = _apiService.getMemoryCached('widgets', params: {'action': 'widgets', 'router': router, 'startDate': filters['startDate'], 'endDate': filters['endDate']});
    final cMem = _apiService.getMemoryCached('charts', params: {'action': 'charts', 'router': router, 'startDate': filters['startDate'], 'endDate': filters['endDate']});
    final tMem = _apiService.getMemoryCached('recent_transactions', params: {'action': 'recent_transactions', 'limit': 5, 'router': router, 'startDate': filters['startDate'], 'endDate': filters['endDate']});
    final rMem = _apiService.getMemoryCached('widgets', params: {'action': 'router_status', 'limit': 5});

    if (wMem != null || cMem != null || tMem != null || rMem != null) {
      _widgets = _extractData(wMem, 'widgets');
      _charts = cMem?['data']?['charts']?['revenue_over_time'] ?? cMem?['charts']?['revenue_over_time'] ?? cMem?['data']?['revenue_over_time'] ?? [];
      _transactions = _extractData(tMem, 'recent_transactions') ?? [];
      _routerStatus = _extractData(rMem, 'router_status') ?? [];
      _isLoading = false; // Instant data available
    }
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
    } catch (e) { debugPrint("API: Failed to load routers: $e"); }
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

    // SILENT CACHE LOAD
    final cached = await Future.wait<Map<String, dynamic>?>([
      _apiService.getSummaryWidgets(router: router, startDate: filters['startDate'], endDate: filters['endDate'], forceRefresh: false),
      _apiService.getSummaryCharts(router: router, startDate: filters['startDate'], endDate: filters['endDate'], forceRefresh: false),
      _apiService.getRecentTransactions(router: router, startDate: filters['startDate'], endDate: filters['endDate'], limit: 5, forceRefresh: false),
      _apiService.getRouterStatus(limit: 5, forceRefresh: false),
    ]);

    if (mounted) {
      final hasData = cached.any((element) => element != null);
      setState(() {
        _widgets = _extractData(cached[0], 'widgets');
        _charts = cached[1]?['data']?['charts']?['revenue_over_time'] ?? cached[1]?['charts']?['revenue_over_time'] ?? cached[1]?['data']?['revenue_over_time'] ?? [];
        _transactions = _extractData(cached[2], 'recent_transactions') ?? [];
        _routerStatus = _extractData(cached[3], 'router_status') ?? [];
        if (hasData) _isLoading = false;
      });
    }

    // LIVE REFRESH
    final live = await Future.wait<Map<String, dynamic>?>([
      _apiService.getSummaryWidgets(router: router, startDate: filters['startDate'], endDate: filters['endDate'], forceRefresh: true),
      _apiService.getSummaryCharts(router: router, startDate: filters['startDate'], endDate: filters['endDate'], forceRefresh: true),
      _apiService.getRecentTransactions(router: router, startDate: filters['startDate'], endDate: filters['endDate'], limit: 5, forceRefresh: true),
      _apiService.getRouterStatus(limit: 5, forceRefresh: true),
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
    final dynamic data = res['data'];
    if (data is Map) return data[key] ?? data;
    return res[key] ?? data;
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 24),
            _buildGlobalFilters(isDark),
            const SizedBox(height: 32),
            if (_isLoading && _widgets == null)
              const SkeletonGrid(count: 4)
            else ...[
              _buildMetricsGrid(isDark),
              const SizedBox(height: 24),
              _buildCreateVoucherButton(isDark),
              const SizedBox(height: 48),
              _buildQuickAccessGrid(isDark),
              const SizedBox(height: 48),
              _buildSectionHeader('ACTIVITY & GROWTH', 'NETWORK UTILIZATION TRENDS', isDark),
              _buildChartCard(isDark),
              const SizedBox(height: 48),
              _buildSectionHeader('RECENT ACTIVITY', 'LIVE CONNECTIONS', isDark),
              _buildActivityTable(isDark),
              const SizedBox(height: 48),
              _buildSectionHeader('NETWORK STATIONS', 'CORE NODES STATUS', isDark),
              _buildStationTable(isDark),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String sub, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 13, fontWeight: FontWeight.normal, letterSpacing: -0.2)),
            Text(sub, style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ]),
          if (title == 'ACTIVITY & GROWTH') ...[
             const Spacer(),
             Row(children: [
               _buildDot(0), const SizedBox(width: 4), _buildDot(1)
             ]),
             const SizedBox(width: 12),
             Row(children: [_buildLegend(PaceColors.purple, 'REVENUE'), const SizedBox(width: 12), _buildLegend(const Color(0xFF22C55E), 'ACTIVITY')]),
          ]
        ],
      ),
    );
  }

  Widget _buildDot(int index) => Container(width: 6, height: 6, decoration: BoxDecoration(color: _currentChartIndex == index ? PaceColors.purple : PaceColors.getBorder(true), shape: BoxShape.circle));

  Widget _buildHeader(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('DASHBOARD', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 20, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
      Text('PERFORMANCE SUMMARY', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
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
    showModalBottomSheet(context: context, backgroundColor: PaceColors.getCard(isDark), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))), builder: (context) => Container(padding: const EdgeInsets.symmetric(vertical: 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Text('SELECT STATION NODE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 2))), const SizedBox(height: 8), Flexible(child: ListView.builder(shrinkWrap: true, itemCount: _routerNames.length, itemBuilder: (context, index) { final r = _routerNames[index]; final isSelected = _selectedRouter == r; return ListActionTile(label: r, icon: Icons.router_outlined, isSelected: isSelected, onTap: () { setState(() => _selectedRouter = r); Navigator.pop(context); _fetchCachedThenLive(); }, isDark: isDark); }))])));
  }

  void _showDatePicker(bool isDark) {
    final ranges = ['All Time', 'Today', 'Yesterday', 'This Week', 'This Month'];
    showModalBottomSheet(context: context, backgroundColor: PaceColors.getCard(isDark), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))), builder: (context) => Container(padding: const EdgeInsets.symmetric(vertical: 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Text('SELECT PERFORMANCE CYCLE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 2))), const SizedBox(height: 8), ...ranges.map((range) { final isSelected = _selectedDateRange == range; return ListActionTile(label: range, icon: Icons.access_time_rounded, isSelected: isSelected, onTap: () { setState(() => _selectedDateRange = range); Navigator.pop(context); _fetchCachedThenLive(); }, isDark: isDark); }).toList()])));
  }

  Widget _buildMetricsGrid(bool isDark) {
    if (_widgets == null) return const SkeletonGrid(count: 6);
    final data = _widgets!;
    final metrics = [
      {'label': "TODAY'S EARNINGS", 'value': "KSH ${_format(data['todays_earnings']?['value'])}", 'icon': Icons.account_balance_wallet_rounded, 'color': PaceColors.purple, 'bg': PaceColors.purple.withOpacity(0.08)},
      {'label': "MONTH REVENUE", 'value': "KSH ${_format(data['month_revenue']?['value'])}", 'icon': Icons.credit_card_rounded, 'color': const Color(0xFF3B82F6), 'bg': const Color(0xFF3B82F6).withOpacity(0.08)},
      {'label': "ENTRIES", 'value': "${data['active_users']?['value'] ?? 0}", 'icon': Icons.bolt_rounded, 'color': const Color(0xFF22C55E), 'bg': const Color(0xFF22C55E).withOpacity(0.08)},
      {'label': "MONTH CUSTOMERS", 'value': "${data['customers_month']?['value'] ?? 0}", 'icon': Icons.people_rounded, 'color': PaceColors.getDimText(isDark), 'bg': PaceColors.getSurface(isDark)},
      {'label': "ONLINE USERS", 'value': "${data['online_customers']?['value'] ?? 0}", 'icon': Icons.wifi_rounded, 'color': const Color(0xFF10B981), 'bg': const Color(0xFF10B981).withOpacity(0.08)},
      {'label': "SYSTEM HEALTH", 'value': "${data['system_health']?['value'] ?? '98%'}", 'icon': Icons.lan_rounded, 'color': const Color(0xFFF59E0B), 'bg': const Color(0xFFF59E0B).withOpacity(0.08)},
    ];
    return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5), itemCount: metrics.length, itemBuilder: (context, index) {
      final m = metrics[index];
      final bool blurIt = m['label'] == "MONTH REVENUE" && _isRevenueBlurred;
      return InkWell(onTap: m['label'] == "MONTH REVENUE" ? () => setState(() => _isRevenueBlurred = !_isRevenueBlurred) : null, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2), boxShadow: isDark ? [] : [BoxShadow(color: (m['color'] as Color).withOpacity(0.05), blurRadius: 20, spreadRadius: -5, offset: const Offset(0, 10))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: m['bg'] as Color, borderRadius: BorderRadius.circular(10)), child: Icon(m['icon'] as IconData, color: m['color'] as Color, size: 16)), const Spacer(), if (blurIt) ClipRect(child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), child: Text("KSH 88,888", style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.normal, color: PaceColors.getPrimaryText(isDark), letterSpacing: -0.5)))) else Text(m['value'] as String, style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.normal, color: PaceColors.purple, letterSpacing: -0.5)), const SizedBox(height: 2), Text(m['label'] as String, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1))])));
    });
  }

  Widget _buildCreateVoucherButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: widget.onGenerateVoucher,
        icon: const Icon(Icons.confirmation_num_rounded, size: 24),
        label: Text('CREATE NEW VOUCHERS', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: PaceColors.purple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          shadowColor: PaceColors.purple.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildQuickAccessGrid(bool isDark) {
    return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.5, children: [
        _buildActionItem(Icons.tag_rounded, 'ACTIVE PLANS', 'Bandwidth tiers', Colors.blue, isDark, () {}),
        _buildActionItem(Icons.people_alt_rounded, 'CUSTOMERS', 'Manage accounts', PaceColors.emerald, isDark, () {}),
        _buildActionItem(Icons.lan_rounded, 'STATION NODE', 'Hardware portal', Colors.orange, isDark, () {}),
        _buildActionItem(Icons.analytics_rounded, 'SMART LOGGER', 'Internal events', PaceColors.getDimText(isDark), isDark, () {}),
    ]);
  }

  Widget _buildActionItem(IconData icon, String title, String sub, Color color, bool isDark, VoidCallback? onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2), boxShadow: isDark ? [] : [BoxShadow(color: color.withOpacity(0.04), blurRadius: 40, spreadRadius: 0)]), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 18)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w800, color: PaceColors.getPrimaryText(isDark), letterSpacing: -0.2)), Text(sub, style: GoogleFonts.figtree(fontSize: 7, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold))]))])));
  }

  Widget _buildChartCard(bool isDark) {
    if (_charts.isEmpty) return const PaceSkeleton(height: 240);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 40, spreadRadius: 0)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            InkWell(
              onTap: () {
                final next = (_currentChartIndex + 1) % 2;
                _chartPageController.animateToPage(next, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 14, color: PaceColors.purple),
                    const SizedBox(width: 4),
                    Text('SWAP VIEW', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 240, 
          child: PageView(
            controller: _chartPageController,
            onPageChanged: (idx) => setState(() => _currentChartIndex = idx),
            children: [
              DashboardChart(chartData: _charts, type: ChartType.line),
              DashboardChart(chartData: _charts, type: ChartType.bar),
            ],
          )
        ),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _buildLegend(Color color, String label) => Row(children: [Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 4), Text(label, style: GoogleFonts.figtree(fontSize: 7, fontWeight: FontWeight.bold, color: PaceColors.getDimText(true), letterSpacing: 1))]);

  Widget _buildActivityTable(bool isDark) {
    if (_transactions.isEmpty && _isLoading) return const SkeletonList(count: 5);
    return Container(
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 40, spreadRadius: 0)]),
      child: Column(children: [
        _buildTableHeader(['CLIENT', 'PLAN', 'AMOUNT', 'REC'], isDark),
        if (_transactions.isEmpty)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('NO LIVE CONNECTIONS FOUND', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey))))
        else
          ..._transactions.map((tx) => _buildTxRow(tx, isDark)).toList(),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildTxRow(dynamic tx, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark).withOpacity(0.4)))),
      child: Row(children: [
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tx['user_phone'] ?? 'SYSTEM', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))), Text(tx['time_ago'] ?? 'Now', style: GoogleFonts.figtree(fontSize: 7, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold))])),
        Expanded(flex: 2, child: Text(tx['plan_name']?.toString().split('_')[0].toUpperCase() ?? 'PLAN', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.purple))),
        Expanded(flex: 2, child: Text('KES ${_format(tx['amount'])}', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)))),
        Expanded(flex: 2, child: Container(alignment: Alignment.centerRight, child: Text(tx['mpesa_code']?.toString().toUpperCase().substring(0, 3) ?? 'TX', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)))),
      ]),
    );
  }

  Widget _buildStationTable(bool isDark) {
    if (_routerStatus.isEmpty && _isLoading) return const SkeletonList(count: 3);
    return Container(
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 40, spreadRadius: 0)]),
      child: Column(children: [
        _buildTableHeader(['NODE NAME', 'NETWORK IP', 'STATUS'], isDark),
        if (_routerStatus.isEmpty)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('NO CHASSIS NODES DETECTED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey))))
        else
          ..._routerStatus.map((r) => _buildStationRow(r, isDark)).toList(),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildStationRow(dynamic r, bool isDark) {
    bool isOnline = r['status']?.toString().toLowerCase() == 'up' || r['status']?.toString().toLowerCase() == 'online';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark).withOpacity(0.4)))),
      child: Row(children: [
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r['name']?.toUpperCase() ?? 'NODE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))), Text(r['uptime'] ?? '15d 4h', style: GoogleFonts.figtree(fontSize: 7, color: PaceColors.getDimText(isDark)))]).pOnly(left: 4)),
        Expanded(flex: 3, child: Text(r['ip'] ?? '0.0.0.0', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: PaceColors.getPrimaryText(isDark)))),
        SizedBox(width: 80, child: PaceBadge(label: isOnline ? 'ONLINE' : 'OFFLINE', variant: isOnline ? BadgeVariant.success : BadgeVariant.error)),
      ]),
    );
  }

  Widget _buildTableHeader(List<String> titles, bool isDark) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: PaceColors.getSurface(isDark).withOpacity(0.5), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))), child: Row(children: titles.asMap().entries.map((e) {
      final bool last = e.key == titles.length - 1;
      return Expanded(flex: e.key == 0 ? 3 : 2, child: Text(e.value, textAlign: last ? TextAlign.right : TextAlign.left, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 0.5)));
    }).toList()));
  }

  String _format(dynamic val) { if (val == null) return "0"; try { final double n = double.parse(val.toString()); return _currencyFormat.format(n.toInt()); } catch (e) { return val.toString(); } }
}

extension PaddingExtension on Widget {
  Widget pOnly({double left = 0, double right = 0, double top = 0, double bottom = 0}) => Padding(padding: EdgeInsets.only(left: left, right: right, top: top, bottom: bottom), child: this);
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
