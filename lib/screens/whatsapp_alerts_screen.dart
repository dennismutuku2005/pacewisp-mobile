import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

class WhatsAppAlertsScreen extends StatefulWidget {
  const WhatsAppAlertsScreen({super.key});

  @override
  State<WhatsAppAlertsScreen> createState() => _WhatsAppAlertsScreenState();
}

class _WhatsAppAlertsScreenState extends State<WhatsAppAlertsScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final res = await _apiService.getWhatsAppAlertsConfig();
    if (mounted && res != null) {
      setState(() {
        _data = res;
        _isLoading = false;
      });
    }
  }

  Future<void> _performAction(String action, Map<String, dynamic> body) async {
    final res = await _apiService.performWhatsAppAlertAction(action, body);
    if (mounted && res != null && res['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Action successful'), backgroundColor: PaceColors.emerald));
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return RefreshIndicator(
      onRefresh: () => _fetchData(),
      color: PaceColors.purple,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 24),
          if (_isLoading && _data == null)
            const SkeletonList(count: 3)
          else ...[
            _buildToggles(isDark),
            const SizedBox(height: 24),
            _buildVerificationCard(isDark),
            const SizedBox(height: 24),
            _buildInfrastructureCard(isDark),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('WHATSAPP ALERTS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
        Text('CONFIGURE AUTOMATED LOGS & HEALTH ALERTS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
    ]);
  }

  Widget _buildToggles(bool isDark) {
    final reporting = _data?['reporting_enabled'] == true;
    final billing = _data?['billing_reporting_enabled'] == true;

    return Column(children: [
      _buildToggleCard('ROUTER HEALTH ALERTS', 'PINGS EVERY 12 MINUTES', Icons.wifi_rounded, reporting, (val) => _performAction('update_reporting', {'enable': val}), isDark),
      const SizedBox(height: 12),
      _buildToggleCard('BILLING NOTIFICATIONS', 'FRIENDLY 5-DAY REMINDERS', Icons.notifications_active_rounded, billing, (val) => _performAction('update_billing_reporting', {'enable': val}), isDark, iconColor: Colors.green),
    ]);
  }

  Widget _buildToggleCard(String title, String sub, IconData icon, bool enabled, Function(bool) onChanged, bool isDark, {Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (iconColor ?? PaceColors.purple).withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor ?? PaceColors.purple, size: 20)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
          Text(sub, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 0.5)),
        ])),
        Switch.adaptive(value: enabled, activeColor: PaceColors.emerald, onChanged: onChanged),
      ]),
    );
  }

  Widget _buildVerificationCard(bool isDark) {
    final user = _data?['user'];
    final verified = user?['whatsapp_verified'] == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('ADMIN VERIFICATION', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
          Icon(verified ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: verified ? PaceColors.emerald : Colors.red, size: 16),
        ]),
        const SizedBox(height: 12),
        Text(user?['phone'] ?? 'NO PHONE SET', style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
        Text('REQUIRED FOR RECEIVING AUTOMATED SYSTEM REPORTS.', style: GoogleFonts.figtree(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
        if (!verified) ...[
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _performAction('send_otp', {}), style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)), child: Text('SEND VERIFICATION CODE', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1))))
        ],
        if (verified) ...[
          const SizedBox(height: 20),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: PaceColors.emerald.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Center(child: Text('SYSTEM CONNECTED & READY', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.emerald, letterSpacing: 1)))),
        ]
      ]),
    );
  }

  Widget _buildInfrastructureCard(bool isDark) {
    final routers = _data?['routers'] as List<dynamic>? ?? [];
    final subscribed = routers.where((r) => r['subscribed'] == true).length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
      child: Column(children: [
        CircleAvatar(radius: 30, backgroundColor: PaceColors.purple.withOpacity(0.05), border: Border.all(color: PaceColors.purple.withOpacity(0.1)), child: Icon(Icons.wifi_tethering_rounded, color: PaceColors.purple, size: 30)),
        const SizedBox(height: 20),
        Text('INFRASTRUCTURE SELECTION', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w800, color: PaceColors.getPrimaryText(isDark))),
        const SizedBox(height: 8),
        RichText(textAlign: TextAlign.center, text: TextSpan(style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.normal), children: [
          const TextSpan(text: 'CURRENTLY MONITORING '),
          TextSpan(text: '$subscribed', style: const TextStyle(fontWeight: FontWeight.bold, color: PaceColors.purple)),
          const TextSpan(text: ' ROUTERS. OPEN SELECTOR TO UPDATE PREFERENCES.'),
        ])),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => _showRouterSelector(isDark), style: OutlinedButton.styleFrom(side: const BorderSide(color: PaceColors.purple, width: 1.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)), child: Text('MANAGE ROUTERS', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1)))),
      ]),
    );
  }

  void _showRouterSelector(bool isDark) {
    final routers = _data?['routers'] as List<dynamic>? ?? [];
    showModalBottomSheet(context: context, backgroundColor: PaceColors.getCard(isDark), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))), builder: (context) => Container(padding: const EdgeInsets.symmetric(vertical: 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Text('INFRASTRUCTURE ALERTS', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 2))), const SizedBox(height: 16), Flexible(child: ListView.builder(shrinkWrap: true, itemCount: routers.length, itemBuilder: (context, index) { final r = routers[index]; final sub = r['subscribed'] == true; return ListTile(leading: Icon(Icons.router_outlined, color: sub ? PaceColors.purple : PaceColors.getDimText(isDark)), title: Text(r['router_name'] ?? 'STATION', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))), subtitle: Text(r['ip_address'] ?? '', style: GoogleFonts.jetBrainsMono(fontSize: 9, color: PaceColors.getDimText(isDark))), trailing: IconButton(icon: Icon(sub ? Icons.check_circle_rounded : Icons.circle_outlined, color: sub ? PaceColors.purple : PaceColors.getDimText(isDark)), onPressed: () { Navigator.pop(context); _performAction('toggle_router', {'router_id': r['id'], 'enable': !sub}); }), onTap: () { Navigator.pop(context); _performAction('toggle_router', {'router_id': r['id'], 'enable': !sub}); }); }))])));
  }
}
