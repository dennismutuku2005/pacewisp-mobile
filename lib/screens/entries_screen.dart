import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String _selectedRouterId = 'all';
  List<dynamic> _routers = [];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchMoreEntries();
      }
    }
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait<Map<String, dynamic>?>([
      _apiService.getEntries(search: _search, page: 1, router: _selectedRouterId),
      _apiService.getRouters(),
    ]);

    if (mounted) {
      setState(() {
        final res0 = results[0];
        final res1 = results[1];
        
        _entries = res0?['data']?['entries'] ?? res0?['data']?['recent_transactions'] ?? res0?['entries'] ?? res0?['data'] ?? [];
        _hasMore = res0?['pagination']?['has_more'] ?? res0?['data']?['pagination']?['has_more'] ?? false;
        _total = res0?['pagination']?['total'] ?? res0?['data']?['pagination']?['total'] ?? 0;
        
        // Robust router extraction
        final dynamic rawRouters = res1?['data']?['routers'] ?? res1?['routers'] ?? res1?['data'] ?? [];
        final Set<String> unique = {'all'}; // Internal ID for all
        _routers = [];
        if (rawRouters is List) {
          for (var r in rawRouters) {
             _routers.add(r);
          }
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchEntries() async {
    setState(() => _isLoading = true);
    final res = await _apiService.getEntries(search: _search, page: 1, router: _selectedRouterId);
    if (mounted) {
      setState(() {
        _entries = res?['data']?['entries'] ?? res?['entries'] ?? res?['data']?['recent_transactions'] ?? res?['recent_transactions'] ?? res?['data'] ?? [];
        _hasMore = res?['pagination']?['has_more'] ?? res?['data']?['pagination']?['has_more'] ?? false;
        _total = res?['pagination']?['total'] ?? res?['data']?['pagination']?['total'] ?? 0;
        _page = 1;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMoreEntries() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final res = await _apiService.getEntries(search: _search, page: nextPage, router: _selectedRouterId);
    if (mounted) {
      setState(() {
        final newItems = res?['data']?['entries'] ?? res?['entries'] ?? res?['data']?['recent_transactions'] ?? res?['recent_transactions'] ?? res?['data'] ?? [];
        _entries.addAll(newItems);
        _hasMore = res?['pagination']?['has_more'] ?? res?['data']?['pagination']?['has_more'] ?? false;
        _page = nextPage;
        _isLoadingMore = false;
      });
    }
  }

  void _showDetailModal(dynamic entry, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: PaceColors.getBackground(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: PaceColors.getBorder(isDark)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: PaceColors.getBorder(isDark), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('ENTRY DETAILS', style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1.5)),
            const SizedBox(height: 32),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildDetailRow('PHONE NUMBER', entry['phone'] ?? 'SYSTEM', isDark),
                    _buildDetailRow('M-PESA CODE', entry['code'] ?? 'NO_CODE', isDark),
                    _buildDetailRow('MAC ADDRESS', entry['mac'] ?? 'UNKNOWN', isDark),
                    _buildDetailRow('STATION', entry['router'] ?? 'DEFAULT', isDark),
                    _buildDetailRow('AMOUNT PAID', 'KES ${entry['amount']}', isDark, valueColor: PaceColors.purple),
                    _buildDetailRow('STATUS', (entry['active'] == true || entry['active'] == 1) ? 'ACTIVE' : 'EXPIRED', isDark, valueColor: (entry['active'] == true || entry['active'] == 1) ? PaceColors.emerald : Colors.red),
                    _buildDetailRow('TIMELINE', 'Started: ${entry['created']}\nExpires: ${entry['expires'] ?? 'N/A'}', isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5))),
          Expanded(flex: 3, child: Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: valueColor ?? PaceColors.getPrimaryText(isDark)))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Container(
      color: PaceColors.getBackground(isDark),
      child: Column(
        children: [
          _buildHeader(isDark),
          _buildSearchAndFilter(isDark),
          _buildTableHeader(isDark),
          Expanded(
            child: _isLoading 
              ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 8))
              : RefreshIndicator(
                  onRefresh: _fetchEntries,
                  color: PaceColors.purple,
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
                    itemCount: _entries.length + (_isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                    itemBuilder: (context, index) {
                      if (index == _entries.length) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)));
                      return _buildEntryTableItem(_entries[index], isDark);
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('REVENUE ENTRIES', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
              Text('TRANSACTIONAL LEDGER FLOW', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ],
          ),
          IconButton(
            onPressed: () => _fetchEntries(),
            icon: const Icon(Icons.refresh_rounded, color: PaceColors.purple, size: 20),
          )
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
              child: TextField(
                onChanged: (val) { setState(() => _search = val); _fetchEntries(); },
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                decoration: InputDecoration(
                  hintText: 'Search Receipt...', 
                  hintStyle: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 12), 
                  icon: Icon(Icons.receipt_long_rounded, color: PaceColors.getDimText(isDark), size: 18), 
                  border: InputBorder.none, 
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRouterId,
                dropdownColor: PaceColors.getCard(isDark),
                icon: const Icon(Icons.tune_rounded, size: 14, color: PaceColors.purple),
                items: [
                  DropdownMenuItem(value: 'all', child: Text('ALL NODES', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w800, color: PaceColors.getPrimaryText(isDark)))),
                  ..._routers.map((r) {
                    final String name = (r is Map) ? (r['name'] ?? r['router_name'] ?? r['router'])?.toString().toUpperCase() ?? 'NODE' : r.toString().toUpperCase();
                    final String id = (r is Map) ? r['id']?.toString() ?? name : r.toString();
                    return DropdownMenuItem(value: id, child: Text(name, style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w800, color: PaceColors.getPrimaryText(isDark))));
                  }),
                ],
                onChanged: (val) { setState(() => _selectedRouterId = val!); _fetchEntries(); },
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('IDENTIFICATION', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
          Expanded(flex: 2, child: Center(child: Text('PAID', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)))),
          Expanded(flex: 2, child: Text('STATUS', textAlign: TextAlign.right, style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1))),
        ],
      ),
    );
  }

  Widget _buildEntryTableItem(dynamic entry, bool isDark) {
    final bool isActive = (entry['active'] == true || entry['active'] == 1);
    
    return InkWell(
      onTap: () => _showDetailModal(entry, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(entry['phone'] ?? 'SYSTEM', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w800, color: PaceColors.purple, letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(entry['code']?.toString().toUpperCase() ?? 'NO_CODE', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(width: 4),
                      Text('•', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 8)),
                      const SizedBox(width: 4),
                      Text((entry['router'] ?? entry['router_name'] ?? 'NODE').toString().toUpperCase(), style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Text('KES ${entry['amount']}', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w900, color: PaceColors.emerald)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PaceBadge(
                    label: isActive ? 'ACTIVE' : 'EXPIRED', 
                    variant: isActive ? BadgeVariant.success : BadgeVariant.secondary
                  ),
                  const SizedBox(height: 4),
                  Text(entry['created'] ?? entry['created_at'] ?? '', style: GoogleFonts.figtree(fontSize: 7, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
