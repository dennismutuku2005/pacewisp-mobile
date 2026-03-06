import 'package:flutter/material.dart';
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
  final TextEditingController _searchController = TextEditingController();
  
  List<dynamic> _entries = [];
  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchEntries();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchMoreEntries();
      }
    }
  }

  Future<void> _fetchEntries({bool force = false}) async {
    if (!force) setState(() => _isLoading = true);
    final res = await _apiService.getEntries(search: _search, page: 1, forceRefresh: force);
    if (mounted) {
      setState(() {
        _entries = res?['data'] ?? [];
        _hasMore = res?['pagination']?['has_more'] ?? false;
        _page = 1;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMoreEntries() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final res = await _apiService.getEntries(search: _search, page: nextPage);
    if (mounted) {
      setState(() {
        final newItems = res?['data'] ?? [];
        _entries.addAll(newItems);
        _hasMore = res?['pagination']?['has_more'] ?? false;
        _page = nextPage;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildSearchBox(),
        Expanded(
          child: _isLoading 
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 10))
            : RefreshIndicator(
                onRefresh: () => _fetchEntries(force: true),
                color: PaceColors.purple,
                child: _entries.isEmpty 
                  ? _buildEmptyState()
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _entries.length + (_isLoadingMore ? 1 : 0),
                      separatorBuilder: (_, __) => const Divider(color: PaceColors.border, height: 1),
                      itemBuilder: (context, index) {
                        if (index == _entries.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)),
                          );
                        }
                        return _buildEntryItem(_entries[index]);
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ENTRIES',
            style: TextStyle(color: PaceColors.purple, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          Text(
            'REAL-TIME CONNECTION LOG',
            style: TextStyle(color: PaceColors.adminDim, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: PaceColors.bgSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PaceColors.border),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() => _search = val);
            _fetchEntries();
          },
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            hintText: 'Search phone or MAC...',
            hintStyle: TextStyle(color: PaceColors.adminDim, fontSize: 12),
            prefixIcon: Icon(Icons.search, color: PaceColors.adminDim, size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryItem(dynamic entry) {
    final bool isActive = entry['active'] == true || entry['status'] == 'active';
    return InkWell(
      onTap: () => _showEntryDetails(entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry['phone'] ?? entry['username'] ?? '',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.purple, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        entry['mac']?.toString().toUpperCase() ?? '',
                        style: const TextStyle(fontSize: 10, color: PaceColors.adminDim, fontFamily: 'monospace'),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: PaceColors.bgSubtle, borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          entry['router']?.toString().replaceAll('_', ' ') ?? 'Node',
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.adminDim),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PaceBadge(
                  label: isActive ? 'Active' : 'Expired',
                  variant: isActive ? BadgeVariant.success : BadgeVariant.secondary,
                ),
                const SizedBox(height: 4),
                Text(
                  entry['created'] ?? entry['start_time'] ?? '',
                  style: const TextStyle(fontSize: 9, color: PaceColors.adminDim, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 48, color: PaceColors.adminDim.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('NO RECORDS FOUND', style: TextStyle(color: PaceColors.adminDim, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  void _showEntryDetails(dynamic entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: PaceColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ENTRY DETAILS', style: TextStyle(color: PaceColors.purple, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 24),
            _buildDetailRow('Phone Number', entry['phone'] ?? entry['username'], isMono: true),
            _buildDetailRow('M-Pesa Code', entry['code'] ?? entry['mpesa_code'], isMono: true),
            _buildDetailRow('MAC Address', entry['mac'], isMono: true),
            _buildDetailRow('Station', entry['router']),
            _buildDetailRow('Amount Paid', 'KES ${entry['amount']}'),
            _buildDetailRow('Timeline', 'Started: ${entry['created'] ?? entry['start_time']}\nExpires: ${entry['expires'] ?? entry['end_time']}'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, {bool isMono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(color: PaceColors.adminDim, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(
            value ?? '-',
            style: TextStyle(
              color: PaceColors.purple,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: isMono ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}
