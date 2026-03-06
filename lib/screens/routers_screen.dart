import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';

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
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: PaceColors.purple))
            : RefreshIndicator(
                onRefresh: _fetchRouters,
                color: PaceColors.purple,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _routers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildRouterCard(_routers[index]),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ROUTER NODES',
            style: TextStyle(color: PaceColors.purple, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          Text(
            'NETWORK STATIONS & GATEWAYS',
            style: TextStyle(color: PaceColors.adminDim, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRouterCard(dynamic router) {
    bool isOnline = (router['status'] ?? '').toString().toLowerCase() == 'online';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaceColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: PaceColors.purpleLight, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.router, color: PaceColors.purple, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      router['router_name'] ?? 'STATION',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: PaceColors.purple),
                    ),
                    Text(
                      router['host'] ?? 'Local Network',
                      style: const TextStyle(fontSize: 11, color: PaceColors.adminDim, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              PaceBadge(
                label: isOnline ? 'Online' : 'Offline',
                variant: isOnline ? BadgeVariant.success : BadgeVariant.error,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: PaceColors.border, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat('USERS', router['users']?.toString() ?? '0'),
              _buildStat('UPTIME', router['uptime'] ?? '0h'),
              _buildStat('CPU', '${router['cpu'] ?? 0}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: PaceColors.adminDim, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
        Text(value, style: const TextStyle(color: PaceColors.adminValue, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
