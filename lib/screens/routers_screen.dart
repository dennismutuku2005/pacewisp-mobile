import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
import '../components/otp_modal.dart';

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

    return Column(
      children: [
        _buildHeader(isDark, settings),
        Expanded(
          child: _isLoading && _routers.isEmpty
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 3))
            : RefreshIndicator(
                onRefresh: _fetchRouters,
                color: PaceColors.purple,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: _routers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) => _buildRouterCard(_routers[index], isDark, settings),
                ),
              ),
        ),
      ],
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
              Text('CONTROL AND SYNCHRONIZATION STATUS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ],
          ),
          if (settings.hasPolicy('manage_routers'))
            IconButton(onPressed: () => _handleSaveRouter(), icon: const Icon(LucideIcons.plusCircle, color: PaceColors.purple, size: 28)),
        ],
      ),
    );
  }

  Widget _buildRouterCard(dynamic r, bool isDark, SettingsProvider settings) {
    final bool isOnline = r['status'] == 'active';
    final stats = r['stats'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
      child: Column(
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(LucideIcons.router, color: PaceColors.purple, size: 20)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['router_name']?.toString().toUpperCase().replaceAll('_', ' ') ?? 'HOTSPOT UNIT', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.purple)),
                Text(r['ip_address'] ?? '0.0.0.0', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
              ])),
              PaceBadge(label: isOnline ? 'ONLINE' : 'OFFLINE', variant: isOnline ? BadgeVariant.success : BadgeVariant.error),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildHealthMet('CPU LOAD', stats?['cpu'] ?? '0%', LucideIcons.activity, isDark),
              _buildHealthMet('UPTIME', stats?['uptime'] ?? '0D 0H', LucideIcons.clock, isDark),
              _buildHealthMet('VER', 'v${stats?['version'] ?? '---'}', LucideIcons.terminal, isDark),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBillingBadge(r),
              Row(children: [
                if (settings.hasPolicy('manage_routers'))
                   IconButton(onPressed: () => _handleRestart(r), icon: const Icon(LucideIcons.power, color: Colors.redAccent, size: 18)),
                IconButton(onPressed: () => _showControlPanel(r, isDark, settings), icon: const Icon(LucideIcons.moreHorizontal, size: 18)),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMet(String label, String val, IconData icon, bool isDark) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 10, color: Colors.grey), const SizedBox(width: 4), Text(label, style: GoogleFonts.figtree(fontSize: 7, fontWeight: FontWeight.black, color: Colors.grey, letterSpacing: 1))]),
      const SizedBox(height: 4),
      Text(val, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold)),
    ]));
  }

  Widget _buildBillingBadge(dynamic r) {
    final type = r['accountType']?.toString().toLowerCase() ?? 'kcb';
    final String label = type == 'till' ? 'TILL' : type.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
      child: Text('$label: ${r['accountNumber'] ?? '---'}', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.black, color: PaceColors.purple)),
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
            Text('ROUTER MANAGEMENT', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.black, color: PaceColors.purple, letterSpacing: 1)),
            const SizedBox(height: 24),
            _buildActionItem('Edit Identity & Login', LucideIcons.edit3, Colors.orange, () {
              Navigator.pop(context);
              if (settings.hasPolicy('manage_routers')) _handleSaveRouter(editing: r);
            }),
            _buildActionItem('Edit Payment Config', LucideIcons.creditCard, Colors.blue, () {
              Navigator.pop(context);
              if (settings.hasPolicy('manage_routers')) _showBillingDialog(r, isDark);
            }),
            _buildActionItem('Restart Hardware', LucideIcons.power, Colors.red, () {
              Navigator.pop(context);
              _handleRestart(r);
            }),
            if (settings.hasPolicy('manage_routers'))
              _buildActionItem('Remove Data Unit', LucideIcons.trash2, Colors.grey, () {
                Navigator.pop(context);
                _handleDelete(r);
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
      title: Text(label, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold)),
      trailing: const Icon(LucideIcons.chevronRight, size: 14),
    );
  }

  void _handleDelete(dynamic r) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('DELETE ROUTER'),
        content: Text('Permanently remove ${r['router_name']}? This action is irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final res = await _apiService.fetchData('routers', method: 'DELETE', params: {'id': r['id']});
      if (res?['status'] == 'success') _fetchRouters();
    }
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

  void _handleSaveRouter({Map<String, dynamic>? editing}) async {
    final name = TextEditingController(text: editing?['router_name'] ?? '');
    final ip = TextEditingController(text: editing?['ip_address'] ?? '');
    final user = TextEditingController(text: editing?['username'] ?? '');
    final pass = TextEditingController(text: editing?['password'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getBackground(Provider.of<SettingsProvider>(context).isDarkMode),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(editing == null ? 'ADD NEW ROUTER' : 'EDIT ROUTER', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.purple)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEditField('ROUTER NAME', name, LucideIcons.tag),
              const SizedBox(height: 16),
              _buildEditField('IP ADDRESS', ip, LucideIcons.wifi),
              const SizedBox(height: 16),
              _buildEditField('API USERNAME', user, LucideIcons.user),
              const SizedBox(height: 16),
              _buildEditField('API PASSWORD', pass, LucideIcons.lock),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple), child: const Text('SAVE CONFIG', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (result == true) {
      final data = {
        'router_name': name.text,
        'ip_address': ip.text,
        'username': user.text,
        'password': pass.text,
      };
      final res = await _apiService.updateRouter(editing?['id']?.toString() ?? 'new', data);
      if (res?['status'] == 'success') _fetchRouters();
    }
  }

  Widget _buildEditField(String label, TextEditingController ctrl, IconData icon) {
    final isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 6), child: Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.black, color: Colors.grey, letterSpacing: 1))),
      TextField(
        controller: ctrl, 
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 16, color: PaceColors.purple), 
          filled: true, fillColor: PaceColors.getSurface(isDark),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
        )
      ),
    ]);
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

  void _showBillingDialog(dynamic r, bool isDark) {
    String selectedBank = r['accountType']?.toString().toLowerCase() ?? 'kcb';
    final accController = TextEditingController(text: r['accountNumber']?.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.fromLTRB(24, 32, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BILLING CONFIGURATION', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.black, color: PaceColors.purple, letterSpacing: 1)),
              const SizedBox(height: 24),
              Text('PAYMENT GATEWAY', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.black, color: Colors.grey, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: ['kcb', 'equity', 'ncba', 'till', 'custom'].map((b) => ChoiceChip(
                label: Text(b.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                selected: selectedBank == b,
                onSelected: (s) => setS(() => selectedBank = b),
                selectedColor: PaceColors.purple.withOpacity(0.2),
              )).toList()),
              const SizedBox(height: 24),
              Text('ACCOUNT REFERENCE', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.black, color: Colors.grey, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              TextField(
                controller: accController,
                decoration: InputDecoration(
                  hintText: 'e.g. PACE_001 or Till Number',
                  filled: true, fillColor: PaceColors.getSurface(isDark),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
                onPressed: () async {
                   final res = await _apiService.updateRouter(r['id'].toString(), {'accountType': selectedBank, 'accountNumber': accController.text});
                   if (res?['status'] == 'otp_required') {
                      Navigator.pop(ctx);
                      _showOtpModal((code) async {
                        await _apiService.updateRouter(r['id'].toString(), {'accountType': selectedBank, 'accountNumber': accController.text, 'otp_code': code});
                        _fetchRouters();
                      });
                   } else {
                     Navigator.pop(ctx);
                     _fetchRouters();
                   }
                },
                style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('SAVE CONFIGURATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
