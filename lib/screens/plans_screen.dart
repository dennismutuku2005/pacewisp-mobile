import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _plans = [];
  List<dynamic> _routers = [];
  String? _selectedRouterId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final routersRes = await _apiService.getRouters();
    if (mounted) {
      setState(() {
        _routers = routersRes?['data'] ?? [];
        if (_routers.isNotEmpty) {
          _selectedRouterId = _routers[0]['id'].toString();
          _fetchPlans();
        } else {
          _isLoading = false;
        }
      });
    }
  }

  Future<void> _fetchPlans() async {
    if (_selectedRouterId == null) return;
    setState(() => _isLoading = true);
    final plansRes = await _apiService.getPlans(_selectedRouterId!);
    if (mounted) {
      setState(() {
        _plans = plansRes?['plans'] ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildRouterSelector(),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: PaceColors.purple))
            : RefreshIndicator(
                onRefresh: _fetchPlans,
                color: PaceColors.purple,
                child: _plans.isEmpty ? _buildEmptyState() : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildPlanCard(_plans[index]),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ACCESS PLANS',
                style: TextStyle(color: PaceColors.purple, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              Text(
                'BANDWIDTH CONFIGURATION',
                style: TextStyle(color: PaceColors.adminDim, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, padding: const EdgeInsets.symmetric(horizontal: 12)),
            child: const Text('NEW PLAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRouterSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: PaceColors.bgSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PaceColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedRouterId,
            isExpanded: true,
            icon: const Icon(Icons.router, color: PaceColors.purple, size: 20),
            items: _routers.map<DropdownMenuItem<String>>((router) {
              return DropdownMenuItem<String>(
                value: router['id'].toString(),
                child: Text(router['router_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.purple)),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedRouterId = val);
              _fetchPlans();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(dynamic plan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaceColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan['name'] ?? '',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: PaceColors.purple),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'KES ${plan['price']}',
                      style: const TextStyle(color: PaceColors.adminValue, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.timer_outlined, size: 12, color: PaceColors.adminDim),
                    const SizedBox(width: 4),
                    Text(
                      plan['duration'] ?? '',
                      style: const TextStyle(color: PaceColors.adminDim, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PaceBadge(
                label: plan['rate_limit'] ?? '6M/6M',
                variant: BadgeVariant.info,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.edit_outlined, size: 18, color: PaceColors.adminDim),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers_clear, size: 48, color: PaceColors.adminDim.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('NO PLANS CONFIGURED', style: TextStyle(color: PaceColors.adminDim, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}
