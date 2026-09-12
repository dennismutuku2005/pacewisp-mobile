import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/empty_state.dart';
import '../components/skeleton.dart';
import 'customer_history_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _customers = [];
  List<dynamic> _routers = [];
  int _page = 1;
  int _total = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _search = '';
  String _selectedRouter = 'all';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchMore();
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getRouters(forceRefresh: true),
        _fetchCustomers(pageNum: 1),
      ]);
      final routersRes = results[0] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _routers = routersRes?['data'] ?? routersRes?['routers'] ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCustomers({required int pageNum}) async {
    try {
      final res = await _apiService.fetchData(slug: 'customers', params: {
        'page': pageNum,
        'limit': 20,
        'search': _search,
        'router_name': _selectedRouter == 'all' ? null : _selectedRouter,
      });

      if (mounted && (res?['status'] == 'success' || res?['status'] == 200)) {
        final List<dynamic> listData = (res?['data'] is List) ? (res!['data'] as List) : [];
        setState(() {
          if (pageNum == 1) {
            _customers = listData;
          } else {
            _customers.addAll(listData);
          }
          _hasMore = res?['pagination']?['has_more'] ?? false;
          _total = res?['pagination']?['total'] ?? _customers.length;
          _page = pageNum;
        });
      }
    } catch (e) {
      debugPrint("Error fetching customers: $e");
    }
  }

  Future<void> _fetchMore() async {
    setState(() => _isLoadingMore = true);
    try {
      await _fetchCustomers(pageNum: _page + 1);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<SettingsProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            _buildControls(isDark),
            _buildTableHeader(isDark),
            Expanded(
              child: _isLoading
                  ? const Padding(padding: EdgeInsets.all(16.0), child: TransactionSkeleton(count: 8))
                  : RefreshIndicator(
                      onRefresh: _loadInitialData,
                      color: PaceColors.purple,
                      child: _customers.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: PaceEmptyState(
                                title: 'No Customers Found',
                                subtitle: 'No customer profiles match your search criteria.',
                                onRetry: _loadInitialData,
                                isDark: isDark,
                              ),
                            )
                          : ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                              itemCount: _customers.length + (_isLoadingMore ? 1 : 0),
                              separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                              itemBuilder: (context, index) {
                                if (index == _customers.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)),
                                    ),
                                  );
                                }
                                return _buildCustomerRow(_customers[index], isDark);
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer Base',
                style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Distinct phone profiles • Total: $_total',
                style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            color: PaceColors.purple,
            onPressed: _loadInitialData,
          ),
        ],
      ),
    );
  }

  Widget _buildControls(bool isDark) {
    return Padding(
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
                onChanged: (val) {
                  _search = val;
                  _fetchCustomers(pageNum: 1);
                },
                style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getPrimaryText(isDark)),
                decoration: InputDecoration(
                  hintText: 'Search phone number...',
                  hintStyle: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 13),
                  prefixIcon: Icon(LucideIcons.search, size: 16, color: PaceColors.getDimText(isDark)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                value: _selectedRouter,
                dropdownColor: PaceColors.getCard(isDark),
                icon: const Icon(LucideIcons.chevronDown, size: 14),
                items: [
                  DropdownMenuItem(value: 'all', child: Text('All Mikrotiks', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600))),
                  ..._routers.map((r) => DropdownMenuItem(value: r['router_name']?.toString() ?? '', child: Text(r['router_name']?.toString() ?? 'Node', style: GoogleFonts.figtree(fontSize: 12)))),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedRouter = v);
                    _fetchCustomers(pageNum: 1);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isDark) {
    return Container(
      color: PaceColors.getSurface(isDark),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('PHONE NUMBER', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark), letterSpacing: 0.5))),
          Expanded(flex: 2, child: Center(child: Text('TOTAL PAID', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark), letterSpacing: 0.5)))),
          Expanded(flex: 2, child: Text('LAST SEEN', textAlign: TextAlign.right, style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark), letterSpacing: 0.5))),
        ],
      ),
    );
  }

  Widget _buildCustomerRow(dynamic c, bool isDark) {
    final phone = c['phone']?.toString() ?? '---';
    final totalPaid = c['total_paid']?.toString() ?? c['total_spent']?.toString() ?? '0';
    final lastSeen = c['last_seen']?.toString() ?? c['created_at']?.toString() ?? '---';
    final router = c['router_name']?.toString() ?? '';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CustomerHistoryScreen(phone: phone)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    phone,
                    style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: PaceColors.purple),
                  ),
                  if (router.isNotEmpty)
                    Text(
                      router,
                      style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark)),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  'KES $totalPaid',
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: PaceColors.green),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    lastSeen.split(' ')[0],
                    style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
                  ),
                  Text(
                    'Tap for history →',
                    style: GoogleFonts.figtree(fontSize: 9, color: PaceColors.purple, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
