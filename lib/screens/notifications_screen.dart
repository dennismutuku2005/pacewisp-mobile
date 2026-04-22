import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isRefreshing = true);
    final res = await _apiService.fetchData('notifications'); 
    if (mounted) {
      setState(() {
        _notifications = res?['data'] ?? [];
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _markRead(String? id) async {
    // Optimistic UI
    setState(() {
      if (id == null) {
        for (var n in _notifications) { n['is_read'] = 1; }
      } else {
        final idx = _notifications.indexWhere((n) => n['id'].toString() == id);
        if (idx != -1) _notifications[idx]['is_read'] = 1;
      }
    });
    
    // Call API (Add mark_notification_read to ApiService if needed)
    // await _apiService.sendAction('mark_notification_read', {'id': id});
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _fetchNotifications,
        color: PaceColors.purple,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('NOTIFICATIONS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
                      Text('SYSTEM ALERTS & CONNECTION ERRORS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ]),
                  ),
                  TextButton(
                    onPressed: () => _markRead(null),
                    child: Text('MARK ALL READ', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 10))
                : _notifications.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildNotificationCard(_notifications[index], isDark),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.bell, size: 48, color: PaceColors.getDimText(isDark).withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('NO NOTIFICATIONS', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(dynamic n, bool isDark) {
    final bool isUnread = n['is_read'] == 0 || n['is_read'] == false;
    final type = n['type']?.toString().toUpperCase() ?? 'ALERT';
    
    return InkWell(
      onTap: isUnread ? () => _markRead(n['id'].toString()) : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread ? PaceColors.purple.withOpacity(isDark ? 0.05 : 0.03) : PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isUnread ? PaceColors.purple.withOpacity(0.3) : PaceColors.getBorder(isDark), width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: (isUnread ? PaceColors.purple : PaceColors.getDimText(isDark)).withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(LucideIcons.alertCircle, size: 16, color: isUnread ? PaceColors.purple : PaceColors.getDimText(isDark)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(type.replaceAll('_', ' '), style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.black, color: PaceColors.purple, letterSpacing: 1)),
                      Text(n['created_at']?.toString().split(' ')[0] ?? '', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(n['error_message'] ?? 'No detail provided', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark), height: 1.4)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(LucideIcons.user, size: 10, color: PaceColors.purple).pOnly(right: 4),
                      Text(n['user_mac'] ?? 'Unknown MAC', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
                    ],
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

extension PaddingExtension on Widget {
  Widget pOnly({double left = 0, double right = 0, double top = 0, double bottom = 0}) => Padding(padding: EdgeInsets.only(left: left, right: right, top: top, bottom: bottom), child: this);
}
