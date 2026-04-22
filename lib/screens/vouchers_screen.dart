import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _vouchers = [];
  List<dynamic> _routers = [];
  List<dynamic> _plans = [];
  final Set<String> _selectedVoucherIds = {};
  
  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isSaving = false;
  bool _isVouchersAsSaleForced = false;
  
  String _activeRouterId = 'all';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreVouchers();
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getRouters(forceRefresh: true);
      final sys = await _apiService.fetchData('system_settings'); // Get forced sale settings
      
      if (sys?['status'] == 'success') {
         _isVouchersAsSaleForced = (sys['data']?['vouchers_as_sale']?.toString() == '1');
      }

      if (res != null) {
        _routers = res['data'] ?? [];
        await _fetchVouchers(pageNum: 1);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchVouchers({required int pageNum}) async {
    final res = await _apiService.fetchData('prepaid_vouchers', params: {
      'page': pageNum,
      'limit': 15,
      'search': _search,
      'router_id': _activeRouterId
    });

    if (mounted && res?['status'] == 'success') {
      setState(() {
        if (pageNum == 1) {
          _vouchers = res?['data'] ?? [];
        } else {
          _vouchers.addAll(res?['data'] ?? []);
        }
        _hasMore = res?['pagination']?['has_more'] ?? false;
        _page = pageNum;
      });
    }
  }

  Future<void> _loadMoreVouchers() async {
    setState(() => _isLoadingMore = true);
    try {
      await _fetchVouchers(pageNum: _page + 1);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadRouterPlans(String routerId) async {
    final res = await _apiService.fetchData('prepaid_plans', params: {'router_id': routerId});
    if (mounted && res?['status'] == 'success') {
       setState(() {
         _plans = res['plans'] ?? [];
       });
    }
  }

  Future<void> _handleCreateVouchers() async {
    String? selectedRouterId = _activeRouterId == 'all' ? null : _activeRouterId;
    String? selectedPlan;
    int count = 1;
    bool isSale = _isVouchersAsSaleForced;

    if (selectedRouterId != null) await _loadRouterPlans(selectedRouterId);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: PaceColors.getBackground(Provider.of<SettingsProvider>(context).isDarkMode),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('GENERATE VOUCHERS', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.purple)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDropdownField('ROUTER NODE', _routers, selectedRouterId, (val) async {
                   setModalState(() { selectedRouterId = val; _plans = []; selectedPlan = null; });
                   if (val != null) {
                     final res = await _apiService.fetchData('prepaid_plans', params: {'router_id': val});
                     setModalState(() { _plans = res?['plans'] ?? []; });
                   }
                }, isDark: Provider.of<SettingsProvider>(context).isDarkMode),
                const SizedBox(height: 16),
                _buildPlanPicker('ACCESS PLAN', _plans, selectedPlan, (val) {
                   setModalState(() { selectedPlan = val; });
                }, isDark: Provider.of<SettingsProvider>(context).isDarkMode),
                const SizedBox(height: 16),
                _buildCountField('QUANTITY (MAX 50)', (val) => count = int.tryParse(val) ?? 1, isDark: Provider.of<SettingsProvider>(context).isDarkMode),
                const SizedBox(height: 24),
                _buildSaleToggle(isSale, (val) {
                   if (!_isVouchersAsSaleForced) setModalState(() => isSale = val);
                }, isDark: Provider.of<SettingsProvider>(context).isDarkMode),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: (selectedRouterId != null && selectedPlan != null) ? () => Navigator.pop(ctx, true) : null,
              style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('GENERATE', style: GoogleFonts.figtree(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() => _isSaving = true);
      try {
        final r = _routers.firstWhere((x) => x['id'].toString() == selectedRouterId);
        final res = await _apiService.fetchData('create_vouchers', method: 'POST', body: {
          'router_name': r['router_name'],
          'plan': selectedPlan,
          'count': count,
          'sale': isSale ? 1 : 0
        });

        if (res?['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count vouchers generated successfully'), backgroundColor: PaceColors.emerald));
          _fetchVouchers(pageNum: 1);
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleDeleteVouchers({String? singleId}) async {
    final List<String> idsToDelete = singleId != null ? [singleId] : _selectedVoucherIds.toList();
    if (idsToDelete.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getBackground(Provider.of<SettingsProvider>(context).isDarkMode),
        title: Text('DELETE VOUCHERS', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('Permanently remove ${idsToDelete.length} selected vouchers? This action cannot be undone.', style: GoogleFonts.figtree(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE ALL', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      try {
        final res = await _apiService.fetchData('delete_vouchers', method: 'POST', body: {
          'voucher_ids': idsToDelete, // Map to portal's delete expectations
          'ids': idsToDelete
        });

        if (res?['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vouchers deleted successfully'), backgroundColor: Colors.black));
          _selectedVoucherIds.clear();
          _fetchVouchers(pageNum: 1);
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildDropdownField(String label, List<dynamic> options, String? value, Function(String?) onChanged, {required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: PaceColors.getBorder(isDark))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: Text('Select Router', style: TextStyle(fontSize: 12, color: PaceColors.getDimText(isDark))),
              items: options.map((r) => DropdownMenuItem<String>(value: r['id'].toString(), child: Text(r['router_name'].toString().toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanPicker(String label, List<dynamic> plans, String? value, Function(String?) onChanged, {required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: PaceColors.getBorder(isDark))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: Text(plans.isEmpty ? 'Loading Plans...' : 'Select Plan', style: TextStyle(fontSize: 12, color: PaceColors.getDimText(isDark))),
              items: plans.map((p) => DropdownMenuItem<String>(value: p['name'].toString(), child: Text('${p['name']} - KES ${p['price']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountField(String label, Function(String) onChanged, {required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: PaceColors.getBorder(isDark))),
          child: TextField(
            onChanged: onChanged,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(hintText: '1', border: InputBorder.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSaleToggle(bool value, Function(bool) onChanged, {required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value ? PaceColors.emerald.withOpacity(0.05) : PaceColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: value ? PaceColors.emerald.withOpacity(0.3) : PaceColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value ? 'SALES RECORDING ACTIVE' : 'RECORD AS SALE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.black, color: value ? PaceColors.emerald : PaceColors.getPrimaryText(isDark))),
            Text(value ? 'FORCED BY SYSTEM POLICY' : 'Creates an income entry on use', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark))),
          ])),
          Switch(
            value: value,
            onChanged: _isVouchersAsSaleForced ? null : onChanged,
            activeColor: Colors.white,
            activeTrackColor: PaceColors.emerald,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Column(
      children: [
        _buildHeader(isDark),
        _buildControls(isDark),
        Expanded(
          child: _isLoading 
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 10))
            : RefreshIndicator(
                onRefresh: () => _fetchVouchers(pageNum: 1),
                color: PaceColors.purple,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: _vouchers.length + (_isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == _vouchers.length) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)));
                    return _buildVoucherCard(_vouchers[index], isDark);
                  },
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PREPAID VOUCHERS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
              Text('MULTI-ACCESS HOTSPOT CODES', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ],
          ),
          IconButton(
            onPressed: () => _handleCreateVouchers(),
            icon: const Icon(LucideIcons.plusCircle, color: PaceColors.purple, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: PaceColors.getBorder(isDark))),
                  child: TextField(
                    onChanged: (val) { _search = val; _fetchVouchers(pageNum: 1); },
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(hintText: 'Search codes...', icon: Icon(LucideIcons.search, size: 14, color: PaceColors.getDimText(isDark)), border: InputBorder.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildMiniRouterPicker(isDark),
            ],
          ),
          if (_selectedVoucherIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), border: Border.all(color: Colors.red.withOpacity(0.1)), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Text('${_selectedVoucherIds.length} SELECTED', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.black, color: Colors.red)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _handleDeleteVouchers(),
                    icon: const Icon(LucideIcons.trash2, size: 12, color: Colors.red),
                    label: Text('REMOVE ALL', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                  ),
                  IconButton(onPressed: () => setState(() => _selectedVoucherIds.clear()), icon: const Icon(LucideIcons.x, size: 14, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniRouterPicker(bool isDark) {
    final activeName = _activeRouterId == 'all' ? 'ALL' : _routers.firstWhere((r) => r['id'].toString() == _activeRouterId, orElse: () => {'router_name': 'NODE'})['router_name'];
    return InkWell(
      onTap: () => _showRouterPicker(isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: PaceColors.purple.withOpacity(0.2))),
        child: Row(children: [Text(activeName.toString().toUpperCase(), style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.black, color: PaceColors.purple)), const SizedBox(width: 4), const Icon(LucideIcons.chevronDown, size: 10, color: PaceColors.purple)]),
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
          children: [
            ListTile(
              leading: Icon(LucideIcons.globe, color: _activeRouterId == 'all' ? PaceColors.purple : Colors.grey),
              title: const Text('ALL ROUTERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onTap: () { setState(() => _activeRouterId = 'all'); Navigator.pop(context); _fetchVouchers(pageNum: 1); },
            ),
            ..._routers.map((r) => ListTile(
              leading: Icon(LucideIcons.router, color: r['id'].toString() == _activeRouterId ? PaceColors.purple : Colors.grey),
              title: Text(r['router_name']?.toUpperCase() ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onTap: () { setState(() => _activeRouterId = r['id'].toString()); Navigator.pop(context); _fetchVouchers(pageNum: 1); },
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherCard(dynamic v, bool isDark) {
    final bool isUsed = (v['used']?.toString() == '1');
    final bool isSale = (v['sale']?.toString() == '1');
    final String id = v['id'].toString();
    final bool isSelected = _selectedVoucherIds.contains(id);

    return InkWell(
      onLongPress: () {
         setState(() {
            if (isSelected) _selectedVoucherIds.remove(id);
            else _selectedVoucherIds.add(id);
         });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? PaceColors.purple.withOpacity(0.05) : PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? PaceColors.purple : PaceColors.getBorder(isDark)),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              activeColor: PaceColors.purple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (val) {
                setState(() {
                  if (val == true) _selectedVoucherIds.add(id);
                  else _selectedVoucherIds.remove(id);
                });
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v['voucher_code']?.toUpperCase() ?? 'CODE', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.black, color: PaceColors.purple, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(v['plan']?.toUpperCase() ?? 'PLAN', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
                      const SizedBox(width: 8),
                      Container(width: 3, height: 3, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(v['router_name']?.toString().toUpperCase() ?? 'NODE', style: GoogleFonts.figtree(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PaceBadge(label: isUsed ? 'USED' : 'AVAILABLE', variant: isUsed ? BadgeVariant.secondary : BadgeVariant.success),
                const SizedBox(height: 6),
                if (isSale)
                  Row(
                     children: [
                       const Icon(LucideIcons.checkCircle2, size: 10, color: PaceColors.emerald),
                       const SizedBox(width: 4),
                       Text('SALE RECORDED', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.black, color: PaceColors.emerald)),
                     ],
                  )
                else
                  Text(v['created_at'] ?? '', style: GoogleFonts.figtree(fontSize: 7, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _handleDeleteVouchers(singleId: id),
              icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }
}
