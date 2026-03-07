import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSyncMemory();
    _fetchCachedThenLive();
    _loadRouters();
    _scrollController.addListener(_onScroll);
  }

  void _loadSyncMemory() {
    final filters = _parseDateRange(_selectedDateRange);
    final router = _selectedRouter == 'All Routers' ? null : _selectedRouter;
    final mem = _apiService.getMemoryCached('entries', params: {
      'search': _search,
      'router': router,
      'startDate': filters['startDate'],
      'endDate': filters['endDate'],
      'page': 1
    });

    if (mem != null) {
      _entries = _extractEntries(mem);
      _hasMore = _extractHasMore(mem);
      _total = _extractTotal(mem);
      _isLoading = false;
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchMoreEntries();
      }
    }
  }

  Future<void> _loadRouters() async {
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
    return {}; // All Time
  }

  Future<void> _fetchCachedThenLive() async {
    final filters = _parseDateRange(_selectedDateRange);
    final router = _selectedRouter == 'All Routers' ? null : _selectedRouter;

    // 1. SILENT CACHE LOAD
    final cached = await _apiService.getEntries(
      search: _search, 
      page: 1, 
      router: router,
      startDate: filters['startDate'],
      endDate: filters['endDate'],
      forceRefresh: false
    );
    if (mounted && cached != null && _entries.isEmpty) {
      setState(() {
        _entries = _extractEntries(cached);
        _hasMore = _extractHasMore(cached);
        _total = _extractTotal(cached);
        _isLoading = false;
      });
    }

    // 2. LIVE REFRESH
    final live = await _apiService.getEntries(
      search: _search, 
      page: 1, 
      router: router,
      startDate: filters['startDate'],
      endDate: filters['endDate'],
      forceRefresh: true
    );
    if (mounted) {
      if (live != null) {
        setState(() {
          _entries = _extractEntries(live);
          _hasMore = _extractHasMore(live);
          _total = _extractTotal(live);
          _page = 1;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchMoreEntries() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final filters = _parseDateRange(_selectedDateRange);
    final router = _selectedRouter == 'All Routers' ? null : _selectedRouter;

    final res = await _apiService.getEntries(
      search: _search, 
      page: nextPage, 
      router: router,
      startDate: filters['startDate'],
      endDate: filters['endDate'],
      forceRefresh: true
    );

    if (mounted && res != null) {
      setState(() {
        final newItems = _extractEntries(res);
        _entries.addAll(newItems);
        _hasMore = _extractHasMore(res);
        _page = nextPage;
        _isLoadingMore = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  List<dynamic> _extractEntries(Map<String, dynamic> res) {
    final d = res['data'];
    if (d is List) return d;
    if (d is Map) return d['entries'] ?? d['recent_transactions'] ?? d['data'] ?? [];
    return res['entries'] ?? [];
  }

  bool _extractHasMore(Map<String, dynamic> res) {
    final p = res['pagination'] ?? res['data']?['pagination'];
    if (p is Map) return p['has_more'] ?? false;
    return false;
  }

  int _extractTotal(Map<String, dynamic> res) {
    final p = res['pagination'] ?? res['data']?['pagination'];
    if (p is Map) return p['total'] ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Container(
      color: PaceColors.getBackground(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(isDark),
          _buildGlobalFilters(isDark),
          _buildSearchBox(isDark),
          _buildTableHeader(isDark),
          Expanded(
            child: _isLoading && _entries.isEmpty 
              ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 10))
              : RefreshIndicator(
                  onRefresh: () => _fetchCachedThenLive(),
                  color: PaceColors.purple,
                  child: ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                    itemCount: _entries.length + (_isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                    itemBuilder: (context, index) {
                      if (index == _entries.length) {
                        return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)));
                      }
                      return _buildEntryItem(_entries[index], isDark);
                    },
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('CONNECTION ENTRIES', textAlign: TextAlign.left, style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
          Text('REAL-TIME ACCESS LOGS & SESSIONS', textAlign: TextAlign.left, style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildGlobalFilters(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Row(children: [
        Expanded(child: _buildFilterButton(icon: Icons.router_rounded, label: _selectedRouter, onTap: () => _showRouterPicker(isDark), isDark: isDark)),
        const SizedBox(width: 8),
        Expanded(child: _buildFilterButton(icon: Icons.calendar_today_rounded, label: _selectedDateRange, onTap: () => _showDatePicker(isDark), isDark: isDark)),
      ]),
    );
  }

  Widget _buildFilterButton({required IconData icon, required String label, required VoidCallback onTap, required bool isDark}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
        child: Row(children: [Icon(icon, size: 14, color: PaceColors.getDimText(isDark)), const SizedBox(width: 8), Expanded(child: Text(label, style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark)), overflow: TextOverflow.ellipsis)), Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: PaceColors.getDimText(isDark))]),
      ),
    );
  }

  void _showRouterPicker(bool isDark) {
    showModalBottomSheet(context: context, backgroundColor: PaceColors.getCard(isDark), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))), builder: (context) => Container(padding: const EdgeInsets.symmetric(vertical: 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Text('STATION NODE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 2))), ..._routerNames.map((r) => _buildListTile(label: r, icon: Icons.router_outlined, isSelected: _selectedRouter == r, isDark: isDark, onTap: () { setState(() => _selectedRouter = r); Navigator.pop(context); _fetchCachedThenLive(); })).toList()])));
  }

  void _showDatePicker(bool isDark) {
    final ranges = ['All Time', 'Today', 'Yesterday', 'This Week', 'This Month'];
    showModalBottomSheet(context: context, backgroundColor: PaceColors.getCard(isDark), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))), builder: (context) => Container(padding: const EdgeInsets.symmetric(vertical: 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Text('TIME RANGE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 2))), ...ranges.map((range) => _buildListTile(label: range, icon: Icons.access_time_rounded, isSelected: _selectedDateRange == range, isDark: isDark, onTap: () { setState(() => _selectedDateRange = range); Navigator.pop(context); _fetchCachedThenLive(); })).toList()])));
  }

  Widget _buildListTile({required String label, required IconData icon, required bool isSelected, required bool isDark, required VoidCallback onTap}) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1), child: ListTile(onTap: onTap, dense: true, selected: isSelected, selectedTileColor: PaceColors.purple.withOpacity(0.08), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), leading: Icon(icon, size: 16, color: isSelected ? PaceColors.purple : PaceColors.getDimText(isDark)), title: Text(label, style: GoogleFonts.figtree(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? PaceColors.purple : PaceColors.getPrimaryText(isDark)))));
  }

  Widget _buildSearchBox(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
        child: TextField(
          onChanged: (val) { setState(() => _search = val); _fetchCachedThenLive(); },
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
          decoration: InputDecoration(
            hintText: 'Search identifiers, MACs, codes...', 
            hintStyle: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 12), 
            icon: Icon(Icons.search_rounded, color: PaceColors.getDimText(isDark), size: 20), 
            border: InputBorder.none, 
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(bool isDark) {
    return Container(
      color: PaceColors.getSurface(isDark),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('IDENTIFICATION', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
          Expanded(flex: 2, child: Center(child: Text('PAID', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1)))),
          Expanded(flex: 2, child: Text('STATUS', textAlign: TextAlign.right, style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
        ],
      ),
    );
  }

  Widget _buildEntryItem(dynamic entry, bool isDark) {
    final bool isActive = (entry['active'] == true || entry['active'] == 1);
    
    return InkWell(
      onTap: () => _showDetailModal(entry, isDark),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry['phone'] ?? 'SYSTEM', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w800, color: PaceColors.purple, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(entry['code']?.toString().toUpperCase() ?? 'NO_CODE', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      const SizedBox(width: 6),
                      Container(width: 3, height: 3, decoration: BoxDecoration(color: PaceColors.getBorder(isDark), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(child: Text((entry['router'] ?? entry['router_name'] ?? 'NODE').toString().toUpperCase(), style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Text('KES ${entry['amount']}', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: PaceColors.emerald)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PaceBadge(label: isActive ? 'ACTIVE' : 'EXPIRED', variant: isActive ? BadgeVariant.success : BadgeVariant.secondary),
                  const SizedBox(height: 6),
                  Text(entry['created'] ?? '', style: GoogleFonts.figtree(fontSize: 7, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailModal(dynamic entry, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: PaceColors.getBorder(isDark), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Icon(Icons.smartphone_rounded, color: PaceColors.purple, size: 32),
            const SizedBox(height: 12),
            Text('ENTRY LOG DETAILS', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1.5)),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.2, crossAxisSpacing: 16, mainAxisSpacing: 16),
                children: [
                   _buildPopupItem('PHONE NUMBER', entry['phone'] ?? 'SYSTEM', isDark, isMono: true),
                   _buildPopupItem('M-PESA CODE', entry['code'] ?? 'NO_CODE', isDark, isMono: true),
                   _buildPopupItem('MAC ADDRESS', entry['mac'] ?? 'UNKNOWN', isDark, isMono: true, smallValue: true),
                   _buildPopupItem('STATION', entry['router'] ?? 'DEFAULT', isDark),
                   _buildPopupItem('AMOUNT PAID', 'KES ${entry['amount']}', isDark, valueColor: PaceColors.purple),
                   _buildPopupItem('STATUS', (entry['active'] == true || entry['active'] == 1) ? 'ACTIVE' : 'EXPIRED', isDark, valueColor: (entry['active'] == true || entry['active'] == 1) ? PaceColors.emerald : Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            Padding(
               padding: const EdgeInsets.all(24),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text('TIMELINE', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
                   const SizedBox(height: 8),
                   Row(children: [
                     Icon(Icons.circle, size: 6, color: PaceColors.getDimText(isDark)),
                     const SizedBox(width: 8),
                     Text('CREATED: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark))),
                     Text(entry['created'] ?? 'N/A', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                   ]),
                   const SizedBox(height: 4),
                   Row(children: [
                     Icon(Icons.circle, size: 6, color: PaceColors.purple),
                     const SizedBox(width: 8),
                     Text('EXPIRES: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.purple)),
                     Text(entry['expires'] ?? 'N/A', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.purple)),
                   ]),
                 ],
               ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupItem(String label, String value, bool isDark, {bool isMono = false, Color? valueColor, bool smallValue = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: isMono ? GoogleFonts.jetBrainsMono(fontSize: smallValue ? 10 : 12, fontWeight: FontWeight.w700, color: valueColor ?? PaceColors.purple) : GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor ?? PaceColors.getPrimaryText(isDark))),
      ],
    );
  }
}
