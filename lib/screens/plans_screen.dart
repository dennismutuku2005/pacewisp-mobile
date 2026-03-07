import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  String _selectedRouterId = '';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    final routersRes = await _apiService.getRouters();
    if (mounted && routersRes != null && routersRes['data'] != null) {
      _routers = routersRes['data'];
      if (_routers.isNotEmpty) {
        _selectedRouterId = _routers[0]['id'].toString();
        await _fetchPlans();
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchPlans() async {
    if (_selectedRouterId.isEmpty) return;
    final res = await _apiService.getPlans(_selectedRouterId, forceRefresh: true);
    if (mounted) {
      setState(() {
        _plans = res?['data']?['plans'] ?? res?['plans'] ?? [];
      });
    }
  }

  void _showCreateModal(bool isDark) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final durationController = TextEditingController();
    String? selectedLimitType = 'Unlimited';
    bool isSaving = false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: PaceColors.getBackground(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: PaceColors.getBorder(isDark)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: PaceColors.getBorder(isDark), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Text('CREATE ACCESS PLAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1.5)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('PLAN NAME (PROMO)', isDark),
                      _buildTextField(nameController, 'e.g. 50MB 1 HOUR', Icons.title, isDark, enabled: !isSaving),
                      const SizedBox(height: 20),
                      _buildLabel('PRICE (KES)', isDark),
                      _buildTextField(priceController, 'e.g. 10', Icons.payments_outlined, isDark, kType: TextInputType.number, enabled: !isSaving),
                      const SizedBox(height: 20),
                      _buildLabel('DURATION (MINUTES)', isDark),
                      _buildTextField(durationController, 'e.g. 60', Icons.timer_outlined, isDark, kType: TextInputType.number, enabled: !isSaving),
                      const SizedBox(height: 20),
                      _buildLabel('DATA LIMIT (MB)', isDark),
                      DropdownButtonFormField<String>(
                        value: selectedLimitType,
                        dropdownColor: PaceColors.getCard(isDark),
                        decoration: _inputDecoration(Icons.data_usage_rounded, isDark),
                        items: ['Unlimited', '50', '100', '250', '500', '1024']
                            .map((l) => DropdownMenuItem(value: l, child: Text(l, style: TextStyle(color: PaceColors.getPrimaryText(isDark), fontWeight: FontWeight.bold))))
                            .toList(),
                        onChanged: isSaving ? null : (val) => setModalState(() => selectedLimitType = val),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity, 
                  height: 56, 
                  child: ElevatedButton(
                    onPressed: isSaving ? null : () async {
                      setModalState(() => isSaving = true);
                      final res = await _apiService.createPlan({
                        'router_id': _selectedRouterId,
                        'name': nameController.text,
                        'price': priceController.text,
                        'duration': durationController.text,
                        'data_limit': selectedLimitType == 'Unlimited' ? '0' : selectedLimitType,
                      });
                      if (mounted) {
                        Navigator.pop(context);
                        _fetchPlans();
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    child: isSaving 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('SAVE PLAN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                  )
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(IconData icon, bool isDark) => InputDecoration(
    prefixIcon: Icon(icon, color: PaceColors.purple, size: 20),
    filled: true,
    fillColor: PaceColors.getSurface(isDark),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: PaceColors.getBorder(isDark), width: 1.5)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: PaceColors.getBorder(isDark), width: 1.5)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PaceColors.purple, width: 2)),
  );

  Widget _buildLabel(String text, bool isDark) => Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)));

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon, bool isDark, {TextInputType kType = TextInputType.text, bool enabled = true}) => TextField(
    controller: ctrl, 
    keyboardType: kType,
    enabled: enabled,
    style: TextStyle(color: PaceColors.getPrimaryText(isDark), fontWeight: FontWeight.bold),
    decoration: _inputDecoration(icon, isDark).copyWith(hintText: hint, hintStyle: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 13)),
  );

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
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _plans.length,
                separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                itemBuilder: (context, index) => _buildPlanItem(_plans[index], isDark),
              ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('HOTSPOT PLANS', style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              Text('TIERED SERVICE CONFIGURATION', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
          IconButton(onPressed: () => _showCreateModal(isDark), icon: const Icon(Icons.add_circle_outline_rounded, color: PaceColors.purple, size: 28)),
        ],
      ),
    );
  }

  Widget _buildRouterSelector(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark))),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedRouterId.isEmpty ? null : _selectedRouterId,
            isExpanded: true,
            dropdownColor: PaceColors.getCard(isDark),
            icon: const Icon(Icons.wifi_rounded, color: PaceColors.purple),
            items: _routers.map((r) => DropdownMenuItem(value: r['id'].toString(), child: Text(r['router_name'].toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark), letterSpacing: 1)))).toList(),
            onChanged: (val) { setState(() => _selectedRouterId = val!); _fetchPlans(); },
          ),
        ),
      ),
    );
  }

  Widget _buildPlanItem(dynamic plan, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10), 
            decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), 
            child: const Icon(Icons.layers_rounded, color: PaceColors.purple, size: 22)
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan['name']?.toUpperCase() ?? 'UNNAMED', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1)),
                const SizedBox(height: 2),
                Text('${plan['duration']} MINS • ${plan['data_limit'] == '0' ? 'UNLIMITED' : plan['data_limit'] + 'MB'}', style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ],
            ),
          ),
          Text('KES ${plan['price']}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark), fontFamily: 'monospace')),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                title: const Text('Delete Plan?'),
                content: const Text('This will remove the plan from the purchase list.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
                ],
              ));
              if (confirm == true) { await _apiService.deletePlan(plan['id'].toString()); _fetchPlans(); }
            },
            icon: Icon(Icons.delete_outline_rounded, color: Colors.red.withOpacity(0.5), size: 20),
          ),
        ],
      ),
    );
  }
}
