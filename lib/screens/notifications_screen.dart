import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
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
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications({bool isRefresh = false}) async {
    if (!isRefresh) setState(() => _isLoading = true);
    final res = await _apiService.getNotifications(forceRefresh: true);
    if (mounted) {
      setState(() {
        _notifications = res?['data'] ?? [];
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    final res = await _apiService.markNotificationRead(null);
    if (res?['status'] == 'success') {
      _fetchNotifications(isRefresh: true);
    }
  }

  Future<void> _markOneRead(String id) async {
    final res = await _apiService.markNotificationRead(id);
    if (res?['status'] == 'success') {
      setState(() {
        final idx = _notifications.indexWhere((n) => n['id'].toString() == id);
        if (idx != -1) _notifications[idx]['is_read'] = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Column(
      children: [
        _buildHeader(isDark),
        Expanded(
          child: _isLoading && _notifications.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 8))
              : RefreshIndicator(
                  onRefresh: () => _fetchNotifications(isRefresh: true),
                  color: PaceColors.purple,
                  child: _notifications.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: PaceEmptyState(
                            title: 'All Caught Up',
                            subtitle: 'No unread system alerts, router warnings, or payment errors.',
                            onRetry: () => _fetchNotifications(isRefresh: true),
                            isDark: isDark,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                          itemCount: _notifications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) => _buildCard(_notifications[i], isDark),
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
                'Notifications',
                style: GoogleFonts.figtree(
                  color: PaceColors.getPrimaryText(isDark),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'System alerts, gateway notices, and error logs',
                style: GoogleFonts.figtree(
                  color: PaceColors.getDimText(isDark),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _markAllRead,
            child: Text(
              'Mark all read',
              style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.purple),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(dynamic n, bool isDark) {
    final bool isUnread = n['is_read'] == 0 || n['is_read'] == "0";
    final type = n['type']?.toString().toLowerCase() ?? 'alert';
    final message = n['error_message']?.toString() ?? n['message']?.toString() ?? 'Notification';
    final date = n['created_at']?.toString() ?? '';

    IconData icon = LucideIcons.bell;
    Color iconColor = PaceColors.purple;
    if (type.contains('payment')) {
      icon = LucideIcons.checkCircle;
      iconColor = PaceColors.emerald;
    } else if (type.contains('reconnect')) {
      icon = LucideIcons.refreshCw;
      iconColor = Colors.orange.shade700;
    } else if (type.contains('error') || type.contains('fail')) {
      icon = LucideIcons.alertTriangle;
      iconColor = Colors.red.shade600;
    }

    return InkWell(
      onTap: isUnread ? () => _markOneRead(n['id'].toString()) : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread ? PaceColors.purple.withOpacity(isDark ? 0.08 : 0.04) : PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnread ? PaceColors.purple.withOpacity(0.3) : PaceColors.getBorder(isDark),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        type.replaceAll('_', ' ').toUpperCase(),
                        style: GoogleFonts.figtree(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: PaceColors.purple,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: GoogleFonts.figtree(
                      fontSize: 13,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                      color: PaceColors.getPrimaryText(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark)),
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
