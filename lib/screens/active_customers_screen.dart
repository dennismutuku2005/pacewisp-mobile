import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

class ActiveCustomersScreen extends StatefulWidget {
  const ActiveCustomersScreen({super.key});

  @override
  State<ActiveCustomersScreen> createState() => _ActiveCustomersScreenState();
}

class _ActiveCustomersScreenState extends State<ActiveCustomersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _connections = [];
  bool _isLoading = true;
  String _search = '';
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final res = await _apiService.getActiveCustomers(forceRefresh: true);
    if (mounted) {
      setState(() {
        _connections = res?['data'] ?? [];
        _total = res?['pagination']?['total'] ?? _connections.length;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    final filtered = _connections.where((c) {
      final phone = (c['phone'] ?? '').toString();
      final plan = (c['plan'] ?? '').toString().toLowerCase();
      return phone.contains(_search) || plan.contains(_search.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: PaceColors.purple,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ACTIVE CONNECTIONS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
                    Text('REAL-TIME TRACKING OF PAID SESSIONS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ]),
                  _buildPulseCounter(isDark),
                ],
              ),
            ),
            
            _buildSearchBox(isDark),

            Expanded(
              child: _isLoading && _connections.isEmpty
                ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 10))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildConnectionCard(filtered[index], isDark),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseCounter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: PaceColors.emerald.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaceColors.emerald.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: PaceColors.emerald, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(_total.toString(), style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.black, color: PaceColors.emerald)),
            ],
          ),
          Text('ONLINE NOW', style: GoogleFonts.figtree(fontSize: 7, fontWeight: FontWeight.black, color: PaceColors.emerald, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildSearchBox(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
        child: TextField(
          onChanged: (val) => setState(() => _search = val),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
          decoration: InputDecoration(
            hintText: 'Search phone or plan...', 
            hintStyle: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 12), 
            icon: Icon(LucideIcons.search, color: PaceColors.getDimText(isDark), size: 18), 
            border: InputBorder.none, 
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCard(dynamic c, bool isDark) {
    final type = c['type']?.toString().toUpperCase() ?? 'M-PESA';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: Column(
        children: [
          Row(children: [
            CircleAvatar(radius: 18, backgroundColor: PaceColors.purple.withOpacity(0.1), child: Icon(LucideIcons.activity, color: PaceColors.purple, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['phone']?.toString() ?? 'SYSTEM', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: PaceColors.getPrimaryText(isDark), letterSpacing: -0.5)),
              Text(c['plan']?.toString().toUpperCase() ?? 'VOUCHER', style: GoogleFonts.figtree(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
            ])),
            PaceBadge(label: type, variant: type == 'M-PESA' ? BadgeVariant.success : BadgeVariant.info),
          ]),
          const SizedBox(height: 16),
          _buildDetailRow(LucideIcons.clock, 'STARTED', c['created_at'] ?? 'N/A', isDark),
          const SizedBox(height: 8),
          _buildDetailRow(LucideIcons.alertCircle, 'EXPIRES', c['expire_time'] ?? 'N/A', isDark, iconColor: Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark, {Color? iconColor}) {
    return Row(
      children: [
        Icon(icon, size: 10, color: iconColor ?? PaceColors.getDimText(isDark)),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.black, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
        const Spacer(),
        Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
      ],
    );
  }
}
