import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/skeleton.dart';
import '../components/overlay_loader.dart';
import '../components/badge.dart';

class SystemConfigScreen extends StatefulWidget {
  const SystemConfigScreen({super.key});

  @override
  State<SystemConfigScreen> createState() => _SystemConfigScreenState();
}

class _SystemConfigScreenState extends State<SystemConfigScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _routers = [];
  String? _activeRouterId;
  Map<String, dynamic> _metadata = {};
  Map<String, dynamic> _links = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLocked = true;

  final _wifiNameCtrl = TextEditingController();
  final _supportCtrl = TextEditingController();
  final _routerIdCtrl = TextEditingController();
  final _lnmo1Ctrl = TextEditingController();
  final _lnmo2Ctrl = TextEditingController();
  final _lnmo3Ctrl = TextEditingController();
  final _lnmo4Ctrl = TextEditingController();
  final _lnmo5Ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _wifiNameCtrl.dispose();
    _supportCtrl.dispose();
    _routerIdCtrl.dispose();
    _lnmo1Ctrl.dispose();
    _lnmo2Ctrl.dispose();
    _lnmo3Ctrl.dispose();
    _lnmo4Ctrl.dispose();
    _lnmo5Ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final res = await _apiService.getRouters();
      if (mounted && res != null) {
        final List<dynamic> data = res['data'] ?? [];
        if (data.isNotEmpty) {
          setState(() {
            _routers = data;
            _activeRouterId = _routers[0]['id'].toString();
          });
          await Future.delayed(const Duration(milliseconds: 100));
          await _loadConfig();
        } else {
          setState(() => _isLoading = false);
        }
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadConfig() async {
    if (_activeRouterId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getSystemConfig(_activeRouterId!);
      if (mounted && res != null) {
        final configRoot = res['data'] ?? res;
        final meta = configRoot['metadata'] ?? {};
        final lnks = configRoot['links'] ?? {};

        setState(() {
          _metadata = meta;
          _links = lnks;

          _wifiNameCtrl.text = _metadata['wifiname']?.toString() ?? '';
          _supportCtrl.text = _metadata['customercare']?.toString() ?? '';
          _routerIdCtrl.text = _links['router']?.toString() ?? '';
          _lnmo1Ctrl.text = _links['lnmoapi']?.toString() ?? '';
          _lnmo2Ctrl.text = _links['lnmoapi2']?.toString() ?? '';
          _lnmo3Ctrl.text = _links['lnmoapi3']?.toString() ?? '';
          _lnmo4Ctrl.text = _links['lnmoapi4']?.toString() ?? '';
          _lnmo5Ctrl.text = _links['lnmoapi5']?.toString() ?? '';
        });
      }
    } catch (e) {
      debugPrint("Load Config Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSave() async {
    if (_activeRouterId == null) return;

    final isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Apply Hotspot Configuration', style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
        content: Text('Are you sure you want to update and propagate these network settings to the selected router?', style: GoogleFonts.figtree(fontSize: 14, color: PaceColors.getDimText(isDark))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: PaceColors.purple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Confirm', style: GoogleFonts.figtree(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    final data = {
      'metadata': {
        'wifiname': _wifiNameCtrl.text,
        'customercare': _supportCtrl.text,
      },
      'links': {
        'router': _routerIdCtrl.text,
        'lnmoapi': _lnmo1Ctrl.text,
        'lnmoapi2': _lnmo2Ctrl.text,
        'lnmoapi3': _lnmo3Ctrl.text,
        'lnmoapi4': _lnmo4Ctrl.text,
        'lnmoapi5': _lnmo5Ctrl.text,
      }
    };
    final res = await _apiService.saveSystemConfig(_activeRouterId!, data);
    if (mounted) {
      if (res?['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Configuration saved and propagated', style: GoogleFonts.figtree()), backgroundColor: PaceColors.emerald),
        );
        setState(() => _isLocked = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['message'] ?? 'Save failed', style: GoogleFonts.figtree()), backgroundColor: Colors.red.shade700),
        );
      }
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return PaceOverlayLoader(
      isLoading: _isSaving,
      message: 'Propagating hotspot configuration...',
      child: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: _isLoading
                ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 6))
                : RefreshIndicator(
                    onRefresh: _loadConfig,
                    color: PaceColors.purple,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      children: [
                        _buildRouterPicker(isDark),
                        const SizedBox(height: 16),
                        _buildIdentityCard(isDark),
                        const SizedBox(height: 16),
                        _buildApiLinksCard(isDark),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hotspot Config',
                  style: GoogleFonts.figtree(
                    color: PaceColors.purple,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'SSID identity & gateway settings',
                  style: GoogleFonts.figtree(
                    color: PaceColors.getDimText(isDark),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: (_isSaving || _isLoading) ? null : _handleSave,
            icon: const Icon(LucideIcons.save, size: 15),
            label: Text('Save', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: PaceColors.purple,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouterPicker(bool isDark) {
    if (_routers.isEmpty) return const SizedBox();
    final activeOne = _routers.firstWhere((r) => r['id'].toString() == _activeRouterId, orElse: () => _routers[0]);

    return InkWell(
      onTap: () => _showRouterModal(isDark),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PaceColors.getBorder(isDark)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: const Icon(LucideIcons.router, size: 18, color: PaceColors.purple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Target Router',
                    style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark)),
                  ),
                  Text(
                    activeOne['router_name'] ?? 'Select Router',
                    style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronDown, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showRouterModal(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PaceColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Target Router',
                  style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                ),
                IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            ..._routers.map((r) {
              final isSelected = r['id'].toString() == _activeRouterId;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: Icon(LucideIcons.router, size: 18, color: isSelected ? PaceColors.purple : PaceColors.getDimText(isDark)),
                title: Text(
                  r['router_name'] ?? 'Router',
                  style: GoogleFonts.figtree(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? PaceColors.purple : PaceColors.getPrimaryText(isDark),
                  ),
                ),
                trailing: isSelected ? const Icon(LucideIcons.check, color: PaceColors.purple, size: 18) : null,
                onTap: () {
                  setState(() => _activeRouterId = r['id'].toString());
                  Navigator.pop(ctx);
                  _loadConfig();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityCard(bool isDark) {
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
              const Icon(LucideIcons.wifi, size: 18, color: PaceColors.purple),
              const SizedBox(width: 8),
              Text(
                'Identity & Branding',
                style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildField('Wi-Fi SSID (Broadcast Name)', _wifiNameCtrl, LucideIcons.smartphone, isDark, sub: 'Displayed on captive portal logins and SMS receipts'),
          const SizedBox(height: 14),
          _buildField('Customer Care Contact Phone', _supportCtrl, LucideIcons.phone, isDark, sub: 'Provided on landing pages for billing inquiries and support'),
        ],
      ),
    );
  }

  Widget _buildApiLinksCard(bool isDark) {
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
                  const Icon(LucideIcons.link, size: 18, color: PaceColors.purple),
                  const SizedBox(width: 8),
                  Text(
                    'Gateway Integration Links',
                    style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                  ),
                ],
              ),
              if (_isLocked)
                TextButton.icon(
                  onPressed: () => setState(() => _isLocked = false),
                  icon: const Icon(LucideIcons.unlock, size: 14, color: PaceColors.purple),
                  label: Text('Unlock', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.purple)),
                )
              else
                PaceBadge(label: 'Unlocked', variant: BadgeVariant.warning),
            ],
          ),
          const SizedBox(height: 16),
          _buildField('Primary LNMO API Endpoint', _lnmo1Ctrl, LucideIcons.globe, isDark, isMono: true, enabled: !_isLocked),
          const SizedBox(height: 12),
          _buildField('Router Identity Identifier', _routerIdCtrl, LucideIcons.network, isDark, isMono: true, enabled: !_isLocked, sub: 'Used by payment webhooks to route transaction packets'),
          const SizedBox(height: 12),
          _buildField('Secondary LNMO 2', _lnmo2Ctrl, LucideIcons.link2, isDark, isMono: true, enabled: !_isLocked),
          const SizedBox(height: 12),
          _buildField('Secondary LNMO 3', _lnmo3Ctrl, LucideIcons.link2, isDark, isMono: true, enabled: !_isLocked),
          const SizedBox(height: 12),
          _buildField('Fallback LNMO 4', _lnmo4Ctrl, LucideIcons.link2, isDark, isMono: true, enabled: !_isLocked),
          const SizedBox(height: 12),
          _buildField('Fallback LNMO 5', _lnmo5Ctrl, LucideIcons.link2, isDark, isMono: true, enabled: !_isLocked),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, bool isDark, {bool isMono = false, bool enabled = true, String? sub}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: PaceColors.getSurface(isDark),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PaceColors.getBorder(isDark)),
          ),
          child: TextField(
            controller: ctrl,
            enabled: enabled,
            style: isMono
                ? GoogleFonts.jetBrainsMono(fontSize: 13, color: enabled ? PaceColors.getPrimaryText(isDark) : PaceColors.getDimText(isDark))
                : GoogleFonts.figtree(fontSize: 14, color: enabled ? PaceColors.getPrimaryText(isDark) : PaceColors.getDimText(isDark)),
            decoration: InputDecoration(
              icon: Icon(icon, size: 16, color: PaceColors.getDimText(isDark)),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(
            sub,
            style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark)),
          ),
        ],
      ],
    );
  }
}
