import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/skeleton.dart';
import '../components/empty_state.dart';
import '../components/overlay_loader.dart';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load routers', style: GoogleFonts.figtree()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPlans({bool forceRefresh = false}) async {
    if (_activeRouterId == null) return;
    try {
      final res = await _apiService.fetchData(
        slug: 'plans',
        params: {'router_id': _activeRouterId},
        forceRefresh: forceRefresh,
      );
      if (mounted && res?['status'] == 'success') {
        setState(() {
          _plans = _sortPlans(res?['plans'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading plans: $e');
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
    final durationController = TextEditingController(text: editingPlan?['duration']?.toString() ?? editingPlan?['time']?.toString() ?? '');
    final speedController = TextEditingController(text: editingPlan?['speed'] ?? 'Unlimited');
    final rateLimitController = TextEditingController(text: editingPlan?['rate_limit'] ?? '6M/6M');
    final isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PaceColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                    Text(
                      editingPlan == null ? 'Create Access Plan' : 'Edit Access Plan',
                      style: GoogleFonts.figtree(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: PaceColors.getPrimaryText(isDark),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ],
                ),
                Text(
                  'Configure billing rates and bandwidth limits for this hotspot package.',
                  style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getDimText(isDark)),
                ),
                const SizedBox(height: 20),
                _buildFormField('Plan Name', nameController, TextInputType.text, isDark, hint: 'e.g. 1 Hour Unlimited'),
                const SizedBox(height: 14),
                _buildFormField('Price (KES)', priceController, TextInputType.number, isDark, hint: 'e.g. 20'),
                const SizedBox(height: 14),
                _buildFormField('Duration', durationController, TextInputType.text, isDark, hint: 'e.g. 1 hour, 30 min, 1 day'),
                const SizedBox(height: 14),
                _buildFormField('Bandwidth Identity', speedController, TextInputType.text, isDark, hint: 'e.g. Fast, Unlimited, Standard'),
                const SizedBox(height: 14),
                _buildFormField('Rate Limit (Upload/Download)', rateLimitController, TextInputType.text, isDark, hint: 'e.g. 6M/6M or 3M/5M'),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: PaceColors.getBorder(isDark)),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.figtree(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: PaceColors.getDimText(isDark),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          if (nameController.text.trim().isEmpty || priceController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Plan name and price are required')),
                            );
                            return;
                          }
                          Navigator.pop(ctx, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PaceColors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          editingPlan == null ? 'Create Plan' : 'Save Changes',
                          style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
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
          'name': nameController.text.trim(),
          'price': priceController.text.trim(),
          'duration': durationController.text.trim(),
          'speed': speedController.text.trim(),
          'rate_limit': rateLimitController.text.trim(),
        };

        final List<dynamic> updatedPlans = List.from(_plans);
        if (index != null) {
          updatedPlans[index] = {...updatedPlans[index], ...planData};
        } else {
          updatedPlans.add(planData);
        }

        final res = await _apiService.fetchData(
          slug: 'plans',
          method: 'POST',
          body: {
            'router_id': _activeRouterId,
            'plans': updatedPlans,
            'changed_plan': planData,
            'action': index != null ? 'update' : 'add'
          },
        );

        if (res?['status'] == 'success') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Plan updated successfully', style: GoogleFonts.figtree()),
                backgroundColor: PaceColors.emerald,
              ),
            );
          }
          await _loadPlans(forceRefresh: true);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res?['message'] ?? 'Failed to update plans', style: GoogleFonts.figtree()),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleDeletePlan(int index) async {
    final isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;
    final planToDelete = _plans[index];
    final planName = planToDelete['name'] ?? 'this plan';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Plan',
          style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
        ),
        content: Text(
          'Are you sure you want to delete "$planName"? Customers will no longer be able to purchase vouchers for this package.',
          style: GoogleFonts.figtree(fontSize: 14, color: PaceColors.getDimText(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: GoogleFonts.figtree(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      try {
        final updatedPlans = List.from(_plans)..removeAt(index);
        final res = await _apiService.fetchData(
          slug: 'plans',
          method: 'POST',
          body: {
            'router_id': _activeRouterId,
            'plans': updatedPlans,
            'action': 'delete',
            'deleted_plan_name': planToDelete['name'],
          },
        );
        if (res?['status'] == 'success') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Plan deleted', style: GoogleFonts.figtree()), backgroundColor: PaceColors.emerald),
            );
          }
          await _loadPlans(forceRefresh: true);
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  void _showPlanDetails(dynamic plan, int index, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan['name']?.toString() ?? 'Access Plan',
                      style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                    ),
                    Text(
                      'KES ${plan['price'] ?? '0'}',
                      style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w700, color: PaceColors.emerald),
                    ),
                  ],
                ),
                IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 20),
            _detailRow('Duration', plan['duration']?.toString() ?? plan['time']?.toString() ?? '-', isDark),
            _detailRow('Bandwidth Profile', plan['speed']?.toString() ?? 'Unlimited', isDark),
            _detailRow('Rate Limit', plan['rate_limit']?.toString() ?? '6M/6M', isDark),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleSavePlan(editingPlan: plan, index: index);
                    },
                    icon: const Icon(LucideIcons.edit3, size: 16),
                    label: Text('Edit Plan', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PaceColors.purple,
                      side: const BorderSide(color: PaceColors.purple),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleDeletePlan(index);
                    },
                    icon: const Icon(LucideIcons.trash2, size: 16),
                    label: Text('Delete', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getDimText(isDark))),
          Text(value, style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
        ],
      ),
    );
  }

  Widget _buildFormField(String label, TextEditingController controller, TextInputType type, bool isDark, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: PaceColors.getSurface(isDark),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PaceColors.getBorder(isDark)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: type,
            style: GoogleFonts.figtree(fontSize: 14, color: PaceColors.getPrimaryText(isDark)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getDimText(isDark).withOpacity(0.6)),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
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
      message: 'Updating plan...',
      child: Column(
        children: [
          _buildHeader(isDark),
          _buildRouterSelector(isDark),
          Expanded(
            child: _isLoading
                ? const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SkeletonList(count: 6))
                : RefreshIndicator(
                    onRefresh: () => _loadPlans(forceRefresh: true),
                    color: PaceColors.purple,
                    child: _plans.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: PaceEmptyState(
                              title: 'No Plans Configured',
                              subtitle: 'Add hotspot packages for this router to enable customer checkout and voucher creation.',
                              onRetry: () => _handleSavePlan(),
                              isDark: isDark,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                            itemCount: _plans.length,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Access Plans',
                  style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.bold, color: PaceColors.purple),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tariff packages & bandwidth limits',
                  style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _handleSavePlan(),
            icon: const Icon(LucideIcons.plus, size: 15),
            label: Text('New Plan', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: PaceColors.purple,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouterSelector(bool isDark) {
    if (_routers.isEmpty) return const SizedBox();
    final activeRouter = _routers.firstWhere(
      (r) => r['id'].toString() == _activeRouterId,
      orElse: () => _routers[0],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: InkWell(
        onTap: () => _showRouterPicker(isDark),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: PaceColors.getCard(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PaceColors.getBorder(isDark)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: PaceColors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.router, size: 16, color: PaceColors.purple),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target Router Node',
                      style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark)),
                    ),
                    Text(
                      activeRouter['router_name'] ?? 'Select Router',
                      style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronDown, size: 18, color: Colors.grey),
            ],
          ),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Router Node',
                  style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                ),
                IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            ..._routers.map((r) {
              final isSelected = r['id'].toString() == _activeRouterId;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: Icon(LucideIcons.router, size: 18, color: isSelected ? PaceColors.purple : PaceColors.getDimText(isDark)),
                title: Text(
                  r['router_name'] ?? 'Router',
                  style: GoogleFonts.figtree(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? PaceColors.purple : PaceColors.getPrimaryText(isDark),
                  ),
                ),
                trailing: isSelected ? const Icon(LucideIcons.check, color: PaceColors.purple, size: 18) : null,
                onTap: () {
                  setState(() => _activeRouterId = r['id'].toString());
                  Navigator.pop(context);
                  _loadPlans(forceRefresh: true);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanRow(dynamic plan, int index, bool isDark) {
    final name = plan['name']?.toString() ?? 'Plan';
    final price = plan['price']?.toString() ?? '0';
    final duration = plan['duration']?.toString() ?? plan['time']?.toString() ?? '-';
    final rateLimit = plan['rate_limit']?.toString() ?? '6M/6M';
    final speed = plan['speed']?.toString() ?? 'Standard';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showPlanDetails(plan, index, isDark),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PaceColors.getCard(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PaceColors.getBorder(isDark)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.figtree(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: PaceColors.getPrimaryText(isDark),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(LucideIcons.clock, size: 12, color: PaceColors.getDimText(isDark)),
                            const SizedBox(width: 4),
                            Text(
                              duration,
                              style: GoogleFonts.figtree(
                                fontSize: 12,
                                color: PaceColors.getDimText(isDark),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'KES $price',
                        style: GoogleFonts.figtree(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: PaceColors.emerald,
                        ),
                      ),
                      Text(
                        speed,
                        style: GoogleFonts.figtree(
                          fontSize: 11,
                          color: PaceColors.getDimText(isDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  PaceBadge(
                    label: 'Limit: $rateLimit',
                    variant: BadgeVariant.secondary,
                  ),
                  const Spacer(),
                  Text(
                    'Tap for details',
                    style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark)),
                  ),
                  const SizedBox(width: 4),
                  Icon(LucideIcons.chevronRight, size: 14, color: PaceColors.getDimText(isDark)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
