import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/empty_state.dart';
import '../components/skeleton.dart';
import '../components/search_bar.dart';
import 'customer_history_screen.dart';

class ActiveCustomersScreen extends StatefulWidget {
  const ActiveCustomersScreen({super.key});

  @override
  State<ActiveCustomersScreen> createState() => _ActiveCustomersScreenState();
}

class _ActiveCustomersScreenState extends State<ActiveCustomersScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _active = [];
  int _page = 1;
  int _total = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchData(pageNum: 1);
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

  Future<void> _fetchData({required int pageNum}) async {
    if (pageNum == 1) setState(() => _isLoading = true);

    try {
      final res = await _apiService.getActiveConnections(
        page: pageNum,
        limit: 25,
        search: _search,
        forceRefresh: true,
      );

      if (mounted && res != null) {
        setState(() {
          final newItems = res['data'] ?? res['users'] ?? res['customers'] ?? [];
          if (pageNum == 1) {
            _active = newItems;
          } else {
            _active.addAll(newItems);
          }
          _total = res['pagination']?['total'] ?? _active.length;
          _hasMore = res['pagination']?['has_more'] ?? false;
          _page = pageNum;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMore() async {
    setState(() => _isLoadingMore = true);
    try {
      await _fetchData(pageNum: _page + 1);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Column(
      children: [
        _buildHeader(isDark),
        _buildControls(isDark),
        Expanded(
          child: _isLoading && _active.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 8))
              : RefreshIndicator(
                  onRefresh: () => _fetchData(pageNum: 1),
                  color: PaceColors.purple,
                  child: _active.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: PaceEmptyState(
                            title: 'No Active Sessions',
                            subtitle: 'Connected hotspot devices and authenticated users will appear here in real-time.',
                            onRetry: () => _fetchData(pageNum: 1),
                            isDark: isDark,
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                          itemCount: _active.length + (_isLoadingMore ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index < _active.length) {
                              return _buildActiveCard(_active[index], isDark);
                            }
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
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
                'Live Connections',
                style: GoogleFonts.figtree(
                  color: PaceColors.getPrimaryText(isDark),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Real-time authenticated hotspot sessions',
                style: GoogleFonts.figtree(
                  color: PaceColors.getDimText(isDark),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (_total > 0)
            PaceBadge(
              label: '$_total Online',
              variant: BadgeVariant.success,
            ),
        ],
      ),
    );
  }

  Widget _buildControls(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: PaceSearchBar(
        hint: 'Search by phone number or voucher code...',
        isDark: isDark,
        onChanged: (val) {
          _search = val;
          _fetchData(pageNum: 1);
        },
      ),
    );
  }

  Widget _buildActiveCard(dynamic u, bool isDark) {
    final phone = u['phone']?.toString() ?? 'Guest';
    final code = u['mpesa_code']?.toString() ?? u['voucher']?.toString() ?? 'Online Session';
    final plan = u['plan']?.toString() ?? 'Hotspot Plan';
    final uptime = u['uptime']?.toString() ?? 'Active';

    return InkWell(
      onTap: () {
        if (u['phone'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CustomerHistoryScreen(phone: u['phone'].toString())),
          );
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PaceColors.getBorder(isDark)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PaceColors.emerald.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.wifi, color: PaceColors.emerald, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        phone,
                        style: GoogleFonts.figtree(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: PaceColors.getPrimaryText(isDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PaceBadge(label: 'Online', variant: BadgeVariant.success),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$plan • $code',
                    style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  uptime,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PaceColors.purple,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(LucideIcons.chevronRight, size: 14, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
