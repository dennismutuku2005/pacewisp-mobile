import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
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
                  padding: const EdgeInsets.only(bottom: 120),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: PaceColors.getBorder(isDark)),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NOTIFICATIONS', style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            Text('SYSTEM ALERTS & ERRORS', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ]),
          TextButton(onPressed: _markAllRead, child: const Text('MARK ALL READ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1))),
        ],
      ),
    );
  }

  Widget _buildCard(dynamic n, bool isDark) {
    final bool isUnread = n['is_read'] == 0 || n['is_read'] == "0";
    final type = n['type']?.toString().toLowerCase() ?? 'alert';
    
    Color statusColor = PaceColors.purple;
    if (type.contains('payment')) statusColor = PaceColors.emerald;
    if (type.contains('reconnect')) statusColor = Colors.orange;
    if (type.contains('error')) statusColor = Colors.red;

    return InkWell(
      onTap: isUnread ? () => _markOneRead(n['id'].toString()) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isUnread ? PaceColors.purple.withOpacity(0.05) : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.replaceFirst('_', ' ').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(n['user_mac'] ?? 'SYSTEM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(n['error_message'] ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: PaceColors.getPrimaryText(isDark))),
            ),
            const SizedBox(width: 8),
            Text(n['created_at']?.toString().split(' ')[0] ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(LucideIcons.bellOff, size: 48, color: PaceColors.getDimText(isDark).withOpacity(0.1)),
      const SizedBox(height: 16),
      Text('ALL CAUGHT UP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
      Text('No pending system notifications', style: TextStyle(fontSize: 10, color: PaceColors.getDimText(isDark))),
    ]));
  }
}
