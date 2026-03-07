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
    debugPrint('[VOUCHER] Initializing screen...');
    if (mounted) setState(() => _isLoading = true);
    
    try {
      final routersRes = await _apiService.getRouters(forceRefresh: true);
      if (mounted) {
        final dynamic raw = routersRes?['data'] ?? routersRes?['routers'];
        if (raw is List) {
          final Set<String> uniqueNames = {};
          _routers = [];
          for (var r in raw) {
            final name = (r is Map) ? (r['name'] ?? r['router_name'] ?? r['router'])?.toString() : r.toString();
            if (name != null) {
              final lower = name.toLowerCase().trim();
              if (lower != 'all' && lower != 'all routers' && lower != 'any' && !uniqueNames.contains(lower)) {
                uniqueNames.add(lower);
                _routers.add(r);
              }
            }
          }
        }
        debugPrint('[VOUCHER] Fetched ${_routers.length} nodes');
      }
    } catch (e) {
      debugPrint('[VOUCHER] Error loading routers: $e');
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
    List<dynamic> modalPlans = [];

    Future<void> loadModalPlans(String? rName, Function setModalState) async {
      if (rName == null || rName == 'all') {
        setModalState(() { modalPlans = []; selectedPlan = null; isModalLoading = false; });
        return;
      }
      
      setModalState(() { isModalLoading = true; selectedPlan = null; });
      debugPrint('[VOUCHER] Loading plans for node: $rName');
      
      String? routerId;
      for (var r in _routers) {
        final name = (r is Map) ? (r['name'] ?? r['router_name'] ?? r['router'])?.toString() : r.toString();
        if (name == rName) {
          routerId = (r is Map) ? (r['id'] ?? r['router_id'])?.toString() : r.toString();
          break;
        }
      }
      
      if (routerId == null) {
        setModalState(() => isModalLoading = false);
        return;
      }

      final plansRes = await _apiService.getPlans(routerId);
      if (mounted) {
        setModalState(() {
          final raw = plansRes?['data']?['plans'] ?? plansRes?['plans'] ?? plansRes?['data'] ?? [];
          final allPlans = (raw is List) ? raw : [];
          
          // De-duplicate plans by name
          final Set<String> uniquePlanNames = {};
          modalPlans = [];
          for (var p in allPlans) {
            final pName = p['name']?.toString();
            if (pName != null && !uniquePlanNames.contains(pName)) {
              uniquePlanNames.add(pName);
              modalPlans.add(p);
            }
          }

          debugPrint('[VOUCHER] Loaded ${modalPlans.length} unique plans');
          if (modalPlans.isNotEmpty) {
            selectedPlan = modalPlans[0]['name']?.toString();
          }
          isModalLoading = false;
        });
      }
    }

    if (selectedRouter != null) {
       Future.delayed(Duration.zero, () {
        loadModalPlans(selectedRouter, (fn) => fn());
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
                Text('NEW VOUCHER', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 2)),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildModalLabel('STATION NODE', isDark),
                        _buildModalDropdown(
                          isDark: isDark,
                          value: selectedRouter,
                          items: _routers.map((r) {
                            final name = (r is Map) ? (r['name'] ?? r['router_name'] ?? r['router'])?.toString() : r.toString();
                            return DropdownMenuItem<String>(value: name, child: Text(name?.toUpperCase() ?? 'UNKNOWN', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))));
                          }).toList(),
                          onChanged: (val) {
                            setModalState(() => selectedRouter = val);
                            loadModalPlans(val, setModalState);
                          },
                        ),
                        const SizedBox(height: 20),
                        _buildModalLabel('ACCESS PLAN', isDark),
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
                        _buildModalLabel('QUANTITY', isDark),
                        Row(
                          children: [
                            _buildSpinButton(Icons.remove, () => setModalState(() { if (quantity > 1) quantity--; }), isDark),
                            Expanded(child: Center(child: Text(quantity.toString().padLeft(2, '0'), style: GoogleFonts.jetBrainsMono(fontSize: 24, fontWeight: FontWeight.bold, color: PaceColors.purple)))),
                            _buildSpinButton(Icons.add, () => setModalState(() { if (quantity < 50) quantity++; }), isDark),
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
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (selectedRouter == null || selectedPlan == null || isModalLoading) ? null : () async {
                        setModalState(() => isModalLoading = true);
                        final success = await _handleCreate(selectedRouter!, selectedPlan!, quantity);
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
                        : Text('GENERATE VOUCHERS', style: GoogleFonts.figtree(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13)),
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
    if (res?['status'] == 'success' || res?['status'] == 200) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generation Success'), backgroundColor: Colors.green));
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
        title: Text('Cleanup Assets', style: GoogleFonts.figtree(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Remove ${ids.length} selected voucher(s)?', style: GoogleFonts.figtree(fontSize: 13)),
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

  Widget _buildModalLabel(String label, bool isDark) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(label, style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)));

  Widget _buildModalDropdown({required bool isDark, required String? value, required List<DropdownMenuItem<String>> items, required Function(String?) onChanged}) {
    // Critical: Ensure value is actually in the items list, otherwise Flutter throws an assertion error
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
          items: items.isEmpty ? null : items, // Handle empty items case
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSpinButton(IconData icon, VoidCallback onTap, bool isDark) => InkWell(
    onTap: onTap, 
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(12), 
      decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), 
      child: Icon(icon, color: PaceColors.purple, size: 24)
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
              Text('PREPAID VOUCHERS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 16, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
              Row(
                children: [
                   Text('NODE: ', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold)),
                  Text(_selectedRouterName.toUpperCase(), style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 9, fontWeight: FontWeight.bold)),
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
            label: Text('GENERATE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
                      hintText: 'Lookup PIN code...', 
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
                    value: _selectedRouterName,
                    dropdownColor: PaceColors.getCard(isDark),
                    icon: const Icon(Icons.router_rounded, size: 14, color: PaceColors.purple),
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('ALL NODES', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)))),
                      ..._routers.map((r) {
                        final name = (r is Map) ? (r['name'] ?? r['router_name'] ?? r['router'])?.toString() : r.toString();
                        return DropdownMenuItem(value: name, child: Text(name?.toUpperCase() ?? 'NODE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))));
                      }),
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
                   Text('${_selectedIds.length} ASSETS SELECTED', style: GoogleFonts.figtree(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _handleDelete(_selectedIds.toList()),
                    icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Colors.red),
                    label: Text('DELETE', style: GoogleFonts.figtree(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
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
          Expanded(flex: 3, child: Text('IDENTIFIER', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
          Expanded(flex: 2, child: Center(child: Text('STATUS', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)))),
          Expanded(flex: 2, child: Text('SOURCE', textAlign: TextAlign.right, style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
        ],
      ),
    );
  }

  Widget _buildPortalVoucherItem(dynamic voucher, bool isDark) {
     final String id = voucher['id']?.toString() ?? '0';
    final bool isSelected = _selectedIds.contains(id);
    final status = (voucher['status']?.toString() ?? '').toLowerCase();
    final usedFlag = voucher['used'];
    final bool isUsed = status == 'used' || status == 'exhausted' || usedFlag == 1 || usedFlag == '1';
    
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
                  Text(voucher['voucher_code'] ?? 'NULL', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1)),
                  Text(voucher['plan']?.toUpperCase() ?? 'PLAN', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
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
                  Text(voucher['router_name']?.toUpperCase() ?? 'NODE', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getPrimaryText(isDark), fontWeight: FontWeight.bold)),
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
          Text('NO RESULTS', style: GoogleFonts.figtree(fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark).withOpacity(0.5), letterSpacing: 2, fontSize: 11)),
        ],
      ),
    );
  }
}
