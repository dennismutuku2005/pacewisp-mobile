import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // --- Duration Normalization Logic (Portal Parity) ---
  final Map<String, String> _unitMap = {
    'minute': 'minute', 'minutes': 'minutes', 'min': 'minute',
    'hour': 'hour', 'hours': 'hours', 'hr': 'hour', 'hrs': 'hours',
    'day': 'day', 'days': 'days', 'dy': 'day',
    'week': 'week', 'weeks': 'weeks', 'wk': 'week',
    'month': 'month', 'months': 'months', 'mo': 'month',
  };

  String? normalizeDuration(String raw) {
    if (raw.isEmpty) return null;
    String s = raw.toLowerCase().trim();
    final regex = RegExp(r'(\d+(?:\.\d+)?)\s*([a-z]+)');
    final matches = regex.allMatches(s);
    if (matches.isEmpty) return null;

    List<String> parts = [];
    for (final match in matches) {
      final num = match.group(1)!;
      final unitRaw = match.group(2)!;
      String? unit;
      _unitMap.forEach((key, value) {
        if (unitRaw.startsWith(key) || key.startsWith(unitRaw)) { 
          unit = (double.parse(num) == 1) ? key : value;
        }
      });
      if (unit != null) parts.add('$num $unit');
    }
    return parts.isEmpty ? null : parts.join(' ');
  }

  void _showCreateModal(bool isDark, {Map<String, dynamic>? editingPlan}) {
    final priceController = TextEditingController(text: editingPlan?['price']?.toString());
    final durationController = TextEditingController(text: editingPlan?['duration']?.toString());
    final speedController = TextEditingController(text: editingPlan?['speed']?.toString() ?? 'UNLIMITED');
    final rateLimitController = TextEditingController(text: editingPlan?['rate_limit']?.toString() ?? '6M/6M');
    
    bool isSaving = false;
    String? normalizedPreview = normalizeDuration(durationController.text);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: PaceColors.getBackground(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: PaceColors.getBorder(isDark)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: PaceColors.getBorder(isDark), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text(editingPlan != null ? 'EDIT PLAN' : 'GENERATE NEW PLAN', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              if (_routers.any((r) => r['id'].toString() == _selectedRouterId))
                Text('ROUTER NODE: ${_routers.firstWhere((r) => r['id'].toString() == _selectedRouterId)['router_name']?.toString().toUpperCase()}', 
                  style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
              
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('PRICE (KES)', isDark),
                                _buildTextField(priceController, '10', Icons.payments_outlined, isDark, kType: TextInputType.number, enabled: !isSaving),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('DURATION', isDark),
                                _buildTextField(durationController, 'e.g. 1 hour, 30 min', Icons.timer_outlined, isDark, enabled: !isSaving, onChanged: (v) {
                                  setModalState(() => normalizedPreview = normalizeDuration(v));
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (normalizedPreview != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: PaceColors.emerald.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline, color: PaceColors.emerald, size: 12),
                              const SizedBox(width: 6),
                              Text('PLAN NAME: $normalizedPreview', style: GoogleFonts.figtree(color: PaceColors.emerald, fontSize: 9, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('SPEED IDENTITY', isDark),
                                _buildTextField(speedController, 'UNLIMITED', Icons.speed, isDark, enabled: !isSaving),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('RATE LIMIT', isDark),
                                _buildTextField(rateLimitController, '6M/6M', Icons.network_check, isDark, enabled: !isSaving),
                              ],
                            ),
                          ),
                        ],
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
                    onPressed: (isSaving || priceController.text.isEmpty || normalizedPreview == null) ? null : () async {
                      setModalState(() => isSaving = true);
                      final payload = {
                        'id': editingPlan?['id'],
                        'router_id': _selectedRouterId,
                        'name': normalizedPreview,
                        'price': priceController.text,
                        'duration': durationController.text,
                        'speed': speedController.text.isEmpty ? 'UNLIMITED' : speedController.text,
                        'rate_limit': rateLimitController.text.isEmpty ? '6M/6M' : rateLimitController.text,
                      };
                      
                      final res = await _apiService.createPlan(payload);
                      if (mounted) {
                        Navigator.pop(context);
                        _fetchPlans();
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    child: isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(editingPlan != null ? 'UPDATE PLAN' : 'SAVE PLAN', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
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
    prefixIcon: Icon(icon, color: PaceColors.purple, size: 18),
    filled: true,
    fillColor: PaceColors.getSurface(isDark),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: PaceColors.getBorder(isDark), width: 1.2)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: PaceColors.getBorder(isDark), width: 1.2)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PaceColors.purple, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  Widget _buildLabel(String text, bool isDark) => Padding(padding: const EdgeInsets.only(bottom: 6, left: 4), child: Text(text, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark).withOpacity(0.7), letterSpacing: 1.5)));

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon, bool isDark, {TextInputType kType = TextInputType.text, bool enabled = true, Function(String)? onChanged}) => TextField(
    controller: ctrl, 
    keyboardType: kType,
    enabled: enabled,
    onChanged: onChanged,
    style: GoogleFonts.figtree(color: PaceColors.getPrimaryText(isDark), fontWeight: FontWeight.bold, fontSize: 12),
    decoration: _inputDecoration(icon, isDark).copyWith(hintText: hint, hintStyle: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 11)),
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
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('HOTSPOT PLANS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
              ElevatedButton.icon(
                onPressed: () => _showCreateModal(isDark),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('NEW PLAN', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PaceColors.purple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('PLAN & BANDWIDTH CONTROL', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
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
    return InkWell(
      onTap: () => _showCreateModal(isDark, editingPlan: plan),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10), 
              decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), 
              child: const Icon(Icons.layers_outlined, color: PaceColors.purple, size: 20)
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan['name']?.toString().toUpperCase() ?? 'UNNAMED', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.purple)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(plan['duration']?.toString().toUpperCase() ?? '0 MINS', style: GoogleFonts.figtree(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      const SizedBox(width: 6),
                      Text('•', style: TextStyle(color: PaceColors.getDimText(isDark).withOpacity(0.5))),
                      const SizedBox(width: 6),
                      Text(plan['rate_limit'] ?? '6M/6M', style: GoogleFonts.jetBrainsMono(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('KES ${plan['price']}', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                Text(plan['speed']?.toString().toUpperCase() ?? 'STATIC', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
            const SizedBox(width: 12),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () async {
                final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                  title: const Text('Decommit Plan?'),
                  content: Text('Remove "${plan['name']}" from hotspot configuration?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
                  ],
                ));
                if (confirm == true) { await _apiService.deletePlan(plan['id'].toString()); _fetchPlans(); }
              },
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red.withOpacity(0.4), size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
