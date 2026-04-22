import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final res = await _apiService.getRouters();
    if (mounted && res?['status'] == 'success') {
      _routers = res?['data'] ?? [];
      if (_routers.isNotEmpty) {
        _activeRouterId = _routers[0]['id'].toString();
        _loadConfig();
      }
    }
  }

  Future<void> _loadConfig() async {
    if (_activeRouterId == null) return;
    setState(() => _isLoading = true);
    final res = await _apiService.getSystemConfig(_activeRouterId!);
    if (mounted && res?['status'] == 'success') {
      setState(() {
        _metadata = res?['metadata'] ?? {};
        _links = res?['links'] ?? {};
        _wifiNameCtrl.text = _metadata['wifiname'] ?? '';
        _supportCtrl.text = _metadata['customercare'] ?? '';
        _routerIdCtrl.text = _links['router'] ?? '';
        _lnmo1Ctrl.text = _links['lnmoapi'] ?? '';
        _lnmo2Ctrl.text = _links['lnmoapi2'] ?? '';
        _lnmo3Ctrl.text = _links['lnmoapi3'] ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final data = {
      'metadata': {'wifiname': _wifiNameCtrl.text, 'customercare': _supportCtrl.text},
      'links': {
        'router': _routerIdCtrl.text,
        'lnmoapi': _lnmo1Ctrl.text,
        'lnmoapi2': _lnmo2Ctrl.text,
        'lnmoapi3': _lnmo3Ctrl.text,
      }
    };
    final res = await _apiService.saveSystemConfig(_activeRouterId!, data);
    if (mounted) {
      if (res?['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Config Propagated Successfully'), backgroundColor: PaceColors.emerald));
        setState(() => _isLocked = true);
      }
      setState(() => _isSaving = false);
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
            Text('CORE CONFIGURATION', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
            Text('MANAGE INFRASTRUCTURE IDENTITY & LINKS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ]),
          IconButton(
            onPressed: _isSaving ? null : _handleSave,
            icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: PaceColors.purple)) : const Icon(LucideIcons.save, color: PaceColors.purple),
          ),
        ],
      ),
    );
  }

  Widget _buildRouterPicker(bool isDark) {
    final activeOne = _routers.firstWhere((r) => r['id'].toString() == _activeRouterId, orElse: () => _routers[0]);
    return InkWell(
      onTap: () => _showRouterModal(isDark),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark))),
        child: Row(children: [
          const Icon(LucideIcons.settings2, size: 18, color: PaceColors.purple),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TARGET NODE', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
            Text(activeOne['router_name']?.toUpperCase() ?? 'SELECT ROUTER', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold)),
          ])),
          const Icon(LucideIcons.chevronDown, size: 16, color: Colors.grey),
        ]),
      ),
    );
  }

  Widget _buildIdentityCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(LucideIcons.wifi, size: 14, color: PaceColors.purple),
          const SizedBox(width: 8),
          Text('IDENTITY METADATA', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 24),
        _buildField('WIFI SSID (NETWORK NAME)', _wifiNameCtrl, LucideIcons.smartphone, isDark),
        const SizedBox(height: 20),
        _buildField('SUPPORT NUMBER', _supportCtrl, LucideIcons.phone, isDark),
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
            decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                 Row(children: [
                   const Icon(LucideIcons.link, size: 14, color: Colors.blue),
                   const SizedBox(width: 8),
                   Text('SYSTEM API LINKS', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
                 ]),
                 if (!_isLocked) IconButton(onPressed: () => setState(() => _isLocked = true), icon: const Icon(LucideIcons.unlock, size: 14, color: PaceColors.purple)),
              ]),
              const SizedBox(height: 24),
              _buildField('PRIMARY LNMO API', _lnmo1Ctrl, LucideIcons.globe, isDark, isMono: true, enabled: !_isLocked),
              const SizedBox(height: 16),
              _buildField('ROUTER IDENTITY', _routerIdCtrl, LucideIcons.network, isDark, isMono: true, enabled: !_isLocked),
              const SizedBox(height: 16),
              _buildField('SECONDARY LNMO 2', _lnmo2Ctrl, LucideIcons.link2, isDark, isMono: true, enabled: !_isLocked),
              const SizedBox(height: 16),
              _buildField('SECONDARY LNMO 3', _lnmo3Ctrl, LucideIcons.link2, isDark, isMono: true, enabled: !_isLocked),
            ]),
          ),
        ),
        if (_isLocked)
          Positioned.fill(child: Center(child: InkWell(
            onTap: () => setState(() => _isLocked = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: PaceColors.purple, borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.lock, color: Colors.white, size: 14),
                const SizedBox(width: 8),
                Text('UNLOCK CORE LINKS', style: GoogleFonts.figtree(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
              ]),
            ),
          ))),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, bool isDark, {bool isMono = false, bool enabled = true}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
      const SizedBox(height: 8),
      TextField(
        controller: ctrl,
        enabled: enabled,
        style: isMono ? GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold) : GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 14, color: PaceColors.purple),
          filled: true, fillColor: PaceColors.getSurface(isDark),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      ),
    ]);
  }

  void _showRouterModal(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(mainAxisSize: MainAxisSize.min, children: _routers.map((r) => ListTile(
          leading: Icon(LucideIcons.router, color: r['id'].toString() == _activeRouterId ? PaceColors.purple : Colors.grey),
          title: Text(r['router_name']?.toUpperCase() ?? '', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold)),
          trailing: r['id'].toString() == _activeRouterId ? const Icon(LucideIcons.check, color: PaceColors.purple) : null,
          onTap: () {
            setState(() => _activeRouterId = r['id'].toString());
            Navigator.pop(ctx);
            _loadConfig();
          },
        )).toList()),
      ),
    );
  }
}
