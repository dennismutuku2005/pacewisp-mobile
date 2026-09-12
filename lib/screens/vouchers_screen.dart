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
      Future.delayed(const Duration(milliseconds: 500), _showCreateModal);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
      if (res != null && mounted) {
        setState(() {
          _routers = res['data'] ?? res['routers'] ?? [];
        });
      }
      await _fetchVouchers(pageNum: 1);
    } catch (e) {
      debugPrint("Error loading vouchers initial data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchVouchers({required int pageNum, bool forceRefresh = false}) async {
    String routerName = 'all';
    if (_activeRouterId != 'all') {
      final r = _routers.firstWhere(
        (x) => x['id'].toString() == _activeRouterId,
        orElse: () => null,
      );
      if (r != null) routerName = r['router_name'] ?? 'all';
    }

    try {
      final res = await _apiService.fetchData(
        slug: 'vouchers',
        forceRefresh: forceRefresh,
        params: {
          'page': pageNum,
          'limit': 20,
          'search': _search,
          'router_name': routerName,
        },
      );

      if (mounted) {
        if (res?['status'] == 'success' || res?['status'] == 200) {
          final List<dynamic> listData = (res?['data'] is List) ? (res!['data'] as List) : [];
          setState(() {
            if (pageNum == 1) {
              _vouchers = listData;
            } else {
              _vouchers.addAll(listData);
            }
            _hasMore = res?['pagination']?['has_more'] ?? false;
            _totalCount = res?['pagination']?['total'] ?? res?['pagination']?['total_records'] ?? _vouchers.length;
            _page = pageNum;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching vouchers: $e");
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

    final isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete ${idsToDelete.length} Voucher${idsToDelete.length > 1 ? 's' : ''}?',
          style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w700, color: PaceColors.red),
        ),
        content: Text(
          'Are you sure you want to permanently delete ${idsToDelete.length} voucher(s)? This action cannot be undone.',
          style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getSecondaryText(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PaceColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.figtree(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      try {
        final res = await _apiService.deleteVouchers(idsToDelete);
        if (res?['status'] == 'success') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${idsToDelete.length} voucher(s) deleted'),
                backgroundColor: PaceColors.foreground,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          _selectedVoucherIds.clear();
          await _fetchVouchers(pageNum: 1, forceRefresh: true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: PaceColors.red),
          );
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
          _fetchVouchers(pageNum: 1, forceRefresh: true);
          if (newVouchers.isNotEmpty) {
            _showCreatedVouchersModal(newVouchers);
          }
        },
      ),
    );
  }

  void _showCreatedVouchersModal(List<dynamic> newVouchers) {
    final isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(LucideIcons.checkCircle2, color: PaceColors.green, size: 22),
            const SizedBox(width: 10),
            Text(
              'Generated Vouchers',
              style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w700, color: PaceColors.getPrimaryText(isDark)),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${newVouchers.length} voucher(s) generated successfully.',
                style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getSecondaryText(isDark)),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: newVouchers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final v = newVouchers[index];
                    final code = (v is Map ? v['voucher_code'] : v)?.toString().toUpperCase() ?? '';
                    final plan = (v is Map ? v['plan'] : '')?.toString() ?? '';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: PaceColors.getSurface(isDark),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: PaceColors.getBorder(isDark)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.ticket, size: 16, color: PaceColors.purple),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                code,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: PaceColors.purple,
                                ),
                              ),
                              if (plan.isNotEmpty)
                                Text(
                                  plan,
                                  style: GoogleFonts.figtree(
                                    fontSize: 10,
                                    color: PaceColors.getDimText(isDark),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(LucideIcons.copy, size: 16),
                            color: PaceColors.purple,
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Voucher PIN copied'),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PaceColors.purple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text('Done', style: GoogleFonts.figtree(fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedVoucherIds.length == _vouchers.length) {
        _selectedVoucherIds.clear();
      } else {
        _selectedVoucherIds.clear();
        for (var v in _vouchers) {
          if (v['id'] != null) _selectedVoucherIds.add(v['id'].toString());
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<SettingsProvider>(context).isDarkMode;
    final settings = Provider.of<SettingsProvider>(context);
    final canCreate = settings.hasPolicy('create_voucher');

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark, canCreate),
            _buildFilterBar(isDark),
            if (_selectedVoucherIds.isNotEmpty) _buildBulkActionBar(isDark),
            _buildTableHeader(isDark),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchVouchers(pageNum: 1, forceRefresh: true),
                color: PaceColors.purple,
                child: _isLoading
                    ? const TransactionSkeleton(count: 10)
                    : _vouchers.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: PaceEmptyState(
                              title: 'No Vouchers Found',
                              subtitle: _search.isNotEmpty
                                  ? 'No vouchers match "$_search"'
                                  : 'No prepaid vouchers generated for this node yet.',
                              onRetry: () => _fetchVouchers(pageNum: 1, forceRefresh: true),
                              isDark: isDark,
                            ),
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: _vouchers.length + (_isMoreLoading ? 1 : 0),
                            separatorBuilder: (_, __) => Divider(height: 1, color: PaceColors.getBorder(isDark)),
                            itemBuilder: (context, index) {
                              if (index == _vouchers.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: PaceColors.purple),
                                    ),
                                  ),
                                );
                              }
                              return _buildVoucherRow(_vouchers[index], isDark);
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _showCreateModal,
              backgroundColor: PaceColors.purple,
              elevation: 3,
              icon: const Icon(LucideIcons.plus, color: Colors.white, size: 18),
              label: Text(
                'New Voucher',
                style: GoogleFonts.figtree(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            )
          : null,
    );
  }

  Widget _buildHeader(bool isDark, bool canCreate) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prepaid Vouchers',
                style: GoogleFonts.figtree(
                  color: PaceColors.purple,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    'Node: ',
                    style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _activeRouterId == 'all'
                        ? 'All Mikrotiks'
                        : (_routers.firstWhere((r) => r['id'].toString() == _activeRouterId, orElse: () => {})['router_name'] ?? 'Selected'),
                    style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.purple, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '• Total: $_totalCount',
                    style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark)),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            color: PaceColors.purple,
            onPressed: () => _fetchVouchers(pageNum: 1, forceRefresh: true),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: PaceColors.getSurface(isDark),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PaceColors.getBorder(isDark)),
              ),
              child: TextField(
                onChanged: (v) {
                  _search = v;
                  _fetchVouchers(pageNum: 1);
                },
                style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getPrimaryText(isDark)),
                decoration: InputDecoration(
                  hintText: 'Search voucher PIN...',
                  hintStyle: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 13),
                  prefixIcon: Icon(LucideIcons.search, size: 16, color: PaceColors.getDimText(isDark)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: PaceColors.getSurface(isDark),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PaceColors.getBorder(isDark)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _activeRouterId,
                dropdownColor: PaceColors.getCard(isDark),
                icon: const Icon(LucideIcons.chevronDown, size: 14),
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('All Mikrotiks', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  ..._routers.map((r) => DropdownMenuItem(
                        value: r['id'].toString(),
                        child: Text(r['router_name'] ?? 'Node', style: GoogleFonts.figtree(fontSize: 12)),
                      )),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _activeRouterId = v);
                    _fetchVouchers(pageNum: 1, forceRefresh: true);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActionBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: PaceColors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PaceColors.red.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedVoucherIds.length} Selected',
            style: GoogleFonts.figtree(color: PaceColors.red, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _handleDeleteVouchers(),
            icon: const Icon(LucideIcons.trash2, size: 14, color: PaceColors.red),
            label: Text(
              'Delete Selected',
              style: GoogleFonts.figtree(color: PaceColors.red, fontWeight: FontWeight.w700, fontSize: 12),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark),
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark), width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _vouchers.isNotEmpty && _selectedVoucherIds.length == _vouchers.length,
              onChanged: (_) => _toggleSelectAll(),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              activeColor: PaceColors.purple,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              'VOUCHER PIN',
              style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark), letterSpacing: 0.5),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'PLAN',
              style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark), letterSpacing: 0.5),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'STATUS',
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark), letterSpacing: 0.5),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildVoucherRow(dynamic v, bool isDark) {
    final id = v['id']?.toString() ?? '';
    final code = v['voucher_code']?.toString().toUpperCase() ?? 'CODE';
    final plan = v['plan']?.toString() ?? 'Default';
    final router = v['router_name']?.toString() ?? 'Default';
    final isUsed = v['used']?.toString() == '1';
    final isSale = v['sale']?.toString() == '1';
    final isSelected = _selectedVoucherIds.contains(id);

    return InkWell(
      onTap: () => _showVoucherDetailsDrawer(v, isDark),
      child: Container(
        color: isSelected ? PaceColors.purple.withOpacity(0.05) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedVoucherIds.add(id);
                    } else {
                      _selectedVoucherIds.remove(id);
                    }
                  });
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                activeColor: PaceColors.purple,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.ticket, size: 12, color: PaceColors.purple),
                      const SizedBox(width: 4),
                      Text(
                        code,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: PaceColors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(LucideIcons.wifi, size: 10, color: PaceColors.getDimText(isDark)),
                      const SizedBox(width: 4),
                      Text(
                        router,
                        style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan,
                    style: GoogleFonts.figtree(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: PaceColors.getPrimaryText(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isSale)
                    Text(
                      'SALE',
                      style: GoogleFonts.figtree(fontSize: 9, color: PaceColors.green, fontWeight: FontWeight.w700),
                    ),
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
            IconButton(
              icon: const Icon(LucideIcons.trash2, size: 15, color: Colors.grey),
              onPressed: () => _handleDeleteVouchers(singleId: id),
            ),
          ],
        ),
      ),
    );
  }

  void _showVoucherDetailsDrawer(dynamic v, bool isDark) {
    final code = v['voucher_code']?.toString().toUpperCase() ?? '';
    final plan = v['plan']?.toString() ?? 'N/A';
    final router = v['router_name']?.toString() ?? 'Default';
    final isUsed = v['used']?.toString() == '1';
    final isSale = v['sale']?.toString() == '1';
    final createdAt = v['created_at']?.toString() ?? 'N/A';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: PaceColors.getBorder(isDark)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: PaceColors.getBorder(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Voucher Details',
                  style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w700, color: PaceColors.purple),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PaceColors.getSurface(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PaceColors.getBorder(isDark)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VOUCHER PIN',
                        style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        code,
                        style: GoogleFonts.jetBrainsMono(fontSize: 20, fontWeight: FontWeight.w700, color: PaceColors.purple, letterSpacing: 2),
                      ),
                    ],
                  ),
                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: PaceColors.purple.withOpacity(0.1)),
                    icon: const Icon(LucideIcons.copy, size: 18, color: PaceColors.purple),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Voucher PIN copied to clipboard'), behavior: SnackBarBehavior.floating),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailRow('Plan', plan, isDark),
            _buildDetailRow('Mikrotik Node', router, isDark),
            _buildDetailRow('Status', isUsed ? 'Used' : 'Available', isDark, isStatus: true, isOk: !isUsed),
            _buildDetailRow('Recorded as Sale', isSale ? 'Yes' : 'No', isDark),
            _buildDetailRow('Created At', createdAt, isDark),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {bool isStatus = false, bool isOk = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark))),
          isStatus
              ? PaceBadge(label: value, variant: isOk ? BadgeVariant.success : BadgeVariant.secondary)
              : Text(
                  value,
                  style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
                ),
        ],
      ),
    );
  }
}

class _CreateVoucherBottomSheet extends StatefulWidget {
  final List<dynamic> routers;
  final String initialRouterId;
  final Function(List<dynamic>) onCreated;

  const _CreateVoucherBottomSheet({
    required this.routers,
    required this.initialRouterId,
    required this.onCreated,
  });

  @override
  State<_CreateVoucherBottomSheet> createState() => _CreateVoucherBottomSheetState();
}

class _CreateVoucherBottomSheetState extends State<_CreateVoucherBottomSheet> {
  final ApiService _apiService = ApiService();
  String? _selectedRouterId;
  String? _selectedPlan;
  int _count = 1;
  bool _isSale = false;
  bool _isForcedSale = false;
  bool _isLoading = false;
  bool _isPlansLoading = false;
  List<dynamic> _plans = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialRouterId != 'all') {
      _selectedRouterId = widget.initialRouterId;
    } else if (widget.routers.isNotEmpty) {
      _selectedRouterId = widget.routers.first['id'].toString();
    }
    _fetchSystemSettings();
    if (_selectedRouterId != null) _fetchPlans();
  }

  Future<void> _fetchSystemSettings() async {
    try {
      final res = await _apiService.getSystemSettings();
      if (mounted && res?['data'] != null) {
        final forced = res!['data']['vouchers_as_sale']?.toString() == '1';
        setState(() {
          _isForcedSale = forced;
          _isSale = forced ? true : false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching sys settings: $e");
    }
  }

  Future<void> _fetchPlans() async {
    if (_selectedRouterId == null) return;
    setState(() => _isPlansLoading = true);
    try {
      final res = await _apiService.getPlans(_selectedRouterId!);
      if (mounted) {
        final List<dynamic> fetchedPlans = res?['plans'] ?? [];
        setState(() {
          _plans = fetchedPlans;
          if (_plans.isNotEmpty) {
            _selectedPlan = _plans.first['name']?.toString();
          } else {
            _selectedPlan = null;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching plans: $e");
    } finally {
      if (mounted) setState(() => _isPlansLoading = false);
    }
  }

  Future<void> _handleCreate() async {
    if (_selectedRouterId == null || _selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a router and a plan')),
      );
      return;
    }

    final selectedRouter = widget.routers.firstWhere(
      (r) => r['id'].toString() == _selectedRouterId,
      orElse: () => {'router_name': 'default'},
    );

    setState(() => _isLoading = true);
    try {
      final res = await _apiService.createVoucher({
        'router_name': selectedRouter['router_name'],
        'plan': _selectedPlan,
        'count': _count,
        'sale': _isSale ? 1 : 0,
      });

      if (res?['status'] == 'success' || res?['status'] == 200) {
        final List<dynamic> createdData = (res?['data'] is List) ? (res!['data'] as List) : [];
        if (mounted) {
          Navigator.pop(context);
          widget.onCreated(createdData);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res?['message'] ?? 'Failed to create vouchers'), backgroundColor: PaceColors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Creation error: $e'), backgroundColor: PaceColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<SettingsProvider>(context).isDarkMode;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Generate Vouchers',
                style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w700, color: PaceColors.purple),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x, size: 18)),
            ],
          ),
          const SizedBox(height: 20),
          _buildFieldLabel('Mikrotik Node', isDark),
          const SizedBox(height: 6),
          _buildDropdown(
            value: _selectedRouterId,
            items: widget.routers
                .map((r) => DropdownMenuItem(
                      value: r['id'].toString(),
                      child: Text(r['router_name'] ?? 'Node', style: GoogleFonts.figtree(fontSize: 13)),
                    ))
                .toList(),
            onChanged: (val) {
              setState(() {
                _selectedRouterId = val;
                _selectedPlan = null;
              });
              _fetchPlans();
            },
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _buildFieldLabel('Access Plan', isDark),
          const SizedBox(height: 6),
          _isPlansLoading
              ? Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: PaceColors.getSurface(isDark),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: PaceColors.getBorder(isDark)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: PaceColors.purple)),
                      const SizedBox(width: 12),
                      Text('Fetching plans...', style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getDimText(isDark))),
                    ],
                  ),
                )
              : _buildDropdown(
                  value: _selectedPlan,
                  items: _plans
                      .map((p) => DropdownMenuItem(
                            value: p['name'].toString(),
                            child: Text('${p['name']} - KES ${p['price']}', style: GoogleFonts.figtree(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedPlan = val),
                  isDark: isDark,
                  hint: _plans.isEmpty ? 'No plans configured' : 'Select plan',
                ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Quantity (1-50)', isDark),
                    const SizedBox(height: 6),
                    TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _count = int.tryParse(v) ?? 1,
                      style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: '1',
                        filled: true,
                        fillColor: PaceColors.getSurface(isDark),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: PaceColors.getBorder(isDark)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel(_isForcedSale ? 'Forced Sale Mode' : 'Record as Sale', isDark),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: PaceColors.getSurface(isDark),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: PaceColors.getBorder(isDark)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isSale ? 'YES' : 'NO',
                            style: GoogleFonts.figtree(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _isSale ? PaceColors.green : PaceColors.getDimText(isDark),
                            ),
                          ),
                          Switch(
                            value: _isSale,
                            onChanged: _isForcedSale ? null : (v) => setState(() => _isSale = v),
                            activeColor: PaceColors.green,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: PaceColors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Generate Vouchers', style: GoogleFonts.figtree(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text, bool isDark) => Text(
        text,
        style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark)),
      );

  Widget _buildDropdown({
    required dynamic value,
    required List<DropdownMenuItem> items,
    required Function(dynamic) onChanged,
    required bool isDark,
    String hint = 'Select',
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton(
          isExpanded: true,
          value: value,
          dropdownColor: PaceColors.getCard(isDark),
          hint: Text(hint, style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getDimText(isDark))),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
