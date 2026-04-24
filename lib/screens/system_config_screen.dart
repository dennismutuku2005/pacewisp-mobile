import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
          // Ensure state is updated before loading config
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
        // Handle both root-level and nested 'data' responses
        final configRoot = res['data'] ?? res;
        final meta = configRoot['metadata'] ?? {};
        final lnks = configRoot['links'] ?? {};

        setState(() {
          _metadata = meta;
          _links = lnks;
          
          // Use direct assignment to ensure UI update
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
        backgroundColor: PaceColors.getBackground(isDark),
        title: Text('APPLY CONFIGURATION', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w700, color: PaceColors.purple)),
        content: const Text('Are you sure you want to update and sync these settings to the router? This may impact live connections.', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('CONFIRM')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    
    final data = {
      'metadata': {
        'wifiname': _wifiNameCtrl.text, 
        'customercare': _supportCtrl.text
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration Propagated Successfully'), backgroundColor: PaceColors.emerald));
        setState(() => _isLocked = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Save failed'), backgroundColor: Colors.redAccent));
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
      message: 'Propagating Hotspot Configuration...',
      child: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: _isLoading 
              ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList())
              : RefreshIndicator(
                  onRefresh: _loadConfig,
                  color: PaceColors.purple,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    children: [
                      _buildRouterPicker(isDark),
                      const SizedBox(height: 24),
                      _buildIdentityCard(isDark),
                      const SizedBox(height: 24),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('HOTSPOT CONFIGURATION', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
            Text('MANAGE INFRASTRUCTURE IDENTITY & LINKS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2)),
          ]),
          IconButton(
            onPressed: (_isSaving || _isLoading) ? null : _handleSave,
            icon: const Icon(LucideIcons.save, color: PaceColors.purple),
            style: IconButton.styleFrom(backgroundColor: PaceColors.purple.withOpacity(0.05)),
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark), 
          borderRadius: BorderRadius.circular(20), 
          border: Border.all(color: PaceColors.getBorder(isDark)),
          boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8), 
            decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), 
            child: const Icon(LucideIcons.settings2, size: 16, color: PaceColors.purple)
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TARGET NODE', style: GoogleFonts.figtree(fontSize: 7, fontWeight: FontWeight.w800, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
            Text(activeOne['router_name']?.toUpperCase() ?? 'SELECT ROUTER', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
          ])),
          Icon(LucideIcons.chevronDown, size: 14, color: PaceColors.getDimText(isDark)),
        ]),
      ),
    );
  }

  void _showRouterModal(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: PaceColors.getBorder(isDark), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('SELECT TARGET NODE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w800, color: PaceColors.purple, letterSpacing: 2)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: _routers.length,
                itemBuilder: (context, index) {
                  final r = _routers[index];
                  final bool isSelected = r['id'].toString() == _activeRouterId;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                    leading: Icon(LucideIcons.router, size: 18, color: isSelected ? PaceColors.purple : PaceColors.getDimText(isDark)),
                    title: Text(r['router_name']?.toUpperCase() ?? '', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w700, color: PaceColors.getPrimaryText(isDark))),
                    trailing: isSelected ? const Icon(LucideIcons.checkCircle2, color: PaceColors.purple, size: 18) : null,
                    onTap: () {
                      setState(() => _activeRouterId = r['id'].toString());
                      Navigator.pop(ctx);
                      _loadConfig();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark), 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: PaceColors.getBorder(isDark)),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(LucideIcons.wifi, size: 16, color: PaceColors.purple),
          const SizedBox(width: 12),
          Text('IDENTITY METADATA', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w800, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
          const Spacer(),
          const PaceBadge(label: 'LIVE CONFIG', variant: BadgeVariant.secondary),
        ]),
        const SizedBox(height: 24),
        _buildField('WIFI SSID (NETWORK NAME)', _wifiNameCtrl, LucideIcons.smartphone, isDark, sub: 'Appears on customer login portal and receipts'),
        const SizedBox(height: 20),
        _buildField('SUPPORT NUMBER', _supportCtrl, LucideIcons.phone, isDark, sub: 'Provided to customers for STK push / connectivity issues'),
      ]),
    );
  }

  Widget _buildApiLinksCard(bool isDark) {
    return Stack(
      children: [
        Opacity(
          opacity: _isLocked ? 0.3 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: PaceColors.getCard(isDark), 
              borderRadius: BorderRadius.circular(24), 
              border: Border.all(color: PaceColors.getBorder(isDark)),
              boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                 Row(children: [
                   const Icon(LucideIcons.link, size: 16, color: Colors.blue),
                   const SizedBox(width: 12),
                   Text('SYSTEM API LINKS', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w800, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
                 ]),
                 if (!_isLocked) 
                  const PaceBadge(label: 'CRITICAL ACCESS', variant: BadgeVariant.error),
              ]),
              const SizedBox(height: 24),
              _buildField('PRIMARY LNMO API', _lnmo1Ctrl, LucideIcons.globe, isDark, isMono: true, enabled: !_isLocked),
              const SizedBox(height: 16),
              _buildField('ROUTER IDENTITY', _routerIdCtrl, LucideIcons.network, isDark, isMono: true, enabled: !_isLocked, sub: 'Crucial for matching payment records to gateway'),
              const SizedBox(height: 16),
              _buildField('SECONDARY LNMO 2', _lnmo2Ctrl, LucideIcons.link2, isDark, isMono: true, enabled: !_isLocked),
              const SizedBox(height: 16),
              _buildField('SECONDARY LNMO 3', _lnmo3Ctrl, LucideIcons.link2, isDark, isMono: true, enabled: !_isLocked),
              const SizedBox(height: 16),
              _buildField('FALLBACK LNMO 4', _lnmo4Ctrl, LucideIcons.link2, isDark, isMono: true, enabled: !_isLocked),
              const SizedBox(height: 16),
              _buildField('FALLBACK LNMO 5', _lnmo5Ctrl, LucideIcons.link2, isDark, isMono: true, enabled: !_isLocked),
            ]),
          ),
        ),
        if (_isLocked)
          Positioned.fill(child: Center(child: InkWell(
            onTap: () => setState(() => _isLocked = false),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: PaceColors.purple, 
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: PaceColors.purple.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.lock, color: Colors.white, size: 14),
                const SizedBox(width: 10),
                Text('UNLOCK SYSTEM LINKS', style: GoogleFonts.figtree(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5)),
              ]),
            ),
          ))),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, bool isDark, {bool isMono = false, bool enabled = true, String? sub}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w800, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
      const SizedBox(height: 8),
      TextField(
        controller: ctrl,
        enabled: enabled,
        style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w600, color: enabled ? PaceColors.getPrimaryText(isDark) : PaceColors.getDimText(isDark)),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 16, color: PaceColors.purple),
          filled: true, 
          fillColor: PaceColors.getSurface(isDark),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      if (sub != null) ...[
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(sub, style: GoogleFonts.figtree(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w500)),
        ),
      ],
    ]);
  }

}
