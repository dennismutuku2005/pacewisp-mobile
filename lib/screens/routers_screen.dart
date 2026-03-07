import 'package:flutter/material.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

class RoutersScreen extends StatefulWidget {
  const RoutersScreen({super.key});

  @override
  State<RoutersScreen> createState() => _RoutersScreenState();
}

class _RoutersScreenState extends State<RoutersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _routers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRouters();
  }

  Future<void> _fetchRouters() async {
    setState(() => _isLoading = true);
    final res = await _apiService.getRouters();
    if (mounted) {
      setState(() {
        _routers = res?['data'] ?? [];
        _isLoading = false;
      });
    }
  }

  void _showBillingModal(dynamic router, bool isDark) {
    final accountType = router['accountType']?.toString().toLowerCase() ?? 'kcb';
    final accountController = TextEditingController(text: router['accountNumber']?.toString());
    bool isSaving = false;
    String selectedBank = accountType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: PaceColors.getBackground(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: PaceColors.getBorder(isDark), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text('BILLING CONFIGURATION', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text('ROUTER: ${router['router_name']?.toString().toUpperCase().replaceAll('_', ' ')}', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
              
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('PAYMENT GATEWAY', isDark),
                    Row(
                      children: ['kcb', 'equity', 'ncba'].map((bank) => Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedBank = bank),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selectedBank == bank ? PaceColors.purple.withOpacity(0.1) : PaceColors.getSurface(isDark),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: selectedBank == bank ? PaceColors.purple : PaceColors.getBorder(isDark), width: selectedBank == bank ? 1.5 : 1),
                            ),
                            child: Column(
                              children: [
                                Text(bank.toUpperCase(), style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: selectedBank == bank ? PaceColors.purple : PaceColors.getDimText(isDark))),
                              ],
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 20),
                    _buildLabel('M-PESA ACCOUNT REFERENCE', isDark),
                    TextField(
                      controller: accountController,
                      style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                      decoration: InputDecoration(
                        hintText: 'e.g. PACE_001',
                        prefixIcon: const Icon(Icons.account_balance_outlined, size: 18, color: PaceColors.purple),
                        filled: true,
                        fillColor: PaceColors.getSurface(isDark),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: PaceColors.getBorder(isDark))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: PaceColors.getBorder(isDark))),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : () async {
                          setModalState(() => isSaving = true);
                          final res = await _apiService.updateRouter(router['id'].toString(), {
                            'accountType': selectedBank,
                            'accountNumber': accountController.text,
                          });
                          if (mounted) {
                            Navigator.pop(context);
                            _fetchRouters();
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: isSaving 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('UPDATE BILLING', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) => Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(text, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark).withOpacity(0.7), letterSpacing: 1.5)));


  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Column(
      children: [
        _buildHeader(isDark),
        Expanded(
          child: _isLoading 
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 3))
            : RefreshIndicator(
                onRefresh: _fetchRouters,
                color: PaceColors.purple,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _routers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildRouterCard(_routers[index], isDark),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ROUTERS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
              const Icon(Icons.router_rounded, color: PaceColors.purple, size: 24),
            ],
          ),
          const SizedBox(height: 4),
          Text('CONTROL AND MIKROTIK SYNCHRONIZATION STATUS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildRouterCard(dynamic router, bool isDark) {
    final status = (router['status'] ?? '').toString().toLowerCase();
    final bool isOnline = status == 'active' || status == 'online';
    final String name = router['router_name']?.toString().toUpperCase().replaceAll('_', ' ') ?? 'ROUTER UNIT';
    final String model = router['model'] ?? 'WISP GATEWAY';
    
    // Convert CPU to double for progress bar
    String cpuStr = (router['stats']?['cpu'] ?? router['cpu'] ?? '0%').toString().replaceAll('%', '');
    double cpuValue = (double.tryParse(cpuStr) ?? 0) / 100;
    Color cpuColor = cpuValue > 0.8 ? Colors.red : (cpuValue > 0.5 ? Colors.amber : PaceColors.emerald);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark), 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10), 
                decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), 
                child: const Icon(Icons.router_rounded, color: PaceColors.purple, size: 20)
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.purple)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(model, style: GoogleFonts.jetBrainsMono(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
                        if (router['stats']?['version'] != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: PaceColors.getBorder(isDark), borderRadius: BorderRadius.circular(4)),
                            child: Text('v${router['stats']?['version']}', style: GoogleFonts.jetBrainsMono(fontSize: 7, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PaceBadge(
                label: isOnline ? 'ACTIVE' : 'INACTIVE', 
                variant: isOnline ? BadgeVariant.success : BadgeVariant.error
              ),
            ],
          ),
          const SizedBox(height: 16),
          // System Health Ledger
          Row(
            children: [
              _buildStat('LOAD', '${(cpuValue * 100).toInt()}%', Icons.speed_rounded, isDark, 
                sub: Column(
                  children: [
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: cpuValue,
                        backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                        valueColor: AlwaysStoppedAnimation<Color>(cpuColor),
                        minHeight: 2,
                      ),
                    ),
                  ],
                )
              ),
              _buildStat('UPTIME', router['stats']?['uptime'] ?? router['uptime'] ?? '0D 0H', Icons.timer_outlined, isDark),
              _buildStat('USERS', router['users']?.toString() ?? '0', Icons.people_outline, isDark),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.wifi_tethering_rounded, size: 12, color: PaceColors.getDimText(isDark)),
                    const SizedBox(width: 6),
                    Text(router['ip_address'] ?? '0.0.0.0', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _showBillingModal(router, isDark),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: PaceColors.purple.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: PaceColors.purple.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, size: 14, color: PaceColors.purple),
                      const SizedBox(width: 4),
                      Text('BILLING', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, bool isDark, {Widget? sub}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 10, color: PaceColors.getDimText(isDark)),
              const SizedBox(width: 4),
              Text(label, style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.jetBrainsMono(color: PaceColors.getPrimaryText(isDark), fontSize: 13, fontWeight: FontWeight.bold)),
          if (sub != null) sub,
        ],
      ),
    );
  }
}
