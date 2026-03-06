import 'package:flutter/material.dart';
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
  
  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _search = '';
  String _selectedRouterId = 'all';

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
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _apiService.getVouchers(search: _search, page: 1, router: _selectedRouterId),
      _apiService.getRouters(),
    ]);

    if (mounted) {
      setState(() {
        _vouchers = results[0]?['data'] ?? [];
        _hasMore = results[0]?['pagination']?['has_more'] ?? false;
        _routers = results[1]?['data'] ?? [];
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchVouchers({bool force = false}) async {
    if (!force) setState(() => _isLoading = true);
    final res = await _apiService.getVouchers(search: _search, page: 1, router: _selectedRouterId, forceRefresh: force);
    if (mounted) {
      setState(() {
        _vouchers = res?['data'] ?? [];
        _hasMore = res?['pagination']?['has_more'] ?? false;
        _page = 1;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMoreVouchers() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final res = await _apiService.getVouchers(search: _search, page: nextPage, router: _selectedRouterId);
    if (mounted) {
      setState(() {
        final newItems = res?['data'] ?? [];
        _vouchers.addAll(newItems);
        _hasMore = res?['pagination']?['has_more'] ?? false;
        _page = nextPage;
        _isLoadingMore = false;
      });
    }
  }

  void _showCreateModal() async {
    String? selectedRouter;
    String? selectedPlan;
    int quantity = 1;
    bool isModalLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: PaceColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: PaceColors.border, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                const Text('CREATE VOUCHERS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1)),
                const SizedBox(height: 32),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildModalLabel('TARGET ROUTER'),
                        _buildModalDropdown(
                          value: selectedRouter,
                          items: _routers.map((r) => DropdownMenuItem(value: r['id'].toString(), child: Text(r['router_name']))).toList(),
                          onChanged: (val) async {
                            setModalState(() {
                              selectedRouter = val;
                              isModalLoading = true;
                              selectedPlan = null;
                            });
                            final plansRes = await _apiService.getPlans(val!);
                            setModalState(() {
                              _plans = plansRes?['plans'] ?? [];
                              isModalLoading = false;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildModalLabel('ACCESS PLAN'),
                        isModalLoading 
                          ? const PaceSkeleton(height: 56)
                          : _buildModalDropdown(
                              value: selectedPlan,
                              items: _plans.map((p) => DropdownMenuItem(value: p['name'].toString(), child: Text(p['name']))).toList(),
                              onChanged: (val) => setModalState(() => selectedPlan = val),
                            ),
                        const SizedBox(height: 24),
                        _buildModalLabel('QUANTITY (1-100)'),
                        Row(
                          children: [
                            _buildSpinButton(Icons.remove, () => setModalState(() { if (quantity > 1) quantity--; })),
                            Expanded(
                              child: Center(child: Text(quantity.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: PaceColors.purple))),
                            ),
                            _buildSpinButton(Icons.add, () => setModalState(() { if (quantity < 100) quantity++; })),
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
                      onPressed: (selectedRouter == null || selectedPlan == null) ? null : () async {
                        Navigator.pop(context);
                        _handleCreate(selectedRouter!, selectedPlan!, quantity);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: const Text('GENERATE ASSETS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
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

  Future<void> _handleCreate(String routerId, String planName, int count) async {
    // Implement API call for creation (assuming ApiService has createVouchers)
    // For now showing snackbar
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voucher creation initiated...')));
    // Refresh list
    _fetchVouchers(force: true);
  }

  Widget _buildModalLabel(String label) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.adminDim, letterSpacing: 1)));

  Widget _buildModalDropdown({required String? value, required List<DropdownMenuItem<String>> items, required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: PaceColors.bgSubtle, borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: const Text('Select Option', style: TextStyle(fontSize: 14)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSpinButton(IconData icon, VoidCallback onTap) => GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: PaceColors.purpleLight, shape: BoxShape.circle), child: Icon(icon, color: PaceColors.purple, size: 24)));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildSearchAndFilter(),
        Expanded(
          child: _isLoading 
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 8))
            : RefreshIndicator(
                onRefresh: () => _fetchVouchers(force: true),
                color: PaceColors.purple,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _vouchers.length + (_isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(color: PaceColors.border, height: 1),
                  itemBuilder: (context, index) {
                    if (index == _vouchers.length) return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)));
                    return _buildVoucherItem(_vouchers[index]);
                  },
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VOUCHERS', style: TextStyle(color: PaceColors.purple, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              Text('BULK ACCESS ASSETS', style: TextStyle(color: PaceColors.adminDim, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _showCreateModal,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('NEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: PaceColors.bgSubtle, borderRadius: BorderRadius.circular(12), border: Border.all(color: PaceColors.border)),
              child: TextField(
                onChanged: (val) { setState(() => _search = val); _fetchVouchers(); },
                decoration: const InputDecoration(hintText: 'Search PIN...', hintStyle: TextStyle(color: PaceColors.adminDim, fontSize: 12), border: InputBorder.none, prefixIcon: Icon(Icons.search, size: 18, color: PaceColors.adminDim)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: PaceColors.bgSubtle, borderRadius: BorderRadius.circular(12), border: Border.all(color: PaceColors.border)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRouterId,
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All Stations', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  ..._routers.map((r) => DropdownMenuItem(value: r['id'].toString(), child: Text(r['router_name'], style: const TextStyle(fontSize: 11)))),
                ],
                onChanged: (val) { setState(() => _selectedRouterId = val!); _fetchVouchers(); },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherItem(dynamic voucher) {
    final bool isUsed = voucher['used'] == 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: PaceColors.purpleLight, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.confirmation_number, color: PaceColors.purple, size: 20)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(voucher['voucher_code'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1.5, fontFamily: 'monospace')),
            Text('${voucher['plan']?.toUpperCase() ?? ''} • ${voucher['router_name'] ?? 'DEFAULT'}', style: const TextStyle(fontSize: 9, color: PaceColors.adminDim, fontWeight: FontWeight.bold)),
          ])),
          PaceBadge(label: isUsed ? 'Used' : 'Available', variant: isUsed ? BadgeVariant.secondary : BadgeVariant.success),
        ],
      ),
    );
  }
}
