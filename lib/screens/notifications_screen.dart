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

  Future<void> _fetchNotifications({bool isRefresh = false}) async {
    if (!isRefresh) setState(() => _isLoading = true);
    setState(() => _isRefreshing = true);
    final res = await _apiService.getNotifications(forceRefresh: true);
    if (mounted) {
      setState(() {
        _notifications = res?['data'] ?? [];
        _isLoading = false;
        _isRefreshing = false;
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
          child: _isLoading 
            ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList())
            : RefreshIndicator(
                onRefresh: () => _fetchNotifications(isRefresh: true),
                color: PaceColors.purple,
                child: _notifications.isEmpty ? _buildEmpty(isDark) : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NOTIFICATIONS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
            Text('SYSTEM ALERTS & CONNECTION ERRORS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ]),
          TextButton(onPressed: _markAllRead, child: Text('MARK ALL READ', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1))),
        ],
      ),
    );
  }

  Widget _buildCard(dynamic n, bool isDark) {
    final bool isUnread = n['is_read'] == 0 || n['is_read'] == "0";
    final type = n['type']?.toString().toLowerCase() ?? 'alert';
    
    BadgeVariant variant = BadgeVariant.info;
    if (type.contains('payment')) variant = BadgeVariant.success;
    if (type.contains('reconnect')) variant = BadgeVariant.warning;
    if (type.contains('error')) variant = BadgeVariant.error;

    return InkWell(
      onTap: isUnread ? () => _markOneRead(n['id'].toString()) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread ? PaceColors.purple.withOpacity(0.05) : PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isUnread ? PaceColors.purple.withOpacity(0.3) : PaceColors.getBorder(isDark), width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: (isUnread ? PaceColors.purple : Colors.grey).withOpacity(0.1), shape: BoxShape.circle), child: Center(child: Icon(LucideIcons.bell, size: 14, color: isUnread ? PaceColors.purple : Colors.grey))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                PaceBadge(label: type.replaceFirst('_', ' ').toUpperCase(), variant: variant),
                Text(n['created_at']?.toString().split(' ')[0] ?? '', style: GoogleFonts.figtree(fontSize: 8, color: Colors.grey)),
              ]),
              const SizedBox(height: 8),
              Text(n['error_message'] ?? '', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark), height: 1.4)),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(LucideIcons.user, size: 10, color: Colors.grey),
                const SizedBox(width: 6),
                Text(n['user_mac'] ?? 'SYSTEM', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
              ]),
            ])),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(LucideIcons.bellOff, size: 48, color: PaceColors.getDimText(isDark).withOpacity(0.1)),
      const SizedBox(height: 16),
      Text('ALL CAUGHT UP', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
      Text('No pending system notifications', style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark))),
    ]));
  }
}
