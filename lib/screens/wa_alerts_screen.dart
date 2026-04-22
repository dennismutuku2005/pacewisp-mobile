import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

class WAAlertsScreen extends StatefulWidget {
  const WAAlertsScreen({super.key});

  @override
  State<WAAlertsScreen> createState() => _WAAlertsScreenState();
}

class _WAAlertsScreenState extends State<WAAlertsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> _data = {};
  String _otp = '';
  bool _showOtpInput = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final res = await _apiService.fetchData('wa_alerts');
    if (mounted) {
      setState(() {
        _data = res ?? {};
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAction(String action, {Map<String, dynamic>? body}) async {
    setState(() => _isSaving = true);
    final res = await _apiService.fetchData('wa_alerts_action', method: 'POST', body: {
      'action': action,
      ...?(body ?? {}),
    });
    
    if (mounted) {
      if (res?['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Action Successful'), backgroundColor: PaceColors.emerald));
        if (action == 'send_otp') setState(() => _showOtpInput = true);
        if (action == 'verify_otp') {
          setState(() { _showOtpInput = false; _otp = ''; });
          _fetchData();
        } else {
          _fetchData();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Action Failed'), backgroundColor: Colors.red));
      }
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    if (!settings.hasPolicy('wa_alerts')) return const Center(child: Text('ACCESS RESTRICTED'));

    return Column(
      children: [
        _buildHeader(isDark),
        Expanded(
          child: _isLoading 
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 3))
            : RefreshIndicator(
                onRefresh: _fetchData,
                color: PaceColors.purple,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  children: [
                    _buildToggleCard(
                      'ROUTER HEALTH ALERTS', 
                      'Pings every 12 minutes', 
                      LucideIcons.wifi, 
                      _data['reporting_enabled'] == true || _data['reporting_enabled'] == 1,
                      (val) => _handleAction('update_reporting', body: {'enable': val}),
                      isDark
                    ),
                    const SizedBox(height: 12),
                    _buildToggleCard(
                      'BILLING NOTIFICATIONS', 
                      'Friendly 5-day reminders', 
                      LucideIcons.bell, 
                      _data['billing_reporting_enabled'] == true || _data['billing_reporting_enabled'] == 1,
                      (val) => _handleAction('update_billing_reporting', body: {'enable': val}),
                      isDark
                    ),
                    const SizedBox(height: 24),
                    _buildVerificationCard(isDark),
                    const SizedBox(height: 24),
                    _buildRouterPanelTrigger(isDark),
                  ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WHATSAPP ALERTS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
          Text('CONFIGURE AUTOMATED REPORTING & HEALTH LOGS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildToggleCard(String title, String sub, IconData icon, bool val, Function(bool) onChanged, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: PaceColors.purple, size: 20)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.black, color: PaceColors.getPrimaryText(isDark))),
            Text(sub.toUpperCase(), style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
          ])),
          Switch(value: val, onChanged: _isSaving ? null : onChanged, activeColor: PaceColors.purple),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(bool isDark) {
    final bool verified = _data['user']?['whatsapp_verified'] == true || _data['user']?['whatsapp_verified'] == 1;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(LucideIcons.smartphone, size: 14, color: PaceColors.purple),
            const SizedBox(width: 8),
            Text('ADMIN VERIFICATION', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.black, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
            const Spacer(),
            PaceBadge(label: verified ? 'CONNECTED' : 'UNVERIFIED', variant: verified ? BadgeVariant.success : BadgeVariant.error),
          ]),
          const SizedBox(height: 24),
          Text(_data['user']?['phone'] ?? 'NO PHONE SET', style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.black, color: PaceColors.getPrimaryText(isDark))),
          Text('Automated reports will be sent to this number.', style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark))),
          const SizedBox(height: 24),
          if (!verified) ...[
            if (!_showOtpInput)
              ElevatedButton(
                onPressed: _isSaving ? null : () => _handleAction('send_otp'),
                style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text('SEND VERIFICATION CODE', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              )
            else ...[
              TextField(
                onChanged: (v) => setState(() => _otp = v),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: InputDecoration(hintText: '000000', filled: true, fillColor: PaceColors.getBackground(isDark), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: (_isSaving || _otp.length < 4) ? null : () => _handleAction('verify_otp', body: {'otp': _otp}),
                style: ElevatedButton.styleFrom(backgroundColor: PaceColors.emerald, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text('VERIFY & ACTIVATE', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildRouterPanelTrigger(bool isDark) {
    int subCount = (_data['routers'] as List?)?.where((r) => r['subscribed'] == true || r['subscribed'] == 1).length ?? 0;
    return InkWell(
      onTap: () => _showRouterSelection(isDark),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.purple.withOpacity(0.1))),
        child: Column(
          children: [
            const Icon(LucideIcons.router, color: PaceColors.purple, size: 32),
            const SizedBox(height: 16),
            Text('INFRASTRUCTURE SELECTION', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.black, color: PaceColors.purple)),
            Text('Monitoring $subCount active nodes', style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark))),
            const SizedBox(height: 16),
            Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: PaceColors.purple, borderRadius: BorderRadius.circular(12)), child: Text('MANAGE SUBSCRIPTIONS', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white))),
          ],
        ),
      ),
    );
  }

  void _showRouterSelection(bool isDark) {
    List<dynamic> routers = _data['routers'] ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('NODE ALERTS', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.black, color: PaceColors.purple, letterSpacing: 1)),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: routers.length,
                  separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark)),
                  itemBuilder: (ctx, i) {
                    final r = routers[i];
                    final bool sub = r['subscribed'] == true || r['subscribed'] == 1;
                    return ListTile(
                      dense: true,
                      title: Text(r['router_name'] ?? '', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: Text(r['ip_address'] ?? '', style: GoogleFonts.jetBrainsMono(fontSize: 9, color: Colors.grey)),
                      trailing: IconButton(
                        onPressed: () async {
                           await _handleAction('toggle_router', body: {'router_id': r['id'], 'enable': !sub});
                           setM(() { routers[i]['subscribed'] = !sub; });
                        },
                        icon: Icon(sub ? LucideIcons.checkCircle2 : LucideIcons.circle, color: sub ? PaceColors.purple : Colors.grey, size: 24),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: ElevatedButton(onPressed: () => _handleAction('toggle_all_on'), style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple.withOpacity(0.1), foregroundColor: PaceColors.purple), child: const Text('SELECT ALL'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: () => _handleAction('toggle_all_off'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1), foregroundColor: Colors.red), child: const Text('CLEAR ALL'))),
              ]),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
