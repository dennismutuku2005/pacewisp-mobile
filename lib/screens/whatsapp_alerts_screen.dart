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

class WhatsAppAlertsScreen extends StatefulWidget {
  const WhatsAppAlertsScreen({super.key});

  @override
  State<WhatsAppAlertsScreen> createState() => _WhatsAppAlertsScreenState();
}

class _WhatsAppAlertsScreenState extends State<WhatsAppAlertsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final res = await _apiService.fetchData(slug: 'wa_alerts');
    if (mounted) {
      setState(() {
        _data = res ?? {};
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAction(String action, {Map<String, dynamic>? body}) async {
    setState(() => _isSaving = true);
    final res = await _apiService.performWhatsAppAlertAction(action, body ?? {});

    if (mounted) {
      if (res?['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['message'] ?? 'Settings updated', style: GoogleFonts.figtree()), backgroundColor: PaceColors.emerald),
        );
        if (action == 'send_otp') {
          _showOtpModal();
        } else {
          _fetchData();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['message'] ?? 'Action failed', style: GoogleFonts.figtree()), backgroundColor: Colors.red.shade700),
        );
      }
      setState(() => _isSaving = false);
    }
  }

  void _showOtpModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OtpModal(
        phoneNumber: _data['user']?['phone'] ?? '---',
        onVerify: (code) {
          Navigator.pop(context);
          _handleAction('verify_otp', body: {'otp': code});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    if (!settings.hasPolicy('wa_alerts')) {
      return Center(
        child: Text('Access Restricted', style: GoogleFonts.figtree(fontSize: 16, color: PaceColors.getDimText(isDark))),
      );
    }

    return PaceOverlayLoader(
      isLoading: _isSaving,
      message: 'Updating alert settings...',
      child: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: _isLoading && _data.isEmpty
                ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 3))
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    color: PaceColors.purple,
                    child: _data.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: PaceEmptyState(
                              title: 'Alerts Unavailable',
                              subtitle: 'Unable to load WhatsApp alert configurations.',
                              onRetry: _fetchData,
                              isDark: isDark,
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                            children: [
                              _buildToggleCard(
                                'Router Health Alerts',
                                'Automated pings and uptime status alerts',
                                LucideIcons.wifi,
                                _data['reporting_enabled'] == true || _data['reporting_enabled'] == 1,
                                (val) => _handleAction('update_reporting', body: {'enable': val}),
                                isDark,
                              ),
                              const SizedBox(height: 10),
                              _buildToggleCard(
                                'Billing Notifications',
                                'Cycle renewal and automated payment alerts',
                                LucideIcons.bell,
                                _data['billing_reporting_enabled'] == true || _data['billing_reporting_enabled'] == 1,
                                (val) => _handleAction('update_billing_reporting', body: {'enable': val}),
                                isDark,
                              ),
                              const SizedBox(height: 16),
                              _buildVerificationCard(isDark),
                              const SizedBox(height: 16),
                              _buildRouterPanelTrigger(isDark),
                            ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WhatsApp Alerts',
            style: GoogleFonts.figtree(
              color: PaceColors.getPrimaryText(isDark),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Automated operational digests, revenue summaries, and node alerts',
            style: GoogleFonts.figtree(
              color: PaceColors.getDimText(isDark),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleCard(String title, String sub, IconData icon, bool val, Function(bool) onChanged, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: PaceColors.purple, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark)),
                ),
              ],
            ),
          ),
          Switch(
            value: val,
            onChanged: _isSaving ? null : onChanged,
            activeColor: PaceColors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(bool isDark) {
    final bool verified = _data['user']?['whatsapp_verified'] == true || _data['user']?['whatsapp_verified'] == 1;
    final phone = _data['user']?['phone'] ?? 'No phone set';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.smartphone, size: 18, color: PaceColors.purple),
                  const SizedBox(width: 8),
                  Text(
                    'Admin Recipient Phone',
                    style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                  ),
                ],
              ),
              PaceBadge(
                label: verified ? 'Verified' : 'Unverified',
                variant: verified ? BadgeVariant.success : BadgeVariant.warning,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            phone,
            style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
          ),
          const SizedBox(height: 4),
          Text(
            'Automated reports and critical system alerts will be sent to this WhatsApp number.',
            style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark)),
          ),
          const SizedBox(height: 16),
          if (!verified)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : () => _handleAction('send_otp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PaceColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text('Verify WhatsApp Number', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            )
          else
            Row(
              children: [
                const Icon(LucideIcons.checkCircle, color: PaceColors.emerald, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Connected and active',
                  style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.emerald),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRouterPanelTrigger(bool isDark) {
    int subCount = (_data['routers'] as List?)?.where((r) => r['subscribed'] == true || r['subscribed'] == 1).length ?? 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(LucideIcons.router, color: PaceColors.purple, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monitored Routers',
                      style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                    ),
                    Text(
                      'Currently monitoring $subCount active nodes for alerts',
                      style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => _showRouterSelection(isDark),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              side: const BorderSide(color: PaceColors.purple),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Select Routers',
              style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.purple),
            ),
          ),
        ],
      ),
    );
  }

  void _showRouterSelection(bool isDark) {
    List<dynamic> routers = _data['routers'] ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Node Alert Subscriptions',
                    style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                  ),
                  IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              Text(
                'Select which router nodes should send disconnect and outage alerts.',
                style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getDimText(isDark)),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: routers.length,
                  separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                  itemBuilder: (ctx, i) {
                    final r = routers[i];
                    final bool sub = r['subscribed'] == true || r['subscribed'] == 1;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        r['router_name'] ?? 'Router',
                        style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
                      ),
                      subtitle: Text(
                        r['ip_address'] ?? '',
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, color: PaceColors.getDimText(isDark)),
                      ),
                      trailing: IconButton(
                        onPressed: () async {
                          await _handleAction('toggle_router', body: {'router_id': r['id'], 'enable': !sub});
                          setM(() {
                            routers[i]['subscribed'] = !sub;
                          });
                        },
                        icon: Icon(sub ? LucideIcons.checkSquare : LucideIcons.square, color: sub ? PaceColors.purple : Colors.grey, size: 20),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleAction('toggle_all_on'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: PaceColors.purple),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Select All', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.purple)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleAction('toggle_all_off'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Clear All', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red.shade600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
