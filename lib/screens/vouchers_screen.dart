import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

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
  final Set<String> _selectedIds = {};
  
  int _page = 1;
  int _total = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _search = '';
  String _selectedRouterName = 'all';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchMoreVouchers();
      }
    }
  }

  Future<void> _fetchInitialData() async {
    debugPrint('[VOUCHER] Fetching initial data...');
    if (mounted) setState(() => _isLoading = true);
    
    // Web loadInitialData logic: fetch all routers first
    final routersRes = await _apiService.getRouters();
    if (mounted) {
      final rawData = routersRes?['data'];
      if (rawData is List) {
        _routers = rawData;
      } else {
        _routers = routersRes?['routers'] ?? [];
      }
      debugPrint('[VOUCHER] Loaded ${_routers.length} routers');
    }

    // Now fetch vouchers (force refresh to ensure we see them)
    await _fetchVouchers(page: 1, forceRefresh: true);
    
    // Auto-open modal if requested
    if (widget.openModal && mounted) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      _showCreateModal(isDark);
    }
  }

  Future<void> _fetchVouchers({int page = 1, bool forceRefresh = false}) async {
    debugPrint('[VOUCHER] Fetching vouchers page $page (router: $_selectedRouterName, search: $_search)...');
    if (page == 1) {
      if (mounted) setState(() => _isLoading = true);
    } else {
      if (mounted) setState(() => _isLoadingMore = true);
    }

    final res = await _apiService.getVouchers(
      search: _search, 
      page: page, 
      router: _selectedRouterName == 'all' ? null : _selectedRouterName, 
      forceRefresh: forceRefresh
    );

    if (mounted) {
      setState(() {
        final rawData = res?['data'];
        final List<dynamic> newVouchers = (rawData is List) ? rawData : (res?['vouchers'] ?? []);
        
        if (page == 1) {
          _vouchers = newVouchers;
        } else {
          _vouchers.addAll(newVouchers);
        }
        _hasMore = res?['pagination']?['has_more'] ?? res?['data']?['pagination']?['has_more'] ?? false;
        _total = res?['pagination']?['total'] ?? res?['data']?['pagination']?['total'] ?? 0;
        _page = page;
        _isLoading = false;
        _isLoadingMore = false;
        _selectedIds.clear();
      });
      debugPrint('[VOUCHER] Loaded ${_vouchers.length} vouchers total (HasMore: $_hasMore, Total: $_total)');
    }
  }

  Future<void> _fetchMoreVouchers() async {
    await _fetchVouchers(page: _page + 1);
  }

  void _showCreateModal(bool isDark) async {
    String? selectedRouter = _selectedRouterName == 'all' ? null : _selectedRouterName;
    String? selectedPlan;
    int quantity = 1;
    bool isModalLoading = false;

    // Helper to load plans for a router name
    Future<void> loadPlans(String? rName, Function setModalState) async {
      if (rName == null || rName == 'all') return;
      final router = _routers.find((r) => r['router_name'] == rName);
      if (router == null) return;
      
      setModalState(() { isModalLoading = true; selectedPlan = null; });
      final plansRes = await _apiService.getPlans(router['id'].toString());
      if (mounted) {
        setModalState(() {
          _plans = plansRes?['data']?['plans'] ?? plansRes?['plans'] ?? plansRes?['data'] ?? [];
          isModalLoading = false;
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final modalIsDark = Theme.of(context).brightness == Brightness.dark;
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: BoxDecoration(
              color: PaceColors.getBackground(modalIsDark),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: PaceColors.getBorder(modalIsDark)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: PaceColors.getBorder(modalIsDark), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                Text('NEW ASSET GENERATION', style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1.5)),
                const SizedBox(height: 32),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildModalLabel('TARGET ROUTER NODE', modalIsDark),
                        _buildModalDropdown(
                          isDark: modalIsDark,
                          value: selectedRouter,
                          items: _routers.map((r) => DropdownMenuItem(value: r['router_name'].toString(), child: Text(r['router_name'].toString().toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))).toList(),
                          onChanged: (val) => loadPlans(val, setModalState).then((_) => setModalState(() => selectedRouter = val)),
                        ),
                        const SizedBox(height: 24),
                        _buildModalLabel('ACCESS PLAN TIER', modalIsDark),
                        isModalLoading 
                          ? const PaceSkeleton(height: 56)
                          : _buildModalDropdown(
                              isDark: modalIsDark,
                              value: selectedPlan,
                              items: _plans.map((p) => DropdownMenuItem(value: p['name'].toString(), child: Text('${p['name'].toString().toUpperCase()} - KES ${p['price']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))).toList(),
                              onChanged: (val) => setModalState(() => selectedPlan = val),
                            ),
                        const SizedBox(height: 32),
                        _buildModalLabel('BULK QUANTITY (MAX 50)', modalIsDark),
                        Row(
                          children: [
                            _buildSpinButton(Icons.remove, () => setModalState(() { if (quantity > 1) quantity--; }), modalIsDark),
                            Expanded(
                              child: Center(child: Text(quantity.toString().padLeft(2, '0'), style: GoogleFonts.jetBrainsMono(fontSize: 32, fontWeight: FontWeight.w900, color: PaceColors.purple))),
                            ),
                            _buildSpinButton(Icons.add, () => setModalState(() { if (quantity < 50) quantity++; }), modalIsDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (selectedRouter == null || selectedPlan == null || isModalLoading) ? null : () async {
                        setModalState(() => isModalLoading = true);
                        final success = await _handleCreate(selectedRouter!, selectedPlan!, quantity);
                        if (mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PaceColors.purple, 
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: isModalLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('GENERATE VOUCHERS', style: GoogleFonts.figtree(fontWeight: FontWeight.w900, letterSpacing: 2)),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Future<bool> _handleCreate(String routerName, String planName, int count) async {
    final res = await _apiService.createVoucher({'router_name': routerName, 'plan': planName, 'count': count});
    if (res?['status'] == 'success') {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vouchers generated successfully!'), backgroundColor: Colors.green));
      _fetchVouchers(page: 1, forceRefresh: true);
      return true;
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Failed to generate vouchers'), backgroundColor: Colors.red));
      return false;
    }
  }

  Future<void> _handleDelete(List<String> ids) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Asset', style: GoogleFonts.figtree(fontWeight: FontWeight.bold)),
        content: Text('Remove ${ids.length} selected voucher(s)? This action is irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _apiService.deleteVouchers(ids);
      if (res?['status'] == 'success') {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ids.length} Vouchers removed.')));
        _fetchVouchers(page: 1, forceRefresh: true);
      }
    }
  }

  Widget _buildModalLabel(String label, bool isDark) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(label, style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 2)));

  Widget _buildModalDropdown({required bool isDark, required String? value, required List<DropdownMenuItem<String>> items, required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: PaceColors.getCard(isDark),
          hint: Text('Select Option...', style: TextStyle(fontSize: 13, color: PaceColors.getSecondaryText(isDark), fontWeight: FontWeight.bold)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSpinButton(IconData icon, VoidCallback onTap, bool isDark) => GestureDetector(
    onTap: onTap, 
    child: Container(
      padding: const EdgeInsets.all(16), 
      decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(20)), 
      child: Icon(icon, color: PaceColors.purple, size: 28)
    )
  );

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Container(
      color: PaceColors.getBackground(isDark),
      child: Column(
        children: [
          _buildPortalHeader(isDark),
          _buildControlBar(isDark),
          _buildPortalTableHeader(isDark),
          Expanded(
            child: _isLoading 
              ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 8))
              : _vouchers.isEmpty 
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                      onRefresh: () => _fetchVouchers(page: 1, forceRefresh: true),
                      color: PaceColors.purple,
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
                        itemCount: _vouchers.length + (_isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                        itemBuilder: (context, index) {
                          if (index == _vouchers.length) return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)));
                          return _buildPortalVoucherItem(_vouchers[index], isDark);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortalHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: PaceColors.getBackground(isDark),
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PREPAID VOUCHERS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              Row(
                children: [
                  Text('ROUTER: ', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
                    child: Text(_selectedRouterName.toUpperCase(), style: const TextStyle(color: PaceColors.purple, fontSize: 8, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 8),
                  Text('TOTAL: ', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w900)),
                  Text(_total.toString(), style: const TextStyle(color: PaceColors.purple, fontSize: 10, fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _showCreateModal(isDark),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('GENERATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(
              backgroundColor: PaceColors.purple, 
              foregroundColor: Colors.white, 
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: PaceColors.getSurface(isDark), 
                    borderRadius: BorderRadius.circular(12), 
                    border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)
                  ),
                  child: TextField(
                    onChanged: (val) { _search = val; _fetchVouchers(page: 1); },
                    style: TextStyle(color: PaceColors.getPrimaryText(isDark), fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'Lookup PIN code...', 
                      hintStyle: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 12), 
                      border: InputBorder.none, 
                      icon: Icon(Icons.search_rounded, size: 18, color: PaceColors.getDimText(isDark))
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: PaceColors.getSurface(isDark), 
                  borderRadius: BorderRadius.circular(12), 
                  border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRouterName,
                    dropdownColor: PaceColors.getCard(isDark),
                    icon: const Icon(Icons.router_rounded, size: 14, color: PaceColors.purple),
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('ALL ROUTERS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark)))),
                      ..._routers.map((r) => DropdownMenuItem(value: r['router_name'].toString(), child: Text(r['router_name'].toString().toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark))))),
                    ],
                    onChanged: (val) { setState(() => _selectedRouterName = val!); _fetchVouchers(page: 1); },
                  ),
                ),
              ),
            ],
          ),
          if (_selectedIds.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), border: Border.all(color: Colors.red.withOpacity(0.1)), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Text('${_selectedIds.length} ASSETS SELECTED', style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _handleDelete(_selectedIds.toList()),
                    icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Colors.red),
                    label: const Text('DELETE', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPortalTableHeader(bool isDark) {
    return Container(
      color: PaceColors.getSurface(isDark),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Checkbox(
              value: _vouchers.isNotEmpty && _selectedIds.length == _vouchers.length,
              onChanged: (val) {
                setState(() {
                  if (val == true) _selectedIds.addAll(_vouchers.map((v) => v['id'].toString()));
                  else _selectedIds.clear();
                });
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              activeColor: PaceColors.purple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: Text('VOUCHER ASSET', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
          Expanded(flex: 2, child: Center(child: Text('STATUS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1)))),
          Expanded(flex: 2, child: Text('ROUTER', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
        ],
      ),
    );
  }

  Widget _buildPortalVoucherItem(dynamic voucher, bool isDark) {
    final String id = voucher['id'].toString();
    final bool isSelected = _selectedIds.contains(id);
    final status = (voucher['status']?.toString() ?? '').toLowerCase();
    final usedFlag = voucher['used'];
    final bool isUsed = status == 'used' || status == 'exhausted' || usedFlag == 1 || usedFlag == '1';
    
    return InkWell(
      onTap: () => setState(() => isSelected ? _selectedIds.remove(id) : _selectedIds.add(id)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? PaceColors.purple.withOpacity(0.04) : null,
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Checkbox(
                value: isSelected,
                onChanged: (val) => setState(() => val == true ? _selectedIds.add(id) : _selectedIds.remove(id)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                activeColor: PaceColors.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(voucher['voucher_code'] ?? 'NULL', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1.5)),
                  Text(voucher['plan']?.toUpperCase() ?? 'ACCESS PLAN', style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: PaceBadge(
                  label: isUsed ? 'USED' : 'ACTIVE', 
                  variant: isUsed ? BadgeVariant.secondary : BadgeVariant.success,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(voucher['router_name']?.toUpperCase() ?? 'DEFAULT', style: TextStyle(fontSize: 10, color: PaceColors.getPrimaryText(isDark), fontWeight: FontWeight.w900)),
                  Text(voucher['created_at']?.split(' ')[0] ?? '', style: TextStyle(fontSize: 8, color: PaceColors.getDimText(isDark))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.airplane_ticket_rounded, size: 64, color: PaceColors.getDimText(isDark).withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('NO ASSETS DISCOVERED', style: GoogleFonts.figtree(fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark).withOpacity(0.5), letterSpacing: 2, fontSize: 12)),
          const SizedBox(height: 8),
          Text('Try adjusting filters or create a new batch.', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 11)),
        ],
      ),
    );
  }
}

extension ListFind<T> on List<T> {
  T? find(bool Function(T) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}
