import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
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
  Map<String, dynamic>? _metadata;
  Map<String, dynamic>? _links;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLocked = true;

  final TextEditingController _wifiNameController = TextEditingController();
  final TextEditingController _supportPhoneController = TextEditingController();
  final TextEditingController _lnmoController = TextEditingController();
  final TextEditingController _routerIdentityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final res = await _apiService.getRouters();
    if (mounted && res != null && res['status'] == 'success') {
      setState(() {
        _routers = res['data'] ?? [];
        if (_routers.isNotEmpty) {
          _activeRouterId = _routers[0]['id'].toString();
          _loadConfig();
        } else {
          _isLoading = false;
        }
      });
    }
  }

  Future<void> _loadConfig() async {
    if (_activeRouterId == null) return;
    setState(() => _isLoading = true);
    final res = await _apiService.getSystemConfig(_activeRouterId!);
    if (mounted && res != null && res['status'] == 'success') {
      setState(() {
        _metadata = res['metadata'];
        _links = res['links'];
        _wifiNameController.text = _metadata?['wifiname'] ?? '';
        _supportPhoneController.text = _metadata?['customercare'] ?? '';
        _lnmoController.text = _links?['lnmoapi'] ?? '';
        _routerIdentityController.text = _links?['router'] ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    if (_activeRouterId == null) return;
    setState(() => _isSaving = true);
    final res = await _apiService.saveSystemConfig(_activeRouterId!, {
      'metadata': {
        'wifiname': _wifiNameController.text,
        'customercare': _supportPhoneController.text,
      },
      'links': {
        'lnmoapi': _lnmoController.text,
        'router': _routerIdentityController.text,
      }
    });
    if (mounted) {
      setState(() {
        _isSaving = false;
        _isLocked = true;
      });
      if (res != null && res['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration saved successfully'), backgroundColor: PaceColors.emerald));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      appBar: AppBar(
        title: Text('SYSTEM CONFIG', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(_isSaving ? Icons.sync : Icons.save_rounded, color: PaceColors.purple),
              onPressed: _isSaving ? null : _saveConfig,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
        ? const Padding(padding: EdgeInsets.all(24), child: SkeletonList())
        : ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              _buildRouterSelector(isDark),
              const SizedBox(height: 24),
              _buildIdentitySection(isDark),
              const SizedBox(height: 24),
              _buildCriticalLinksSection(isDark),
              const SizedBox(height: 100),
            ],
          ),
    );
  }

  Widget _buildRouterSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _activeRouterId,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded, color: PaceColors.purple),
          style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
          dropdownColor: PaceColors.getCard(isDark),
          items: _routers.map((r) => DropdownMenuItem(value: r['id'].toString(), child: Text(r['router_name']?.toUpperCase() ?? 'STATION'))).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _activeRouterId = val;
                _isLocked = true;
              });
              _loadConfig();
            }
          },
        ),
      ),
    );
  }

  Widget _buildIdentitySection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.wifi_tethering_rounded, color: PaceColors.purple, size: 18),
          const SizedBox(width: 12),
          Text('HOTSPOT IDENTITY', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 24),
        _buildTextField('WIFI SSID (NETWORK NAME)', _wifiNameController, 'e.g. PACE_HOTSPOT', isDark),
        const SizedBox(height: 20),
        _buildTextField('SUPPORT / CARE NUMBER', _supportPhoneController, 'e.g. 07XXXXXXXX', isDark),
      ]),
    );
  }

  Widget _buildCriticalLinksSection(bool isDark) {
    return Stack(
      children: [
        Opacity(
          opacity: _isLocked ? 0.3 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  const Icon(Icons.link_rounded, color: Colors.blue, size: 18),
                  const SizedBox(width: 12),
                  Text('CRITICAL API LINKS', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
                ]),
                if (!_isLocked) IconButton(onPressed: () => setState(() => _isLocked = true), icon: const Icon(Icons.lock_open_rounded, color: PaceColors.purple, size: 16)),
              ]),
              const SizedBox(height: 24),
              _buildTextField('LNMO API (PRIMARY)', _lnmoController, 'https://api.gateway.com', isDark, isMono: true, enabled: !_isLocked),
              const SizedBox(height: 20),
              _buildTextField('ROUTER IDENTITY', _routerIdentityController, 'e.g. pace', isDark, isMono: true, enabled: !_isLocked),
              const SizedBox(height: 12),
              Text('MODIFICATION OF THESE LINKS MAY BREAK PAYMENT PROCESSING.', style: GoogleFonts.figtree(fontSize: 8, color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
        if (_isLocked)
          Positioned.fill(
            child: Center(
              child: GestureDetector(
                onTap: () => setState(() => _isLocked = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(color: PaceColors.purple, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: PaceColors.purple.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 12),
                    Text('UNLOCK CORE CONFIG', style: GoogleFonts.figtree(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, bool isDark, {bool isMono = false, bool enabled = true}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        enabled: enabled,
        style: isMono ? GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)) : GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 12),
          filled: true,
          fillColor: PaceColors.getBackground(isDark).withOpacity(0.5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    ]);
  }
}
