import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _plans = [];
  List<dynamic> _routers = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _activeRouterId;

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
        if (_routers.isNotEmpty) {
          _activeRouterId = _routers[0]['id'].toString();
          await _loadPlans();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load routers')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPlans() async {
    if (_activeRouterId == null) return;
    final res = await _apiService.fetchData(slug: 'prepaid_plans', params: {'router_id': _activeRouterId});
    if (mounted && res?['status'] == 'success') {
      setState(() {
        _plans = _sortPlans(res?['plans'] ?? []);
      });
    }
  }

  List<dynamic> _sortPlans(List<dynamic> plans) {
    plans.sort((a, b) {
      final da = _durationToMinutes(a['duration'] ?? a['time'] ?? '');
      final db = _durationToMinutes(b['duration'] ?? b['time'] ?? '');
      if (da == db) {
        final pa = double.tryParse(a['price'].toString()) ?? 0;
        final pb = double.tryParse(b['price'].toString()) ?? 0;
        return pa.compareTo(pb);
      }
      return da.compareTo(db);
    });
    return plans;
  }

  int _durationToMinutes(String raw) {
    if (raw.isEmpty) return 0;
    String s = raw.toLowerCase().trim();
    // Simple mock of TYPO_FIXES for extraction
    final pattern = RegExp(r'(\d+(?:\.\d+)?)\s*(month|week|day|hour|min)', caseSensitive: false);
    final matches = pattern.allMatches(s);
    double total = 0;
    for (var m in matches) {
      final num = double.tryParse(m.group(1)!) ?? 0;
      final unit = m.group(2)!;
      if (unit.startsWith('min')) total += num;
      else if (unit.startsWith('hour')) total += num * 60;
      else if (unit.startsWith('day')) total += num * 1440;
      else if (unit.startsWith('week')) total += num * 10080;
      else if (unit.startsWith('month')) total += num * 43200;
    }
    return total.toInt();
  }

  Future<void> _handleSavePlan({Map<String, dynamic>? editingPlan, int? index}) async {
    final nameController = TextEditingController(text: editingPlan?['name'] ?? '');
    final priceController = TextEditingController(text: editingPlan?['price']?.toString() ?? '');
    final durationController = TextEditingController(text: editingPlan?['duration']?.toString() ?? '');
    final speedController = TextEditingController(text: editingPlan?['speed'] ?? 'UNLIMITED');
    final rateLimitController = TextEditingController(text: editingPlan?['rate_limit'] ?? '6M/6M');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: PaceColors.getBackground(Provider.of<SettingsProvider>(context).isDarkMode),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(editingPlan == null ? 'NEW ACCESS PLAN' : 'EDIT PLAN', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.purple)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField('PRICE (KES)', priceController, LucideIcons.banknote, TextInputType.number),
                const SizedBox(height: 16),
                _buildField('DURATION', durationController, LucideIcons.clock, TextInputType.text, hint: 'e.g. 1 hour, 30 minutes'),
                const SizedBox(height: 16),
                _buildField('SPEED IDENTITY', speedController, LucideIcons.zap, TextInputType.text),
                const SizedBox(height: 16),
                _buildField('RATE LIMIT', rateLimitController, LucideIcons.gauge, TextInputType.text),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('CANCEL', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(editingPlan == null ? 'COMMIT' : 'UPDATE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() => _isSaving = true);
      try {
        final planData = {
          'price': priceController.text,
          'duration': durationController.text,
          'speed': speedController.text,
          'rate_limit': rateLimitController.text,
        };

        final List<dynamic> updatedPlans = List.from(_plans);
        if (index != null) {
           updatedPlans[index] = {...updatedPlans[index], ...planData};
        } else {
           updatedPlans.add(planData);
        }

        final res = await _apiService.fetchData(slug: 'save_plans', method: 'POST', body: {
          'router_id': _activeRouterId,
          'plans': updatedPlans,
          'changed_plan': planData,
          'action': index != null ? 'update' : 'add'
        });

        if (res?['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plans synced successfully'), backgroundColor: PaceColors.emerald));
          _loadPlans();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Failed to sync'), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleDeletePlan(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getBackground(Provider.of<SettingsProvider>(context).isDarkMode),
        title: Text('REMOVE PLAN', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('Are you sure you want to delete this plan?', style: GoogleFonts.figtree(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('KEEP')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
       setState(() => _isSaving = true);
       try {
         final planToDelete = _plans[index];
         final updatedPlans = List.from(_plans)..removeAt(index);
         final res = await _apiService.fetchData(slug: 'save_plans', method: 'POST', body: {
            'router_id': _activeRouterId,
            'plans': updatedPlans,
            'action': 'delete',
            'deleted_plan_name': planToDelete['name']
         });
         if (res?['status'] == 'success') {
           _loadPlans();
         }
       } finally {
         if (mounted) setState(() => _isSaving = false);
       }
    }
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, TextInputType type, {String? hint}) {
    final isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: PaceColors.getBorder(isDark))),
          child: TextField(
            controller: controller,
            keyboardType: type,
            style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold),
            decoration: InputDecoration(hintText: hint, icon: Icon(icon, size: 14, color: PaceColors.purple), border: InputBorder.none),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Column(
      children: [
        _buildHeader(isDark),
        _buildRouterSelector(isDark),
        Expanded(
          child: _isLoading 
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 8))
            : RefreshIndicator(
                onRefresh: _loadPlans,
                color: PaceColors.purple,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: _plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildPlanCard(_plans[index], index, isDark),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ACCESS PLANS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
              Text('MANAGE HOTSPOT DATA PACKAGES', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ],
          ),
          IconButton(
            onPressed: () => _handleSavePlan(),
            icon: const Icon(LucideIcons.plusCircle, color: PaceColors.purple, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildRouterSelector(bool isDark) {
    if (_routers.isEmpty) return const SizedBox();
    final activeRouter = _routers.firstWhere((r) => r['id'].toString() == _activeRouterId, orElse: () => _routers[0]);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: InkWell(
        onTap: () => _showRouterPicker(isDark),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark))),
          child: Row(
            children: [
              const Icon(LucideIcons.wifi, size: 16, color: PaceColors.purple),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                 Text('TARGET ROUTER', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
                 Text(activeRouter['router_name']?.toUpperCase() ?? 'SELECT ROUTER', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark))),
              ])),
              const Icon(LucideIcons.chevronDown, size: 16, color: Colors.grey),
            ],
          ),
        ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _routers.map((r) => ListTile(
            leading: Icon(LucideIcons.router, color: r['id'].toString() == _activeRouterId ? PaceColors.purple : Colors.grey),
            title: Text(r['router_name']?.toUpperCase() ?? '', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold)),
            trailing: r['id'].toString() == _activeRouterId ? const Icon(LucideIcons.check, color: PaceColors.purple) : null,
            onTap: () {
               setState(() => _activeRouterId = r['id'].toString());
               Navigator.pop(context);
               _loadPlans();
            },
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildPlanCard(dynamic plan, int index, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(LucideIcons.tag, color: PaceColors.purple, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan['name']?.toUpperCase() ?? 'NEW PLAN', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('KES ${plan['price']}', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.emerald)),
                    const SizedBox(width: 8),
                    Text(plan['rate_limit'] ?? '6M/6M', style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(onPressed: () => _handleSavePlan(editingPlan: plan, index: index), icon: const Icon(LucideIcons.edit3, size: 16, color: Colors.grey)),
              IconButton(onPressed: () => _handleDeletePlan(index), icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.redAccent)),
            ],
          ),
        ],
      ),
    );
  }
}
