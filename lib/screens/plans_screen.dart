import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/skeleton.dart';
import '../components/overlay_loader.dart';

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
    final isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PaceColors.getBackground(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(editingPlan == null ? 'NEW ACCESS PLAN' : 'EDIT PLAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: PaceColors.purple, letterSpacing: -0.5)),
                    IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(ctx, false)),
                  ],
                ),
                const SizedBox(height: 24),
                _buildField('PRICE (KES)', priceController, TextInputType.number, isDark),
                const SizedBox(height: 16),
                _buildField('DURATION', durationController, TextInputType.text, isDark, hint: 'e.g. 1 hour, 30 minutes'),
                const SizedBox(height: 16),
                _buildField('SPEED IDENTITY', speedController, TextInputType.text, isDark),
                const SizedBox(height: 16),
                _buildField('RATE LIMIT', rateLimitController, TextInputType.text, isDark),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('CANCEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: Text(editingPlan == null ? 'COMMIT' : 'UPDATE', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
    final isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getBackground(isDark),
        title: const Text('REMOVE PLAN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red)),
        content: const Text('Are you sure you want to delete this plan?', style: TextStyle(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('KEEP')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600))),
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

  void _showPlanDrawer(dynamic plan, int index, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getBackground(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('PLAN DETAILS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: PaceColors.purple, letterSpacing: -0.5)),
                IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 20),
            _drawerRow('NAME', plan['name']?.toString().toUpperCase() ?? 'PLAN', isDark),
            _drawerRow('PRICE', 'KES ${plan['price'] ?? '0'}', isDark),
            _drawerRow('DURATION', plan['duration']?.toString() ?? plan['time']?.toString() ?? '-', isDark),
            _drawerRow('SPEED', plan['speed']?.toString() ?? 'UNLIMITED', isDark),
            _drawerRow('RATE LIMIT', plan['rate_limit']?.toString() ?? '6M/6M', isDark),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () { Navigator.pop(ctx); _handleSavePlan(editingPlan: plan, index: index); },
                    icon: const Icon(LucideIcons.edit3, size: 14),
                    label: const Text('EDIT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(foregroundColor: PaceColors.purple, side: const BorderSide(color: PaceColors.purple), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () { Navigator.pop(ctx); _handleDeletePlan(index); },
                    icon: const Icon(LucideIcons.trash2, size: 14),
                    label: const Text('DELETE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, TextInputType type, bool isDark, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: PaceColors.getBorder(isDark))),
          child: TextField(
            controller: controller,
            keyboardType: type,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
            decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: PaceColors.getDimText(isDark)), border: InputBorder.none),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return PaceOverlayLoader(
      isLoading: _isSaving,
      message: 'Processing...',
      child: Column(
        children: [
          _buildHeader(isDark),
          _buildRouterSelector(isDark),
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark)))),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('PLAN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
              Expanded(flex: 2, child: Text('PRICE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
              Expanded(flex: 2, child: Text('SPEED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
              const SizedBox(width: 24),
            ],
          ),
        ),
        Expanded(
          child: _isLoading 
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 8))
            : RefreshIndicator(
                onRefresh: _loadPlans,
                color: PaceColors.purple,
                child: _plans.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(LucideIcons.tag, size: 48, color: PaceColors.getDimText(isDark).withOpacity(0.1)),
                      const SizedBox(height: 16),
                      Text('NO PLANS FOUND', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
                    ]))
                  : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: _plans.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: PaceColors.getBorder(isDark)),
                    itemBuilder: (context, index) => _buildPlanRow(_plans[index], index, isDark),
                  ),
              ),
        ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ACCESS PLANS', style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
              Text('MANAGE HOTSPOT PACKAGES', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2)),
            ],
          ),
          IconButton(
            onPressed: () => _handleSavePlan(),
            icon: const Icon(LucideIcons.plusCircle, color: PaceColors.purple, size: 24),
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
                 Text('TARGET ROUTER', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
                 Text(activeRouter['router_name']?.toUpperCase() ?? 'SELECT ROUTER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SELECT ROUTER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: PaceColors.purple, letterSpacing: -0.5)),
                IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            ..._routers.map((r) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(r['router_name']?.toUpperCase() ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              trailing: r['id'].toString() == _activeRouterId ? const Icon(LucideIcons.check, color: PaceColors.purple) : null,
              onTap: () {
                 setState(() => _activeRouterId = r['id'].toString());
                 Navigator.pop(context);
                 _loadPlans();
              },
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanRow(dynamic plan, int index, bool isDark) {
    return InkWell(
      onTap: () => _showPlanDrawer(plan, index, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan['name']?.toString().toUpperCase() ?? 'PLAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
                  const SizedBox(height: 2),
                  Text(plan['duration']?.toString() ?? plan['time']?.toString() ?? '-', style: TextStyle(fontSize: 10, color: PaceColors.getDimText(isDark))),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text('KES ${plan['price'] ?? '0'}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.emerald)),
            ),
            Expanded(
              flex: 2,
              child: Text(plan['rate_limit']?.toString() ?? '6M/6M', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark))),
            ),
            Icon(Icons.more_vert, size: 18, color: PaceColors.getDimText(isDark)),
          ],
        ),
      ),
    );
  }
}
