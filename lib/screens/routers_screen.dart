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
  static List<dynamic> _cache = [];
  List<dynamic> _routers = [];
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchRouters();
  }

  Future<void> _fetchRouters() async {
    if (_cache.isNotEmpty) {
      setState(() { _routers = List.from(_cache); _isLoading = false; });
      _startAutoPing();
    }
    final res = await _apiService.getRouters(forceRefresh: true);
    if (mounted) {
      final fresh = res?['data'] ?? [];
      _cache = fresh;
      setState(() { _routers = List.from(fresh); _isLoading = false; });
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
          _routers[index] = { ..._routers[index], 'stats': isOnline ? stats : null, 'status': isOnline ? 'active' : 'inactive' };
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return PaceOverlayLoader(
      isLoading: _isProcessing,
      message: 'Processing...',
      child: Column(
        children: [
          _buildHeader(isDark, settings),
          Expanded(
            child: _isLoading && _routers.isEmpty
              ? const RouterSkeleton(count: 3)
              : RefreshIndicator(
                  onRefresh: _fetchRouters,
                  color: PaceColors.purple,
                  child: _routers.isEmpty
                    ? SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: PaceEmptyState(onRetry: _fetchRouters, isDark: isDark))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        itemCount: _routers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) => _buildRouterCard(_routers[index], isDark, settings),
                      ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, SettingsProvider settings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('YOUR MIKROTIKS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
              Text('CONTROL AND SYNCHRONIZATION STATUS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouterCard(dynamic r, bool isDark, SettingsProvider settings) {
    final bool isOnline = r['status'] == 'active';
    final stats = r['stats'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: PaceColors.getBorder(isDark))
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: isOnline ? PaceColors.emerald.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(LucideIcons.router, color: isOnline ? PaceColors.emerald : Colors.red, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        r['router_name']?.toString().toUpperCase() ?? 'NODE', 
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark), letterSpacing: -0.2)
                      ),
                    ),
                    if (isOnline) ...[
                      const SizedBox(width: 4),
                      Container(width: 5, height: 5, decoration: const BoxDecoration(color: PaceColors.emerald, shape: BoxShape.circle)),
                    ],
                  ]
                ),
                Text(r['ip_address'] ?? '0.0.0.0', style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: Colors.grey)),
              ]
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end, 
            children: [
              Text(stats?['cpu'] ?? '0%', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.purple)),
              Text(stats?['uptime']?.toString().toUpperCase() ?? 'OFFLINE', style: const TextStyle(fontSize: 7.5, color: Colors.grey, fontWeight: FontWeight.w600)),
            ]
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min, 
            children: [
              if (settings.hasPolicy('manage_routers'))
                 IconButton(onPressed: () => _handleRestart(r), icon: const Icon(LucideIcons.refreshCw, color: PaceColors.purple, size: 14), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              const SizedBox(width: 8),
              IconButton(onPressed: () => _showControlPanel(r, isDark, settings), icon: const Icon(LucideIcons.moreVertical, size: 14, color: Colors.grey), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ]
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMet(String label, String val, IconData icon, bool isDark) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 10, color: Colors.grey), const SizedBox(width: 4), Text(label, style: GoogleFonts.figtree(fontSize: 7, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 1))]),
      const SizedBox(height: 4),
      Text(val, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600)),
    ]));
  }

  Widget _buildBillingBadge(dynamic r) {
    final type = r['accountType']?.toString().toLowerCase() ?? 'kcb';
    final String label = type == 'till' ? 'TILL' : type.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
      child: Text('$label: ${r['accountNumber'] ?? '---'}', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.purple)),
    );
  }

  void _showControlPanel(dynamic r, bool isDark, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ROUTER CONTROL', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600, color: PaceColors.purple, letterSpacing: 1)),
            const SizedBox(height: 24),
            _buildActionItem('Restart Hardware', LucideIcons.power, Colors.red, () {
              Navigator.pop(context);
              _handleRestart(r);
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
      title: Text(label, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600)),
      trailing: const Icon(LucideIcons.chevronRight, size: 14),
    );
  }


  void _handleApiResponse(Map<String, dynamic>? res, VoidCallback retry) {
    if (res?['status'] == 'otp_required') {
      _showOtpModal((code) => retry());
    } else if (res?['status'] == 'success') {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Command Executed'), backgroundColor: PaceColors.emerald));
    }
  }

  void _showOtpModal(Function(String) onVerify) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => OtpModal(
      phoneNumber: Provider.of<SettingsProvider>(context, listen: false).activeAccount?.phone ?? '',
      onVerify: (code) { Navigator.pop(context); onVerify(code); },
    ));
  }

  void _handleRestart(dynamic r) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('RESTART ROUTER'),
        content: Text('Reboot ${r['router_name']}? Current sessions will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('RESTART', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final res = await _apiService.restartRouter(r['ip_address'], r['winbox_port'] ?? 8728);
      _handleApiResponse(res, () => _handleRestart(r));
    }
  }
}
