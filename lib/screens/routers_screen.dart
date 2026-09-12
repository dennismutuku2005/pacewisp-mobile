import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/empty_state.dart';
import '../components/skeleton.dart';
import '../components/otp_modal.dart';
import '../components/overlay_loader.dart';

class RoutersScreen extends StatefulWidget {
  const RoutersScreen({super.key});

  @override
  State<RoutersScreen> createState() => _RoutersScreenState();
}

class _RoutersScreenState extends State<RoutersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _routers = [];
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchRouters();
  }

  Future<void> _fetchRouters() async {
    setState(() => _isLoading = true);
    final res = await _apiService.getRouters(forceRefresh: true);
    if (mounted) {
      final fresh = res?['data'] ?? [];
      setState(() {
        _routers = fresh.map((item) => {...item, 'isPinging': true}).toList();
        _isLoading = false;
      });
      _startAutoPing();
    }
  }

  void _startAutoPing() {
    for (var i = 0; i < _routers.length; i++) {
      _pingSingleRouter(i);
    }
  }

  Future<void> _pingSingleRouter(int index) async {
    if (index >= _routers.length) return;
    final r = _routers[index];
    try {
      final res = await _apiService.pingRouter(r['ip_address'], r['winbox_port'] ?? 8728);
      final stats = res?['data'] ?? res;
      final bool isOnline = stats?['status'] == 'online' || stats?['cpu'] != null;
      if (mounted && index < _routers.length) {
        setState(() {
          _routers[index] = {
            ..._routers[index],
            'stats': isOnline ? stats : null,
            'status': isOnline ? 'active' : 'inactive',
            'isPinging': false,
          };
        });
      }
    } catch (_) {
      if (mounted && index < _routers.length) {
        setState(() {
          _routers[index] = {..._routers[index], 'isPinging': false, 'status': 'inactive'};
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return PaceOverlayLoader(
      isLoading: _isProcessing,
      message: 'Executing router command...',
      child: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: _isLoading && _routers.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: RouterSkeleton(count: 4),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchRouters,
                    color: PaceColors.purple,
                    child: _routers.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: PaceEmptyState(
                              title: 'No Mikrotik Routers Found',
                              subtitle: 'Ensure your Mikrotik node is registered and reachable via API or VPN tunnel.',
                              onRetry: _fetchRouters,
                              isDark: isDark,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                            itemCount: _routers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) => _buildRouterCard(_routers[index], index, isDark, settings),
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
                'Mikrotik Routers',
                style: GoogleFonts.figtree(
                  color: PaceColors.getPrimaryText(isDark),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Node health, synchronization and remote control',
                style: GoogleFonts.figtree(
                  color: PaceColors.getDimText(isDark),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              _startAutoPing();
            },
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            tooltip: 'Ping all nodes',
          ),
        ],
      ),
    );
  }

  Widget _buildRouterCard(dynamic r, int index, bool isDark, SettingsProvider settings) {
    final bool isOnline = r['status'] == 'active';
    final bool isPinging = r['isPinging'] == true;
    final stats = r['stats'];
    final routerName = r['router_name']?.toString() ?? 'Mikrotik Node';
    final ipAddress = r['ip_address']?.toString() ?? '0.0.0.0';
    final port = r['winbox_port']?.toString() ?? '8728';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isPinging
                      ? Colors.grey.withOpacity(0.1)
                      : (isOnline ? PaceColors.emerald.withOpacity(0.1) : Colors.red.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.router,
                  color: isPinging
                      ? Colors.grey
                      : (isOnline ? PaceColors.emerald : Colors.red),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            routerName,
                            style: GoogleFonts.figtree(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: PaceColors.getPrimaryText(isDark),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isPinging)
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 2, color: PaceColors.purple),
                          )
                        else
                          PaceBadge(
                            label: isOnline ? 'Online' : 'Offline',
                            variant: isOnline ? BadgeVariant.success : BadgeVariant.danger,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$ipAddress : $port',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: PaceColors.getDimText(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _pingSingleRouter(index),
                icon: const Icon(LucideIcons.activity, size: 16),
                tooltip: 'Ping',
                color: PaceColors.purple,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: PaceColors.getSurface(isDark),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildStatItem('CPU Load', isPinging ? '...' : (stats?['cpu'] ?? (isOnline ? 'Active' : 'N/A')), isDark),
                Container(width: 1, height: 24, color: PaceColors.getBorder(isDark)),
                _buildStatItem('Uptime', isPinging ? '...' : (stats?['uptime'] ?? (isOnline ? 'Online' : 'Offline')), isDark),
                Container(width: 1, height: 24, color: PaceColors.getBorder(isDark)),
                _buildStatItem('Memory', isPinging ? '...' : (stats?['free_memory'] ?? 'OK'), isDark),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Winbox: $port',
                style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark)),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _handleRestart(r),
                    icon: const Icon(LucideIcons.power, size: 14, color: Colors.red),
                    label: Text(
                      'Reboot',
                      style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: PaceColors.getPrimaryText(isDark),
            ),
          ),
        ],
      ),
    );
  }

  void _handleRestart(dynamic r) async {
    final isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;
    final routerName = r['router_name'] ?? 'this router';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reboot Router',
          style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
        ),
        content: Text(
          'Are you sure you want to reboot "$routerName"? Connected customer sessions will temporarily drop until reboot completes.',
          style: GoogleFonts.figtree(fontSize: 14, color: PaceColors.getDimText(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Reboot Now', style: GoogleFonts.figtree(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      try {
        final res = await _apiService.restartRouter(r['ip_address'], r['winbox_port'] ?? 8728);
        if (res?['status'] == 'otp_required') {
          _showOtpModal((code) => _handleRestart(r));
        } else if (res?['status'] == 'success') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Reboot command dispatched', style: GoogleFonts.figtree()), backgroundColor: PaceColors.emerald),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(res?['message'] ?? 'Reboot command failed', style: GoogleFonts.figtree()), backgroundColor: Colors.red.shade700),
            );
          }
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  void _showOtpModal(Function(String) onVerify) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OtpModal(
        phoneNumber: Provider.of<SettingsProvider>(context, listen: false).activeAccount?.phone ?? '',
        onVerify: (code) {
          Navigator.pop(context);
          onVerify(code);
        },
      ),
    );
  }
}
