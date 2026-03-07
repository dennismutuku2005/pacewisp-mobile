import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

class RoutersScreen extends StatefulWidget {
  const RoutersScreen({super.key});

  @override
  State<RoutersScreen> createState() => _RoutersScreenState();
}

class _RoutersScreenState extends State<RoutersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _routers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRouters();
  }

  Future<void> _fetchRouters() async {
    setState(() => _isLoading = true);
    final res = await _apiService.getRouters();
    if (mounted) {
      setState(() {
        _routers = res?['data'] ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Column(
      children: [
        _buildHeader(isDark),
        Expanded(
          child: _isLoading 
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 4))
            : RefreshIndicator(
                onRefresh: _fetchRouters,
                color: PaceColors.purple,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _routers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) => _buildRouterCard(_routers[index], isDark),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ROUTER NODES', style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              Icon(Icons.router_rounded, color: PaceColors.purple, size: 24),
            ],
          ),
          Text('NETWORK STATIONS & CORE GATEWAYS', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildRouterCard(dynamic router, bool isDark) {
    final status = (router['status'] ?? '').toString().toLowerCase();
    final bool isOnline = status == 'online' || router['is_online'] == true;
    final String name = router['router_name']?.toUpperCase() ?? 'NODE STATION';
    final String model = router['model'] ?? router['host'] ?? 'WISP GATEWAY';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark), 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12), 
                decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(16)), 
                child: Icon(Icons.router_rounded, color: PaceColors.purple, size: 28)
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(model, style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ],
                ),
              ),
              PaceBadge(
                label: isOnline ? 'ONLINE' : 'OFFLINE', 
                variant: isOnline ? BadgeVariant.success : BadgeVariant.error
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildStat('USERS', router['users']?.toString() ?? '0', Icons.people_outline, isDark),
              _buildStat('UPTIME', router['uptime'] ?? '0D 0H', Icons.timer_outlined, isDark),
              _buildStat('LOAD', '${router['cpu'] ?? 0}%', Icons.speed_rounded, isDark),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('IP: ${router['host'] ?? '0.0.0.0'}', style: TextStyle(fontSize: 10, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ),
              Icon(Icons.terminal_rounded, size: 14, color: PaceColors.getDimText(isDark).withOpacity(0.5)),
              const SizedBox(width: 4),
              Text('ROUTEROS', style: TextStyle(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, bool isDark) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 10, color: PaceColors.getDimText(isDark)),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: PaceColors.getPrimaryText(isDark), fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
