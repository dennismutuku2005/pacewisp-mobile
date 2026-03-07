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
  final Set<String> _selectedIds = {};
  
  int _page = 1;
  int _total = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _search = '';
  String _selectedRouterId = 'all'; // Store ID instead of Name for better sync

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
    debugPrint('[VOUCHERS] Initializing...');
    if (mounted) setState(() => _isLoading = true);
    
    try {
      final routersRes = await _apiService.getRouters(forceRefresh: true);
      if (mounted) {
        final dynamic raw = routersRes?['data'] ?? routersRes?['routers'];
        if (raw is List) {
          final Set<String> uniqueIds = {};
          _routers = [];
          for (var r in raw) {
            final id = (r is Map) ? r['id']?.toString() : null;
            if (id != null && !uniqueIds.contains(id)) {
              uniqueIds.add(id);
              _routers.add(r);
            }
          }
        }
        debugPrint('[VOUCHERS] Loaded ${_routers.length} nodes');
      }
    } catch (e) {
      debugPrint('[VOUCHERS] Error loading nodes: $e');
    }

    await _fetchVouchers(page: 1, forceRefresh: true);
    
    if (widget.openModal && mounted) {
      final isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;
      _showCreateModal(isDark);
    }
  }

  Future<void> _fetchVouchers({int page = 1, bool forceRefresh = false}) async {
    if (page == 1) {
      if (mounted) setState(() => _isLoading = true);
    } else {
      if (mounted) setState(() => _isLoadingMore = true);
    }

    // Get current router name for legacy compatibility if needed
    String? rName;
    if (_selectedRouterId != 'all') {
      final r = _routers.firstWhere((element) => element['id'].toString() == _selectedRouterId, orElse: () => null);
      rName = r?['router_name'] ?? r?['name'] ?? r?['router'];
    }

    final res = await _apiService.getVouchers(
      search: _search, 
      page: page, 
      router: rName, 
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
    }
  }

  Future<void> _fetchMoreVouchers() async {
    await _fetchVouchers(page: _page + 1);
  }

  void _showCreateModal(bool isDark) async {
    String? currentRouterId = _selectedRouterId == 'all' ? null : _selectedRouterId;
    String? currentRouterName;
    String? selectedPlan;
    int quantity = 1;
    bool isModalLoading = false;
    List<dynamic> modalPlans = [];

    // Helper to resolve name from ID
    void resolveName() {
      if (currentRouterId != null) {
        final r = _routers.firstWhere((element) => element['id'].toString() == currentRouterId, orElse: () => null);
        currentRouterName = r?['router_name'] ?? r?['name'] ?? r?['router'];
      }
    }
    resolveName();

    Future<void> loadModalPlans(String? rId, Function setModalState) async {
      if (rId == null || rId == 'all') {
        setModalState(() { modalPlans = []; selectedPlan = null; isModalLoading = false; });
        return;
      }
      
      setModalState(() { isModalLoading = true; selectedPlan = null; });
      debugPrint('[VOUCHERS] Fetching plans for router_id: $rId');

      final plansRes = await _apiService.getPlans(rId);
      if (mounted) {
        setModalState(() {
          final dynamic raw = plansRes?['plans'] ?? plansRes?['data']?['plans'] ?? plansRes?['data'] ?? [];
          final allPlans = (raw is List) ? raw : [];
          
          final Set<String> uniquePlanNames = {};
          modalPlans = [];
          for (var p in allPlans) {
            if (p is Map) {
              final pName = p['name']?.toString();
              if (pName != null && pName.isNotEmpty && !uniquePlanNames.contains(pName)) {
                uniquePlanNames.add(pName);
                modalPlans.add(p);
              }
            }
          }

          if (modalPlans.isNotEmpty) {
            selectedPlan = modalPlans[0]['name']?.toString();
          } else {
            selectedPlan = null;
          }
          isModalLoading = false;
        });
      }
    }

    if (currentRouterId != null) {
       Future.delayed(Duration.zero, () {
        loadModalPlans(currentRouterId, (fn) => fn());
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: BoxDecoration(
              color: PaceColors.getBackground(isDark),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: PaceColors.getBorder(isDark), width: 1),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: PaceColors.getBorder(isDark).withOpacity(0.5), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text('GENERATE MULTI-ACCESS VOUCHERS', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1.5)),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildModalLabel('Select Router Node', isDark),
                        _buildModalDropdown(
                          isDark: isDark,
                          value: currentRouterId,
                          items: _routers.map((r) {
                            final name = (r['router_name'] ?? r['name'] ?? r['router'])?.toString();
                            return DropdownMenuItem<String>(value: r['id'].toString(), child: Text(name?.toUpperCase() ?? 'UNKNOWN', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))));
                          }).toList(),
                          onChanged: (val) {
                            setModalState(() => currentRouterId = val);
                            resolveName();
                            loadModalPlans(val, setModalState);
                          },
                        ),
                        const SizedBox(height: 20),
                        _buildModalLabel('Select Access Plan', isDark),
                        isModalLoading 
                          ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: PaceSkeleton(height: 48))
                          : _buildModalDropdown(
                              isDark: isDark,
                              value: selectedPlan,
                              items: modalPlans.map((p) {
                                final pName = p['name']?.toString() ?? 'PLAN';
                                final pPrice = (p['price'] ?? p['amount'] ?? '0').toString();
                                return DropdownMenuItem<String>(value: pName, child: Text('${pName.toUpperCase()} — KES $pPrice', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))));
                              }).toList(),
                              onChanged: (val) => setModalState(() => selectedPlan = val),
                            ),
                        const SizedBox(height: 24),
                        _buildModalLabel('Bulk Quantity', isDark),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: PaceColors.getSurface(isDark), 
                            borderRadius: BorderRadius.circular(12), 
                            border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('Count: ${quantity.toString().padLeft(2, '0')}', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                              ),
                              _buildSpinAction(Icons.remove_rounded, () => setModalState(() { if (quantity > 1) quantity--; }), isDark),
                              const SizedBox(width: 8),
                              _buildSpinAction(Icons.add_rounded, () => setModalState(() { if (quantity < 50) quantity++; }), isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Generate up to 50 unique vouchers at once.', style: GoogleFonts.figtree(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('CANCEL', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: (currentRouterName == null || selectedPlan == null || isModalLoading) ? null : () async {
                              setModalState(() => isModalLoading = true);
                              final success = await _handleCreate(currentRouterName!, selectedPlan!, quantity);
                              if (success && mounted) Navigator.pop(context);
                              else if (mounted) setModalState(() => isModalLoading = false);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PaceColors.purple, 
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isModalLoading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    Text('GENERATE VOUCHERS', style: GoogleFonts.figtree(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 11)),
                                  ],
                                ),
                          ),
                        ),
                      ),
                    ],
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Action Failed'), backgroundColor: Colors.red));
      return false;
    }
  }

  Future<void> _handleDelete(List<String> ids) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getCard(Provider.of<SettingsProvider>(context, listen: false).isDarkMode),
        title: Text('Delete Vouchers', style: GoogleFonts.figtree(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Text('This will permanently remove ${ids.length} voucher(s). Confirm?', style: GoogleFonts.figtree(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('CANCEL', style: GoogleFonts.figtree(color: PaceColors.getDimText(true), fontSize: 12))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('DELETE', style: GoogleFonts.figtree(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _apiService.deleteVouchers(ids);
      if (res?['status'] == 'success') {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vouchers removed.')));
        _fetchVouchers(page: 1, forceRefresh: true);
      }
    }
  }

  Widget _buildModalLabel(String label, bool isDark) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(label, style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 0.5)));

  Widget _buildModalDropdown({required bool isDark, required String? value, required List<DropdownMenuItem<String>> items, required Function(String?) onChanged}) {
    String? effectiveValue;
    if (value != null && items.any((item) => item.value == value)) {
      effectiveValue = value;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isExpanded: true,
          dropdownColor: PaceColors.getCard(isDark),
          hint: Text('Select...', style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
          items: items.isEmpty ? null : items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSpinAction(IconData icon, VoidCallback onTap, bool isDark) => InkWell(
    onTap: onTap, 
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.all(8), 
      decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), 
      child: Icon(icon, color: PaceColors.purple, size: 20)
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
              ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 10))
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
              Text('Prepaid Vouchers', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
              Row(
                children: [
                   Text('SELECTED NODE: ', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold)),
                  Text(_selectedRouterId == 'all' ? 'ALL STATIONS' : (_routers.firstWhere((e) => e['id'].toString() == _selectedRouterId, orElse: () => {'router_name': 'NODE'})['router_name']?.toString().toUpperCase() ?? 'NODE'), style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('TOTAL: ', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold)),
                  Text(_total.toString(), style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _showCreateModal(isDark),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text('NEW VOUCHER', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: PaceColors.purple, 
              foregroundColor: Colors.white, 
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)
                  ),
                  child: TextField(
                    onChanged: (val) { _search = val; _fetchVouchers(page: 1); },
                    style: GoogleFonts.figtree(color: PaceColors.getPrimaryText(isDark), fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'Search vouchers...', 
                      hintStyle: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 12), 
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
                  border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRouterId,
                    dropdownColor: PaceColors.getCard(isDark),
                    icon: const Icon(Icons.wifi_tethering_rounded, size: 14, color: PaceColors.purple),
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('ALL STATIONS', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)))),
                      ..._routers.map((r) {
                        final name = (r['router_name'] ?? r['name'] ?? r['router'])?.toString();
                        return DropdownMenuItem(value: r['id'].toString(), child: Text(name?.toUpperCase() ?? 'NODE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))));
                      }),
                    ],
                    onChanged: (val) { setState(() => _selectedRouterId = val!); _fetchVouchers(page: 1); },
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
                   Text('SELECTED: ${_selectedIds.length}', style: GoogleFonts.figtree(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _handleDelete(_selectedIds.toList()),
                    icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Colors.red),
                    label: Text('DELETE SELECTED', style: GoogleFonts.figtree(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
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
          Expanded(flex: 3, child: Text('Voucher PIN', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 0.5))),
          Expanded(flex: 2, child: Center(child: Text('Status', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 0.5)))),
          Expanded(flex: 2, child: Text('Station', textAlign: TextAlign.right, style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 0.5))),
        ],
      ),
    );
  }

  Widget _buildPortalVoucherItem(dynamic voucher, bool isDark) {
     final String id = voucher['id']?.toString() ?? '0';
    final bool isSelected = _selectedIds.contains(id);
    final status = (voucher['status']?.toString() ?? '').toLowerCase();
    final usedFlag = voucher['used'];
    final bool isUsed = status == 'used' || status == 'exhausted' || usedFlag == 1 || usedFlag == '1' || usedFlag == true;
    
    return InkWell(
      onTap: () => setState(() => isSelected ? _selectedIds.remove(id) : _selectedIds.add(id)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  Text(voucher['voucher_code'] ?? 'NULL', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1.5)),
                  Text(voucher['plan']?.toString().toUpperCase() ?? 'PLAN', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: PaceBadge(
                  label: isUsed ? 'Used' : 'Available', 
                  variant: isUsed ? BadgeVariant.secondary : BadgeVariant.success,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(voucher['router_name']?.toString().toUpperCase() ?? 'STATION', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getPrimaryText(isDark), fontWeight: FontWeight.bold)),
                  Text(voucher['created_at']?.split(' ')[0] ?? '', style: GoogleFonts.figtree(fontSize: 7, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.normal)),
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
          Icon(Icons.airplane_ticket_rounded, size: 48, color: PaceColors.getDimText(isDark).withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('NO VOUCHERS FOUND', style: GoogleFonts.figtree(fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark).withOpacity(0.5), letterSpacing: 2, fontSize: 10)),
        ],
      ),
    );
  }
}
