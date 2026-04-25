import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/empty_state.dart';
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
  final Set<String> _selectedVoucherIds = {};
  
  int _page = 1;
  int _totalCount = 0;
  bool _isLoading = true;
  bool _isMoreLoading = false;
  bool _hasMore = true;
  bool _isSaving = false;
  
  String _activeRouterId = 'all';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
    if (widget.openModal) {
      Future.delayed(const Duration(milliseconds: 600), _showCreateModal);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isMoreLoading && _hasMore) {
        _loadMoreVouchers();
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getRouters(forceRefresh: true);
      if (res != null) {
        setState(() {
          _routers = res['data'] ?? [];
        });
        await _fetchVouchers(pageNum: 1);
      }
    } catch (e) {
      debugPrint("Error loading initial data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchVouchers({required int pageNum, bool forceRefresh = false}) async {
    String routerName = 'all';
    if (_activeRouterId != 'all') {
      final r = _routers.firstWhere((x) => x['id'].toString() == _activeRouterId, orElse: () => null);
      if (r != null) routerName = r['router_name'] ?? 'all';
    }

    final res = await _apiService.fetchData(slug: 'vouchers', forceRefresh: forceRefresh, params: {
      'page': pageNum,
      'limit': 20,
      'search': _search,
      'router_name': routerName
    });

    if (mounted) {
      if (res?['status'] == 'success') {
        setState(() {
          if (pageNum == 1) {
            _vouchers = res?['data'] ?? [];
          } else {
            _vouchers.addAll(res?['data'] ?? []);
          }
          _hasMore = res?['pagination']?['has_more'] ?? false;
          _totalCount = res?['pagination']?['total_records'] ?? _vouchers.length;
          _page = pageNum;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['message'] ?? 'Failed to load vouchers'), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  Future<void> _loadMoreVouchers() async {
    setState(() => _isMoreLoading = true);
    try {
      await _fetchVouchers(pageNum: _page + 1);
    } finally {
      if (mounted) setState(() => _isMoreLoading = false);
    }
  }

  Future<void> _handleDeleteVouchers({String? singleId}) async {
    final List<String> idsToDelete = singleId != null ? [singleId] : _selectedVoucherIds.toList();
    if (idsToDelete.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getBackground(Provider.of<SettingsProvider>(context).isDarkMode),
        title: Text('DELETE VOUCHERS', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red)),
        content: Text('Permanently remove ${idsToDelete.length} selected vouchers? This action cannot be undone.', style: GoogleFonts.figtree(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(idsToDelete.length > 1 ? 'DELETE ALL' : 'DELETE', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      try {
        final res = await _apiService.fetchData(slug: 'vouchers', method: 'DELETE', body: {
          'ids': idsToDelete
        });

        if (res?['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vouchers deleted successfully'), backgroundColor: Colors.black));
          _selectedVoucherIds.clear();
          _fetchVouchers(pageNum: 1, forceRefresh: true);
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  void _showCreateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateVoucherBottomSheet(
        routers: _routers,
        initialRouterId: _activeRouterId,
        onCreated: (newVouchers) {
          setState(() {
            _vouchers.insertAll(0, newVouchers);
            _totalCount += newVouchers.length;
          });
          _showCreatedVouchersModal(newVouchers);
        },
      ),
    );
  }

  void _showCreatedVouchersModal(List<dynamic> newVouchers) {
    final isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getBackground(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            const Icon(Icons.check_circle_rounded, color: PaceColors.emerald, size: 48),
            const SizedBox(height: 12),
            Text('GENERATED CODES', style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.purple)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${newVouchers.length} new vouchers created successfully.', style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark))),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: newVouchers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final v = newVouchers[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: PaceColors.getBorder(isDark))),
                      child: Row(
                        children: [
                          const Icon(Icons.confirmation_num_rounded, size: 16, color: PaceColors.purple),
                          const SizedBox(width: 12),
                          Text(v['voucher_code']?.toString().toUpperCase() ?? '', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: v['voucher_code']?.toString() ?? ''));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!'), duration: Duration(seconds: 1)));
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<SettingsProvider>(context).isDarkMode;
    
    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: Column(
        children: [
          _buildHeader(isDark),
          _buildFilterBar(isDark),
          if (_selectedVoucherIds.isNotEmpty) _buildBulkActionBar(isDark),
          _buildTableHeader(isDark),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchVouchers(pageNum: 1, forceRefresh: true),
              color: PaceColors.purple,
              child: _isLoading 
                ? const TransactionSkeleton(count: 12)
                : _vouchers.isEmpty 
                  ? SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: PaceEmptyState(onRetry: () => _fetchVouchers(pageNum: 1, forceRefresh: true), isDark: isDark))
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
                      itemCount: _vouchers.length + (_isMoreLoading ? 1 : 0),
                      separatorBuilder: (_, __) => Divider(height: 1, color: PaceColors.getBorder(isDark)),
                      itemBuilder: (context, index) {
                        if (index == _vouchers.length) {
                          return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                        }
                        return _buildVoucherRow(_vouchers[index], isDark);
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateModal,
        backgroundColor: PaceColors.purple,
        icon: const Icon(Icons.plus_one, color: Colors.white),
        label: const Text('GENERATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('VOUCHERS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 20, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
            Text('PREPAID INVENTORY', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 2)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(_totalCount.toString(), style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.purple)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark))),
              child: TextField(
                onChanged: (v) {
                  _search = v;
                  _fetchVouchers(pageNum: 1);
                },
                style: TextStyle(fontSize: 13, color: PaceColors.getPrimaryText(isDark)),
                decoration: InputDecoration(
                  hintText: 'Search PIN...',
                  hintStyle: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 13),
                  border: InputBorder.none,
                  icon: Icon(LucideIcons.search, size: 16, color: PaceColors.getDimText(isDark)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildRouterDropdown(isDark),
        ],
      ),
    );
  }

  Widget _buildRouterDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _activeRouterId,
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All Nodes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            ..._routers.map((r) => DropdownMenuItem(value: r['id'].toString(), child: Text(r['router_name'] ?? 'Node', style: const TextStyle(fontSize: 12)))),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => _activeRouterId = v);
              _fetchVouchers(pageNum: 1);
            }
          },
        ),
      ),
    );
  }

  Widget _buildBulkActionBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.withOpacity(0.2))),
      child: Row(
        children: [
          Text('${_selectedVoucherIds.length} Selected', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _handleDeleteVouchers(),
            icon: const Icon(LucideIcons.trash2, size: 14, color: Colors.red),
            label: const Text('DELETE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          IconButton(
            onPressed: () => setState(() => _selectedVoucherIds.clear()),
            icon: const Icon(LucideIcons.x, size: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isDark) {
    return Container(
      color: PaceColors.getSurface(isDark),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('PIN & PLAN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
          Expanded(flex: 2, child: Text('STATION NODE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
          Expanded(flex: 2, child: Text('STATUS', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
        ],
      ),
    );
  }

  Widget _buildVoucherRow(dynamic v, bool isDark) {
    final id = v['id'].toString();
    final isSelected = _selectedVoucherIds.contains(id);
    final isUsed = v['used']?.toString() == '1';
    
    return InkWell(
      onLongPress: () => setState(() => _selectedVoucherIds.add(id)),
      onTap: () {
        if (_selectedVoucherIds.isNotEmpty) {
          setState(() => isSelected ? _selectedVoucherIds.remove(id) : _selectedVoucherIds.add(id));
        } else {
           _showVoucherDrawer(v, isDark);
        }
      },
      child: Container(
        color: isSelected ? PaceColors.purple.withOpacity(0.05) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_selectedVoucherIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: Checkbox(
                              value: isSelected, 
                              onChanged: (val) => setState(() => val! ? _selectedVoucherIds.add(id) : _selectedVoucherIds.remove(id)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              activeColor: PaceColors.purple,
                            ),
                          ),
                        ),
                      Text(v['voucher_code']?.toString().toUpperCase() ?? 'CODE', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(v['plan']?.toString().toUpperCase() ?? 'PLAN', style: TextStyle(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(v['router_name']?.toString().toUpperCase() ?? 'NODE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PaceBadge(label: isUsed ? 'USED' : 'AVAILABLE', variant: isUsed ? BadgeVariant.secondary : BadgeVariant.success),
                  const SizedBox(height: 4),
                  Text(v['created_at']?.split(' ')[0] ?? '', style: TextStyle(fontSize: 7, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVoucherDrawer(dynamic v, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: PaceColors.getBorder(isDark), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('VOUCHER DETAILS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: PaceColors.purple, letterSpacing: 1.5)),
                        IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('VOUCHER CODE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
                              const SizedBox(height: 4),
                              Text(v['voucher_code']?.toUpperCase() ?? 'CODE', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark), letterSpacing: 2)),
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
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _buildDrawerInfo('SALE STATUS', (v['sale']?.toString() == '1') ? 'YES' : 'NO', isDark, isSaleColor: true)),
                        Expanded(child: _buildDrawerInfo('VOUCHER STATUS', (v['used']?.toString() == '1') ? 'USED' : 'AVAILABLE', isDark)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildDrawerInfo('CREATED AT', v['created_at']?.toString() ?? 'N/A', isDark),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawerInfo(String label, String value, bool isDark, {bool isSaleColor = false}) {
    Color valColor = PaceColors.getPrimaryText(isDark);
    if (isSaleColor) {
      if (value.contains('NOT') || value == 'NO') {
        valColor = Colors.red;
      } else {
        valColor = PaceColors.emerald;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valColor)),
      ],
    );
  }
}

class _CreateVoucherBottomSheet extends StatefulWidget {
  final List<dynamic> routers;
  final String initialRouterId;
  final Function(List<dynamic>) onCreated;

  const _CreateVoucherBottomSheet({required this.routers, required this.initialRouterId, required this.onCreated});

  @override
  State<_CreateVoucherBottomSheet> createState() => _CreateVoucherBottomSheetState();
}

class _CreateVoucherBottomSheetState extends State<_CreateVoucherBottomSheet> {
  final ApiService _apiService = ApiService();
  String? _selectedRouterId;
  String? _selectedPlan;
  int _count = 1;
  bool _isSale = true;
  bool _isLoading = false;
  List<dynamic> _plans = [];

  @override
  void initState() {
    super.initState();
    _selectedRouterId = widget.initialRouterId == 'all' ? null : widget.initialRouterId;
    if (_selectedRouterId != null) _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getPlans(_selectedRouterId!);
      setState(() => _plans = res?['plans'] ?? []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCreate() async {
    if (_selectedRouterId == null || _selectedPlan == null) return;
    
    final router = widget.routers.firstWhere((r) => r['id'].toString() == _selectedRouterId);
    
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.fetchData(slug: 'vouchers', method: 'POST', body: {
        'router_name': router['router_name'],
        'plan': _selectedPlan,
        'count': _count,
        'sale': _isSale ? 1 : 0
      });

      if (res?['status'] == 'success') {
        widget.onCreated(res?['data'] ?? []);
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Failed to create')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<SettingsProvider>(context).isDarkMode;
    
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 40),
      decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('GENERATE VOUCHERS', style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.purple)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x)),
            ],
          ),
          const SizedBox(height: 24),
          _buildLabel('SELECT MIKROTIK', isDark),
          const SizedBox(height: 8),
          _buildDropdown(
            value: _selectedRouterId,
            items: widget.routers.map((r) => DropdownMenuItem(value: r['id'].toString(), child: Text(r['router_name'] ?? 'Node'))).toList(),
            onChanged: (val) {
              setState(() { _selectedRouterId = val; _selectedPlan = null; });
              _fetchPlans();
            },
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          _buildLabel('ACCESS PLAN', isDark),
          const SizedBox(height: 8),
          _buildDropdown(
            value: _selectedPlan,
            items: _plans.map((p) => DropdownMenuItem(value: p['name'].toString(), child: Text('${p['name']} - KES ${p['price']}'))).toList(),
            onChanged: (val) => setState(() => _selectedPlan = val),
            isDark: isDark,
            hint: _isLoading ? 'Loading plans...' : 'Select a plan',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('QUANTITY', isDark),
                    const SizedBox(height: 8),
                    TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _count = int.tryParse(v) ?? 1,
                      decoration: InputDecoration(
                        hintText: '1',
                        filled: true,
                        fillColor: PaceColors.getCard(isDark),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: PaceColors.getBorder(isDark))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('RECORD AS SALE', isDark),
                    const SizedBox(height: 8),
                    Switch(
                      value: _isSale,
                      onChanged: (v) => setState(() => _isSale = v),
                      activeColor: PaceColors.emerald,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleCreate,
              style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('GENERATE VOUCHERS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) => Text(text, style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1));

  Widget _buildDropdown({required dynamic value, required List<DropdownMenuItem> items, required Function(dynamic) onChanged, required bool isDark, String hint = 'Select'}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: PaceColors.getBorder(isDark))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton(
          isExpanded: true,
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 13)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
