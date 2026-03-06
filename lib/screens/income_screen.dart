import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/dashboard_chart.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData({bool force = false}) async {
    if (!force) setState(() => _isLoading = true);
    final res = await _apiService.getIncome(router: 'All Routers', forceRefresh: force);
    if (mounted) {
      setState(() {
        _incomeData = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading 
      ? _buildSkeletonBody()
      : RefreshIndicator(
          onRefresh: () => _fetchData(force: true),
          color: PaceColors.purple,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildMetricsGrid(),
                const SizedBox(height: 24),
                _buildChartSection(),
                const SizedBox(height: 24),
                _buildDistributionSection(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
  }

  Widget _buildSkeletonBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PaceSkeleton(height: 40, width: 220),
          const SizedBox(height: 24),
          const SkeletonGrid(count: 3),
          const SizedBox(height: 24),
          const PaceSkeleton(height: 240, borderRadius: 20),
          const SizedBox(height: 24),
          const PaceSkeleton(height: 180, borderRadius: 20),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REVENUE ANALYTICS',
          style: TextStyle(color: PaceColors.purple, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        Text(
          'FINANCIAL PERFORMANCE & INSIGHTS',
          style: TextStyle(color: PaceColors.adminDim, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    final metrics = _incomeData?['metrics'];
    if (metrics == null) return const SizedBox();

    final cardData = [
      {'label': 'TODAY', 'value': 'KSH ${metrics['today']['value']}', 'trend': '${metrics['today']['trend']}%', 'icon': Icons.account_balance_wallet, 'color': PaceColors.purple},
      {'label': 'THIS WEEK', 'value': 'KSH ${metrics['week']['value']}', 'trend': '${metrics['week']['trend']}%', 'icon': Icons.calendar_today, 'color': Colors.blue},
      {'label': 'THIS MONTH', 'value': 'KSH ${metrics['month']['value']}', 'trend': '${metrics['month']['trend']}%', 'icon': Icons.trending_up, 'color': Colors.green},
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
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PaceColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PaceColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: (data['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(data['icon'] as IconData, color: data['color'] as Color, size: 16),
                  ),
                  Text(
                    data['trend'] as String,
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
              const Spacer(),
              Text(data['label'] as String, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.purple)),
              Text(data['value'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: PaceColors.adminValue)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartSection() {
    final charts = _incomeData?['charts']?['revenue_trend'] ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaceColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('INCOME TREND', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.purple)),
          const Text('DAILY REVENUE TREND', style: TextStyle(fontSize: 9, color: PaceColors.adminDim, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          DashboardChart(chartData: charts),
        ],
      ),
    );
  }

  Widget _buildDistributionSection() {
    final distribution = _incomeData?['charts']?['plan_distribution'] ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaceColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PLAN DISTRIBUTION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.purple)),
          const Text('REVENUE BY PLAN TYPE', style: TextStyle(fontSize: 9, color: PaceColors.adminDim, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...distribution.map<Widget>((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: _parseColor(item['color']), shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(child: Text(item['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.adminLabel))),
                Text('${item['value']}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.adminValue)),
              ],
            ),
          )).toList(),
        ],
      ),
    );
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
