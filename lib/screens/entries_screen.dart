import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/empty_state.dart';
import '../components/skeleton.dart';

class EntriesScreen extends StatefulWidget {
  const EntriesScreen({super.key});

  @override
  State<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends State<EntriesScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _entries = [];
  int _page = 1;
  int _total = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _search = '';
  
  String _selectedRouter = 'All Routers';
  String _selectedDateRange = 'All Time';
  List<String> _routerNames = ['All Routers'];
  dynamic _reinitializingId;

  @override
  void initState() {
    super.initState();
    _loadRouters();
    _fetchEntries();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && !_isLoading) {
        _fetchMoreEntries();
      }
    }
  }

  Future<void> _loadRouters() async {
    try {
      final res = await _apiService.getRouters(forceRefresh: true);
      if (res != null) {
        final dynamic raw = res['data'] ?? res['routers'];
        if (raw is List) {
          final Set<String> unique = {'All Routers'};
          for (var r in raw) {
            String? name = (r is Map) ? (r['name'] ?? r['router_name'] ?? r['router'])?.toString() : r.toString();
            if (name != null && name.isNotEmpty) unique.add(name);
          }
          if (mounted) setState(() => _routerNames = unique.toList());
        }
      }
    } catch (_) {}
  }

  Map<String, String> _parseDateRange(String range) {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd');
    if (range == 'Today') return {'startDate': formatter.format(now), 'endDate': formatter.format(now)};
    if (range == 'Yesterday') {
      final yest = now.subtract(const Duration(days: 1));
      return {'startDate': formatter.format(yest), 'endDate': formatter.format(yest)};
    }
    if (range == 'This Week') return {'startDate': formatter.format(now.subtract(const Duration(days: 6))), 'endDate': formatter.format(now)};
    if (range == 'This Month') return {'startDate': formatter.format(DateTime(now.year, now.month, 1)), 'endDate': formatter.format(now)};
    return {};
  }

  Future<void> _fetchEntries({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final filters = _parseDateRange(_selectedDateRange);
    final router = (_selectedRouter == 'All Routers' || _selectedRouter.isEmpty) ? null : _selectedRouter;
    final search = _search.trim().isEmpty ? null : _search.trim();

    try {
      final live = await _apiService.getEntries(
        search: search, 
        page: 1, 
        limit: 12,
        router: router,
        startDate: filters['startDate'],
        endDate: filters['endDate'],
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        if (live != null) {
          final items = _extractEntries(live);
          final hasMore = _extractHasMore(live, items.length);
          final total = _extractTotal(live, items.length);
          setState(() {
            _entries = items;
            _hasMore = hasMore;
            _total = total;
            _page = 1;
            _isLoading = false;
          });
        } else {
          setState(() {
            _entries = [];
            _hasMore = false;
            _total = 0;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMoreEntries() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final filters = _parseDateRange(_selectedDateRange);
    final router = (_selectedRouter == 'All Routers' || _selectedRouter.isEmpty) ? null : _selectedRouter;
    final search = _search.trim().isEmpty ? null : _search.trim();

    try {
      final live = await _apiService.getEntries(
        search: search, 
        page: nextPage, 
        limit: 12,
        router: router,
        startDate: filters['startDate'],
        endDate: filters['endDate'],
        forceRefresh: true,
      );
      if (mounted && live != null) {
        final newEntries = _extractEntries(live);
        final existingIds = _entries.map((e) => e['id']?.toString()).where((id) => id != null).toSet();
        final uniqueNew = newEntries.where((e) => !existingIds.contains(e['id']?.toString())).toList();
        
        setState(() {
          _entries.addAll(uniqueNew);
          _hasMore = _extractHasMore(live, _entries.length);
          _page = nextPage;
          _isLoadingMore = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingMore = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  List<dynamic> _extractEntries(Map<String, dynamic> data) {
    if (data['data'] is List) return data['data'] as List;
    if (data['data'] is Map && data['data']['entries'] is List) {
      return data['data']['entries'] as List;
    }
    if (data['data'] is Map && data['data']['data'] is List) {
      return data['data']['data'] as List;
    }
    if (data['entries'] is List) return data['entries'] as List;
    return [];
  }

  bool _extractHasMore(Map<String, dynamic> data, int currentCount) {
    if (data['pagination'] is Map && data['pagination']['has_more'] != null) {
      final val = data['pagination']['has_more'];
      return val == true || val == 1 || val == '1' || val == 'true';
    }
    if (data['data'] is Map && data['data']['pagination'] is Map && data['data']['pagination']['has_more'] != null) {
      final val = data['data']['pagination']['has_more'];
      return val == true || val == 1 || val == '1' || val == 'true';
    }
    if (data['has_more'] != null) {
      return data['has_more'] == true || data['has_more'] == 1;
    }
    final total = _extractTotal(data, currentCount);
    return total > currentCount && currentCount > 0;
  }

  int _extractTotal(Map<String, dynamic> data, int fallbackCount) {
    if (data['pagination'] is Map && data['pagination']['total'] != null) {
      return int.tryParse(data['pagination']['total'].toString()) ?? fallbackCount;
    }
    if (data['data'] is Map && data['data']['pagination'] is Map && data['data']['pagination']['total'] != null) {
      return int.tryParse(data['data']['pagination']['total'].toString()) ?? fallbackCount;
    }
    if (data['total'] != null) {
      return int.tryParse(data['total'].toString()) ?? fallbackCount;
    }
    return fallbackCount;
  }

  Future<void> _handleReinitialize(dynamic entryId, StateSetter setModalState) async {
    if (_reinitializingId != null) return;
    setModalState(() => _reinitializingId = entryId);

    try {
      final res = await _apiService.reinitializeEntry(entryId);
      if (mounted) {
        if (res != null && res['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Entry reinitialized on MikroTik router'),
              backgroundColor: PaceColors.emerald,
            ),
          );
          // Update item in local list
          setState(() {
            _entries = _entries.map((item) {
              if (item['id']?.toString() == entryId.toString()) {
                final updated = Map<String, dynamic>.from(item as Map);
                updated['used'] = true;
                updated['active'] = true;
                if (res['data'] is Map && res['data']['expires'] != null) {
                  updated['expires'] = res['data']['expires'];
                }
                return updated;
              }
              return item;
            }).toList();
          });
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res?['message'] ?? 'Failed to reinitialize entry'),
              backgroundColor: PaceColors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: PaceColors.red),
        );
      }
    } finally {
      if (mounted) setModalState(() => _reinitializingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<SettingsProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _fetchEntries(forceRefresh: true),
          color: PaceColors.purple,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(isDark)),
              SliverToBoxAdapter(child: _buildGlobalFilters(isDark)),
              SliverToBoxAdapter(child: _buildSearchBox(isDark)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: PaceColors.getCard(isDark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: PaceColors.getBorder(isDark), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTableHeader(isDark),
                        if (_isLoading)
                          _buildSkeletonList(isDark)
                        else if (_entries.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                            child: PaceEmptyState(
                              title: 'No Connection Entries',
                              subtitle: 'No connection sessions match your current filter criteria.',
                              onRetry: () => _fetchEntries(forceRefresh: true),
                              isDark: isDark,
                            ),
                          )
                        else ...[
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _entries.length,
                            itemBuilder: (context, index) {
                              final isLast = index == _entries.length - 1 && !_isLoadingMore;
                              return _buildEntryItem(_entries[index], isDark, isLast: isLast);
                            },
                          ),
                          if (_isLoadingMore)
                            Container(
                              padding: const EdgeInsets.all(16),
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: PaceColors.purple),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return Column(
      children: List.generate(
        8,
        (index) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: index < 7 ? Border(bottom: BorderSide(color: PaceColors.getBorder(isDark), width: 0.8)) : null,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PaceSkeleton(height: 14, width: 120, borderRadius: 4),
                    const SizedBox(height: 6),
                    PaceSkeleton(height: 10, width: 80, borderRadius: 4),
                  ],
                ),
              ),
              const Expanded(
                flex: 2,
                child: Center(
                  child: PaceSkeleton(height: 14, width: 60, borderRadius: 4),
                ),
              ),
              const Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: PaceSkeleton(height: 22, width: 56, borderRadius: 6),
                ),
              ),
            ],
          ),
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
                'Connection Entries',
                style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Real-time access logs • Total: $_total',
                style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            color: PaceColors.purple,
            onPressed: () => _fetchEntries(forceRefresh: true),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalFilters(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterButton(
              icon: LucideIcons.router,
              label: _selectedRouter,
              onTap: () => _showRouterPicker(isDark),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterButton(
              icon: LucideIcons.calendar,
              label: _selectedDateRange,
              onTap: () => _showDatePicker(isDark),
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({required IconData icon, required String label, required VoidCallback onTap, required bool isDark}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: PaceColors.getBorder(isDark)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: PaceColors.getDimText(isDark)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(LucideIcons.chevronDown, size: 14, color: PaceColors.getDimText(isDark)),
          ],
        ),
      ),
    );
  }

  void _showRouterPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Mikrotik Station', 
                    style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w700, color: PaceColors.getPrimaryText(isDark)),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _routerNames.length,
                itemBuilder: (context, index) {
                  final r = _routerNames[index];
                  final isSelected = _selectedRouter == r;
                  return ListTile(
                    dense: true,
                    leading: Icon(LucideIcons.router, size: 16, color: isSelected ? PaceColors.purple : PaceColors.getDimText(isDark)),
                    title: Text(
                      r,
                      style: GoogleFonts.figtree(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? PaceColors.purple : PaceColors.getPrimaryText(isDark)),
                    ),
                    trailing: isSelected ? const Icon(LucideIcons.check, size: 16, color: PaceColors.purple) : null,
                    onTap: () {
                      setState(() => _selectedRouter = r);
                      Navigator.pop(context);
                      _fetchEntries(forceRefresh: true);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDatePicker(bool isDark) {
    final ranges = ['All Time', 'Today', 'Yesterday', 'This Week', 'This Month'];
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Time Range', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w700, color: PaceColors.getPrimaryText(isDark))),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            ...ranges.map((range) {
              final isSelected = _selectedDateRange == range;
              return ListTile(
                dense: true,
                leading: Icon(LucideIcons.calendar, size: 16, color: isSelected ? PaceColors.purple : PaceColors.getDimText(isDark)),
                title: Text(
                  range,
                  style: GoogleFonts.figtree(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? PaceColors.purple : PaceColors.getPrimaryText(isDark)),
                ),
                trailing: isSelected ? const Icon(LucideIcons.check, size: 16, color: PaceColors.purple) : null,
                onTap: () {
                  setState(() => _selectedDateRange = range);
                  Navigator.pop(context);
                  _fetchEntries(forceRefresh: true);
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
            _fetchEntries(); 
          },
          style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getPrimaryText(isDark)),
          decoration: InputDecoration(
            hintText: 'Search phone, MAC, voucher code...',
            hintStyle: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 13),
            prefixIcon: Icon(LucideIcons.search, size: 16, color: PaceColors.getDimText(isDark)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark),
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('CLIENT IDENTIFIER', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark), letterSpacing: 0.5))),
          Expanded(flex: 2, child: Center(child: Text('AMOUNT', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark), letterSpacing: 0.5)))),
          Expanded(flex: 2, child: Text('STATUS', textAlign: TextAlign.right, style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark), letterSpacing: 0.5))),
        ],
      ),
    );
  }

  Widget _buildEntryItem(dynamic entry, bool isDark, {bool isLast = false}) {
    final bool isActive = (entry['active'] == true || entry['active'] == 1 || entry['active'] == '1');
    final phone = (entry['phone'] ?? entry['user_phone'] ?? 'Client').toString();
    final code = (entry['code'] ?? entry['voucher_code'] ?? '').toString();
    final router = (entry['router'] ?? entry['router_name'] ?? 'Mikrotik').toString();
    final amount = (entry['amount'] ?? '0').toString();

    return InkWell(
      onTap: () => _showDetailModal(entry, isDark),
      child: Container(
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: PaceColors.getBorder(isDark), width: 0.8)),
        ),
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
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (code.isNotEmpty) ...[
                        Text(
                          code,
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        Text('•', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 10)),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          router,
                          style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  'KES $amount',
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: PaceColors.green),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: PaceBadge(
                  label: isActive ? 'Active' : 'Ended',
                  variant: isActive ? BadgeVariant.success : BadgeVariant.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailModal(dynamic entry, bool isDark) {
    final bool isActive = (entry['active'] == true || entry['active'] == 1 || entry['active'] == '1');
    final bool isUsed = (entry['used'] == true || entry['used'] == 1 || entry['used'] == '1');
    final dynamic entryId = entry['id'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: PaceColors.getCard(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                  decoration: BoxDecoration(color: PaceColors.getBorder(isDark), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Session Details', style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w700, color: PaceColors.purple)),
                  IconButton(icon: const Icon(LucideIcons.x, size: 18), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Phone / Client', entry['phone']?.toString() ?? 'N/A', isDark),
              _buildDetailRow('Voucher PIN', entry['code']?.toString() ?? 'None', isDark),
              _buildDetailRow('Amount Paid', 'KES ${entry['amount'] ?? 0}', isDark),
              _buildDetailRow('Mikrotik Station', entry['router_name'] ?? entry['router'] ?? 'Default', isDark),
              _buildDetailRow('MAC Address', entry['mac']?.toString() ?? 'N/A', isDark),
              _buildDetailRow('Timeline Started', entry['created'] ?? entry['created_at'] ?? 'N/A', isDark),
              _buildDetailRow('Session Expires', entry['expires']?.toString() ?? 'N/A', isDark),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Status', style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark))),
                    PaceBadge(
                      label: isActive ? 'Active' : 'Expired',
                      variant: isActive ? BadgeVariant.success : BadgeVariant.secondary,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('MikroTik Used', style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark))),
                    Row(
                      children: [
                        PaceBadge(
                          label: isUsed ? 'Yes' : 'No',
                          variant: isUsed ? BadgeVariant.success : BadgeVariant.destructive,
                        ),
                        if (entryId != null) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: (isActive && _reinitializingId == null) 
                              ? () => _handleReinitialize(entryId, setModalState)
                              : null,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isActive ? PaceColors.purple.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: _reinitializingId == entryId
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: PaceColors.purple))
                                : Icon(LucideIcons.refreshCw, size: 14, color: isActive ? PaceColors.purple : Colors.grey),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark))),
          Text(value, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
        ],
      ),
    );
  }
}
