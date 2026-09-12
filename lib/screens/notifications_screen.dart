import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
import '../components/empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _notifications = [];
  int _page = 1;
  int _total = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  bool _hasMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNotifications(page: 1);
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
        _fetchMoreNotifications();
      }
    }
  }

  Future<void> _fetchNotifications({int page = 1, bool forceRefresh = false}) async {
    if (page == 1) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final res = await _apiService.getNotifications(page: page, limit: 20, forceRefresh: forceRefresh);
      if (mounted) {
        if (res != null && (res['status'] == 'success' || res['status'] == 200)) {
          final List<dynamic> newItems = (res['data'] is List) ? (res['data'] as List) : [];
          final pagination = res['pagination'] as Map<String, dynamic>? ?? {};
          final hasMore = pagination['has_more'] == true || pagination['has_more'] == 1;
          final total = int.tryParse(pagination['total']?.toString() ?? '') ?? newItems.length;

          setState(() {
            _page = page;
            _hasMore = hasMore;
            _total = total;
            _notifications = newItems;
            _isLoading = false;
            _isRefreshing = false;
          });
        } else {
          setState(() {
            _error = res?['message']?.toString() ?? 'Failed to load notifications';
            _isLoading = false;
            _isRefreshing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load notifications: $e';
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _fetchMoreNotifications() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _page + 1;
      final res = await _apiService.getNotifications(page: nextPage, limit: 20, forceRefresh: true);
      if (mounted && res != null && (res['status'] == 'success' || res['status'] == 200)) {
        final List<dynamic> newItems = (res['data'] is List) ? (res['data'] as List) : [];
        final pagination = res['pagination'] as Map<String, dynamic>? ?? {};
        final hasMore = pagination['has_more'] == true || pagination['has_more'] == 1;

        setState(() {
          _page = nextPage;
          _hasMore = hasMore;
          final existingIds = _notifications.map((item) => item['id']?.toString()).toSet();
          for (var item in newItems) {
            if (!existingIds.contains(item['id']?.toString())) {
              _notifications.add(item);
            }
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await _fetchNotifications(page: 1, forceRefresh: true);
  }

  Future<void> _markAllRead() async {
    try {
      final res = await _apiService.markNotificationRead(null);
      if (res != null && (res['status'] == 'success' || res['status'] == 200)) {
        if (mounted) {
          setState(() {
            _notifications = _notifications.map((n) {
              final copy = Map<String, dynamic>.from(n as Map);
              copy['is_read'] = 1;
              return copy;
            }).toList();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All notifications marked as read'),
              backgroundColor: PaceColors.emerald,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: PaceColors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _markOneRead(dynamic id) async {
    try {
      final res = await _apiService.markNotificationRead(id);
      if (res != null && (res['status'] == 'success' || res['status'] == 200)) {
        if (mounted) {
          setState(() {
            final idx = _notifications.indexWhere((n) => n['id']?.toString() == id.toString());
            if (idx != -1) {
              final copy = Map<String, dynamic>.from(_notifications[idx] as Map);
              copy['is_read'] = 1;
              _notifications[idx] = copy;
            }
          });
        }
      }
    } catch (_) {}
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr.toString());
      return DateFormat('MMM d, HH:mm').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }

  BadgeVariant _getCategoryVariant(String type) {
    final t = type.toLowerCase();
    if (t.contains('normal_payment') || t.contains('payment')) return BadgeVariant.success;
    if (t.contains('reconnection') || t.contains('voucher')) return BadgeVariant.primary;
    if (t.contains('mac_reconnection') || t.contains('warning')) return BadgeVariant.warning;
    return BadgeVariant.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: PaceColors.purple,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(isDark)),
              if (_error != null)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PaceColors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PaceColors.red.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.alertCircle, size: 16, color: PaceColors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.figtree(color: PaceColors.red, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
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
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 640),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTableHeader(isDark),
                            if (_isLoading)
                              _buildSkeletonTable(isDark)
                            else if (_notifications.isEmpty)
                              Container(
                                width: 640,
                                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                                child: PaceEmptyState(
                                  title: 'No Notifications',
                                  subtitle: 'No MikroTik connection errors, system alerts, or payment logs recorded.',
                                  onRetry: () => _fetchNotifications(page: 1, forceRefresh: true),
                                  isDark: isDark,
                                ),
                              )
                            else ...[
                              ..._notifications.asMap().entries.map((entry) {
                                final index = entry.key;
                                final notif = entry.value;
                                final isLast = index == _notifications.length - 1 && !_isLoadingMore;
                                return _buildNotificationRow(notif, isDark, isLast: isLast);
                              }),
                              if (_isLoadingMore)
                                Container(
                                  width: 640,
                                  padding: const EdgeInsets.all(16),
                                  alignment: Alignment.center,
                                  child: const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: PaceColors.purple),
                                  ),
                                )
                              else
                                Container(
                                  width: 640,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: PaceColors.getSurface(isDark),
                                    border: Border(top: BorderSide(color: PaceColors.getBorder(isDark), width: 0.8)),
                                  ),
                                  child: Text(
                                    _hasMore
                                        ? 'Scroll down for more alerts'
                                        : 'End of notifications • $_total alerts tracked',
                                    style: GoogleFonts.figtree(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: PaceColors.getDimText(isDark),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
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

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.bell, size: 20, color: PaceColors.purple),
                  const SizedBox(width: 8),
                  Text(
                    'Notifications',
                    style: GoogleFonts.figtree(
                      color: PaceColors.purple,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  InkWell(
                    onTap: _isRefreshing ? null : _handleRefresh,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: PaceColors.purple.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: PaceColors.purple.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          _isRefreshing
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: PaceColors.purple),
                                )
                              : const Icon(LucideIcons.refreshCw, size: 12, color: PaceColors.purple),
                          const SizedBox(width: 6),
                          Text(
                            'Refresh',
                            style: GoogleFonts.figtree(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: PaceColors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _markAllRead,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: PaceColors.getSurface(isDark),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: PaceColors.getBorder(isDark)),
                      ),
                      child: Text(
                        'Mark All Read',
                        style: GoogleFonts.figtree(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: PaceColors.getDimText(isDark),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'View and manage MikroTik connection errors and system alerts.',
            style: GoogleFonts.figtree(
              color: PaceColors.getDimText(isDark),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isDark) {
    return Container(
      width: 640,
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark),
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 32, child: Center(child: Text('STATUS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)))),
          const SizedBox(width: 12),
          SizedBox(
            width: 250,
            child: Text(
              'ERROR DETAILS',
              style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark), letterSpacing: 0.5),
            ),
          ),
          SizedBox(
            width: 140,
            child: Text(
              'CLIENT MAC',
              style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark), letterSpacing: 0.5),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              'TIME',
              style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark), letterSpacing: 0.5),
            ),
          ),
          const SizedBox(
            width: 60,
            child: Text(
              'ACTION',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonTable(bool isDark) {
    return Column(
      children: List.generate(
        8,
        (index) => Container(
          width: 640,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: index < 7 ? Border(bottom: BorderSide(color: PaceColors.getBorder(isDark), width: 0.8)) : null,
          ),
          child: Row(
            children: [
              const SizedBox(width: 32, child: Center(child: PaceSkeleton(height: 10, width: 10, borderRadius: 5))),
              const SizedBox(width: 12),
              SizedBox(
                width: 250,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PaceSkeleton(height: 12, width: 200, borderRadius: 4),
                    const SizedBox(height: 6),
                    PaceSkeleton(height: 10, width: 120, borderRadius: 4),
                  ],
                ),
              ),
              const SizedBox(
                width: 140,
                child: PaceSkeleton(height: 12, width: 110, borderRadius: 4),
              ),
              const SizedBox(
                width: 110,
                child: PaceSkeleton(height: 12, width: 70, borderRadius: 4),
              ),
              const SizedBox(
                width: 60,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: PaceSkeleton(height: 22, width: 44, borderRadius: 6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationRow(dynamic n, bool isDark, {bool isLast = false}) {
    final bool isUnread = n['is_read'] == 0 || n['is_read'] == "0" || n['is_read'] == false;
    final message = (n['error_message'] ?? n['message'] ?? 'Connection error').toString();
    final userMac = (n['user_mac'] ?? 'N/A').toString();
    final createdAt = _formatDate(n['created_at']);

    return InkWell(
      onTap: () => _showNotificationDetailModal(n, isDark),
      child: Container(
        width: 640,
        decoration: BoxDecoration(
          color: isUnread ? PaceColors.purple.withOpacity(isDark ? 0.08 : 0.03) : Colors.transparent,
          border: isLast ? null : Border(bottom: BorderSide(color: PaceColors.getBorder(isDark), width: 0.8)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Status dot or check
            SizedBox(
              width: 32,
              child: Center(
                child: isUnread
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: PaceColors.purple,
                          shape: BoxShape.circle,
                        ),
                      )
                    : Icon(LucideIcons.checkCircle, size: 14, color: PaceColors.getDimText(isDark).withOpacity(0.4)),
              ),
            ),
            const SizedBox(width: 12),
            // Error Details
            SizedBox(
              width: 250,
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle, size: 13, color: PaceColors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      message,
                      style: GoogleFonts.figtree(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PaceColors.getPrimaryText(isDark),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Client MAC
            SizedBox(
              width: 140,
              child: Row(
                children: [
                  Icon(LucideIcons.user, size: 11, color: PaceColors.getDimText(isDark)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      userMac,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: PaceColors.purple,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Date & Time
            SizedBox(
              width: 110,
              child: Row(
                children: [
                  Icon(LucideIcons.clock, size: 11, color: PaceColors.getDimText(isDark)),
                  const SizedBox(width: 5),
                  Text(
                    createdAt,
                    style: GoogleFonts.figtree(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: PaceColors.getDimText(isDark),
                    ),
                  ),
                ],
              ),
            ),
            // Action View button
            SizedBox(
              width: 60,
              child: Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => _showNotificationDetailModal(n, isDark),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: PaceColors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.eye, size: 11, color: PaceColors.purple),
                        const SizedBox(width: 3),
                        Text('View', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w700, color: PaceColors.purple)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationDetailModal(dynamic n, bool isDark) {
    final bool isUnread = n['is_read'] == 0 || n['is_read'] == "0" || n['is_read'] == false;
    final type = (n['type'] ?? 'error').toString();
    final message = (n['error_message'] ?? n['message'] ?? 'Connection error').toString();
    final userMac = (n['user_mac'] ?? 'N/A').toString();
    final createdAt = _formatDate(n['created_at']);
    final dynamic id = n['id'];

    if (isUnread && id != null) {
      _markOneRead(id);
    }

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
                Row(
                  children: [
                    const Icon(LucideIcons.fileText, size: 18, color: PaceColors.purple),
                    const SizedBox(width: 8),
                    Text(
                      'Alert Details #$id',
                      style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w700, color: PaceColors.purple),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PaceColors.getSurface(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PaceColors.getBorder(isDark)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RAW ERROR LOG',
                        style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w700, color: PaceColors.getDimText(isDark)),
                      ),
                      IconButton(
                        style: IconButton.styleFrom(backgroundColor: PaceColors.purple.withOpacity(0.08), padding: const EdgeInsets.all(6)),
                        icon: const Icon(LucideIcons.copy, size: 14, color: PaceColors.purple),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: message));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Error log copied to clipboard'), behavior: SnackBarBehavior.floating),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, color: PaceColors.red, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Category', type.replaceAll('_', ' ').toUpperCase(), isDark, isBadge: true, variant: _getCategoryVariant(type)),
            _buildDetailRow('Client MAC', userMac, isDark, isMono: true),
            _buildDetailRow('Timestamp', createdAt, isDark),
            _buildDetailRow('Status', isUnread ? 'Unread' : 'Read', isDark, isBadge: true, variant: isUnread ? BadgeVariant.warning : BadgeVariant.secondary),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {bool isBadge = false, BadgeVariant variant = BadgeVariant.secondary, bool isMono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark))),
          isBadge
              ? PaceBadge(label: value, variant: variant)
              : Text(
                  value,
                  style: isMono
                      ? GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: PaceColors.purple)
                      : GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
                ),
        ],
      ),
    );
  }
}
