import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/dashboard_chart.dart';
import '../components/skeleton.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _widgets;
  List<dynamic> _charts = [];
  List<dynamic> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData({bool force = false}) async {
    if (!force) setState(() => _isLoading = true);
    
    final results = await Future.wait([
      _apiService.getDashboardData(action: 'widgets', forceRefresh: force),
      _apiService.getDashboardData(action: 'charts', forceRefresh: force),
      _apiService.getDashboardData(action: 'recent_transactions', limit: 5, forceRefresh: force),
    ]);

    if (mounted) {
      setState(() {
        if (results[0] != null) _widgets = results[0]!['data']['widgets'];
        if (results[1] != null) _charts = results[1]!['data']['charts']['revenue_over_time'] ?? [];
        if (results[2] != null) _transactions = results[2]!['data']['recent_transactions'] ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return _isLoading 
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
                _buildHeader(settings, isDark),
                const SizedBox(height: 24),
                _buildMetricsGrid(isDark),
                const SizedBox(height: 24),
                _buildQuickActions(isDark),
                const SizedBox(height: 24),
                _buildActivitySection(isDark),
                const SizedBox(height: 24),
                _buildRecentTransactions(isDark),
                const SizedBox(height: 80),
              ],
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
          const PaceSkeleton(height: 40, width: 200),
          const SizedBox(height: 24),
          const SkeletonGrid(count: 4),
          const SizedBox(height: 24),
          Row(
            children: List.generate(3, (index) => const Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: 8),
                child: PaceSkeleton(height: 70),
              ),
            )),
          ),
          const SizedBox(height: 24),
          const PaceSkeleton(height: 240, borderRadius: 20),
          const SizedBox(height: 24),
          const SkeletonList(count: 5),
        ],
      ),
    );
  }

  Widget _buildHeader(SettingsProvider settings, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DASHBOARD',
              style: TextStyle(color: PaceColors.purple, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            Text(
              settings.subdomain?.toUpperCase() ?? 'PERFORMANCE SUMMARY',
              style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: PaceColors.getSurface(isDark), 
            borderRadius: BorderRadius.circular(12), 
            border: Border.all(color: PaceColors.getBorder(isDark))
          ),
          child: const Icon(Icons.notifications_outlined, color: PaceColors.purple, size: 20),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(bool isDark) {
    if (_widgets == null) return const SizedBox();

    final metrics = [
      {'label': 'TODAY\'S EARNINGS', 'value': 'KSH ${_widgets!['todays_earnings']['value']}', 'icon': Icons.account_balance_wallet, 'color': PaceColors.purple, 'bg': PaceColors.purple.withOpacity(0.1)},
      {'label': 'MONTH REVENUE', 'value': 'KSH ${_widgets!['month_revenue']['value']}', 'icon': Icons.credit_card, 'color': Colors.blue, 'bg': Colors.blue.withOpacity(0.1)},
      {'label': 'ENTRIES', 'value': _widgets!['active_users']['value'].toString(), 'icon': Icons.bolt, 'color': Colors.green, 'bg': Colors.green.withOpacity(0.1)},
      {'label': 'ONLINE CUSTOMERS', 'value': _widgets!['online_customers']['value'].toString(), 'icon': Icons.wifi, 'color': Colors.teal, 'bg': Colors.teal.withOpacity(0.1)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PaceColors.getCard(isDark), 
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: PaceColors.getBorder(isDark))
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: metric['bg'] as Color, borderRadius: BorderRadius.circular(8)),
                child: Icon(metric['icon'] as IconData, color: metric['color'] as Color, size: 16),
              ),
              const Spacer(),
              Text(metric['value'] as String, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
              Text(metric['label'] as String, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 0.5)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return SizedBox(
      height: 70,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildActionCard('GENERATE VOUCHERS', 'Bulk prepaid production', Icons.confirmation_number, PaceColors.purple, isDark),
          const SizedBox(width: 12),
          _buildActionCard('ACTIVE PLANS', 'Manage bandwidth tiers', Icons.tag, Colors.blue, isDark),
          const SizedBox(width: 12),
          _buildActionCard('STATION NODE', 'Core hardware hub', Icons.lan, Colors.orange, isDark),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, bool isDark) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: PaceColors.getBorder(isDark))
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
                Text(subtitle, style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: PaceColors.getBorder(isDark))
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
                  const Text('ACTIVITY & GROWTH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.purple)),
                  Text('SYSTEM UTILIZATION TRENDS', style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  _ChartLegend(color: PaceColors.purple, label: 'REVENUE', isDark: isDark),
                  const SizedBox(width: 8),
                  _ChartLegend(color: Colors.green, label: 'ENTRIES', isDark: isDark),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          DashboardChart(chartData: _charts),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: PaceColors.getBorder(isDark))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RECENT ACTIVITY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.purple)),
          Text('LIVE CONNECTIONS', style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _transactions.length,
            separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 24),
            itemBuilder: (context, index) {
              final tx = _transactions[index];
              return Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: PaceColors.getSurface(isDark), 
                      borderRadius: BorderRadius.circular(8), 
                      border: Border.all(color: PaceColors.getBorder(isDark))
                    ),
                    child: Icon(Icons.smartphone, size: 14, color: PaceColors.getDimText(isDark)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx['user_phone'] ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.purple, fontFamily: 'monospace')),
                        Text('${tx['plan_name']?.split('_')[0] ?? ''} • ${tx['time_ago'] ?? ''}', style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('KES ${tx['amount']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: PaceColors.purple, borderRadius: BorderRadius.circular(4)),
                        child: Text(tx['mpesa_code'] ?? '', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDark;
  const _ChartLegend({required this.color, required this.label, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
      ],
    );
  }
}
