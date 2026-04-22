import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
import '../components/search_bar.dart';

class VouchersScreen extends StatefulWidget {
  final bool openModal;
  const VouchersScreen({super.key, this.openModal = false});

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
    if (widget.openModal) {
      Future.delayed(const Duration(milliseconds: 600), _handleCreateVouchers);
    }
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
      final sys = await _apiService.fetchData(slug: 'system_settings'); // Get forced sale settings
      
      if (sys?['status'] == 'success') {
         _isVouchersAsSaleForced = (sys?['data']?['vouchers_as_sale']?.toString() == '1');
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
    final res = await _apiService.fetchData(slug: 'prepaid_vouchers', params: {
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
    final res = await _apiService.fetchData(slug: 'prepaid_plans', params: {'router_id': routerId});
    if (mounted && res?['status'] == 'success') {
       setState(() {
         _plans = res?['plans'] ?? [];
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
        builder: (context, setModalState) {
          final isDark = Provider.of<SettingsProvider>(context).isDarkMode;
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            backgroundColor: PaceColors.getBackground(isDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('GENERATE VOUCHERS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: -0.5)),
                        IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx, false)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildDropdownField('ROUTER NODE', _routers, selectedRouterId, (val) async {
                       setModalState(() { selectedRouterId = val; _plans = []; selectedPlan = null; });
                       if (val != null) {
                         final res = await _apiService.fetchData(slug: 'prepaid_plans', params: {'router_id': val});
                         setModalState(() { _plans = res?['plans'] ?? []; });
                       }
                    }, isDark: isDark),
                    const SizedBox(height: 16),
                    _buildPlanPicker('ACCESS PLAN', _plans, selectedPlan, (val) {
                       setModalState(() { selectedPlan = val; });
                    }, isDark: isDark),
                    const SizedBox(height: 16),
                    _buildCountField('QUANTITY (MAX 50)', (val) => count = int.tryParse(val) ?? 1, isDark: isDark),
                    const SizedBox(height: 24),
                    _buildSaleToggle(isSale, (val) {
                       if (!_isVouchersAsSaleForced) setModalState(() => isSale = val);
                    }, isDark: isDark),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: (selectedRouterId != null && selectedPlan != null) ? () => Navigator.pop(ctx, true) : null,
                            style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: const Text('GENERATE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result == true) {
      setState(() => _isSaving = true);
      try {
        final r = _routers.firstWhere((x) => x['id'].toString() == selectedRouterId);
        final res = await _apiService.fetchData(slug: 'create_vouchers', method: 'POST', body: {
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
        final res = await _apiService.fetchData(slug: 'delete_vouchers', method: 'POST', body: {
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
            Text(value ? 'SALES RECORDING ACTIVE' : 'RECORD AS SALE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: value ? PaceColors.emerald : PaceColors.getPrimaryText(isDark))),
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
            : Column(
                children: [
                  _buildTableHeader(isDark),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _fetchVouchers(pageNum: 1),
                      color: PaceColors.purple,
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        itemCount: _vouchers.length + (_isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark).withOpacity(0.4), height: 1),
                        itemBuilder: (context, index) {
                          if (index == _vouchers.length) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)));
                          return _buildVoucherCard(_vouchers[index], isDark);
                        },
                      ),
                    ),
                  ),
                ],
              ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark).withOpacity(0.3),
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark).withOpacity(0.5))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 36), // Checkbox space
          Expanded(flex: 3, child: Text('VOUCHER & PLAN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
          Expanded(flex: 2, child: Text('STATION', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
          Expanded(flex: 2, child: Text('STATUS', textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.2))),
          const SizedBox(width: 32), // Trash icon space
        ],
      ),
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
              Text('PREPAID VOUCHERS', style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              Text('MULTI-ACCESS HOTSPOT CODES', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
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
                child: PaceSearchBar(
                  hint: 'Search codes...',
                  isDark: isDark,
                  onChanged: (val) { _search = val; _fetchVouchers(pageNum: 1); },
                ),
              ),
            ],
          ),
          if (_selectedVoucherIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), border: Border.all(color: Colors.red.withOpacity(0.1)), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Text('${_selectedVoucherIds.length} SELECTED', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _handleDeleteVouchers(),
                    icon: const Icon(LucideIcons.trash2, size: 12, color: Colors.red),
                    label: const Text('REMOVE ALL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
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



  Widget _buildVoucherCard(dynamic v, bool isDark) {
    final bool isUsed = (v['used']?.toString() == '1');
    final bool isSale = (v['sale']?.toString() == '1');
    final String id = v['id'].toString();
    final bool isSelected = _selectedVoucherIds.contains(id);

    return InkWell(
      onTap: () => _showVoucherDrawer(v, isDark),
      onLongPress: () {
         setState(() {
            if (isSelected) _selectedVoucherIds.remove(id);
            else _selectedVoucherIds.add(id);
         });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        color: isSelected ? PaceColors.purple.withOpacity(0.05) : Colors.transparent,
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              activeColor: PaceColors.purple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              visualDensity: VisualDensity.compact,
              onChanged: (val) {
                setState(() {
                  if (val == true) _selectedVoucherIds.add(id);
                  else _selectedVoucherIds.remove(id);
                });
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v['voucher_code']?.toUpperCase() ?? 'CODE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1.5)),
                  const SizedBox(height: 2),
                  Text(v['plan']?.toUpperCase() ?? 'PLAN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark)), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(v['router_name']?.toString().toUpperCase() ?? 'NODE', style: TextStyle(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PaceBadge(label: isUsed ? 'USED' : 'AVAILABLE', variant: isUsed ? BadgeVariant.secondary : BadgeVariant.success),
                  const SizedBox(height: 4),
                  if (isSale)
                    Text('SALE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.emerald))
                  else
                    const Text('NOT SALE', style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => _handleDeleteVouchers(singleId: id),
              icon: const Icon(LucideIcons.trash2, size: 14, color: Colors.redAccent),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  void _showVoucherDrawer(dynamic v, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getBackground(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('VOUCHER DETAILS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: -0.5)),
                  IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('VOUCHER CODE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
                        const SizedBox(height: 4),
                        Text(v['voucher_code']?.toUpperCase() ?? 'CODE', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark), letterSpacing: 2)),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: v['voucher_code']?.toString() ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voucher code copied to clipboard!')));
                      },
                      icon: const Icon(LucideIcons.copy, color: PaceColors.purple),
                      style: IconButton.styleFrom(backgroundColor: PaceColors.purple.withOpacity(0.1)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildDrawerInfo('PLAN', v['plan']?.toUpperCase() ?? 'N/A', isDark)),
                  Expanded(child: _buildDrawerInfo('ROUTER', v['router_name']?.toString().toUpperCase() ?? 'N/A', isDark)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildDrawerInfo('SALE STATUS', (v['sale']?.toString() == '1') ? 'RECORDED AS SALE' : 'NOT RECORDED AS SALE', isDark, isSaleColor: true)),
                  Expanded(child: _buildDrawerInfo('VOUCHER STATUS', (v['used']?.toString() == '1') ? 'USED' : 'AVAILABLE', isDark)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildDrawerInfo('CREATED AT', v['created_at']?.toString() ?? 'N/A', isDark)),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawerInfo(String label, String value, bool isDark, {bool isSaleColor = false}) {
    Color valColor = PaceColors.getPrimaryText(isDark);
    if (isSaleColor) {
      if (value.contains('NOT')) {
        valColor = Colors.red;
      } else {
        valColor = PaceColors.emerald;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: valColor)),
      ],
    );
  }
}
