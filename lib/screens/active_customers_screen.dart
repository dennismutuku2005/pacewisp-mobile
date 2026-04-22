import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
import 'customer_history_screen.dart';

class ActiveCustomersScreen extends StatefulWidget {
  const ActiveCustomersScreen({super.key});

  @override
  State<ActiveCustomersScreen> createState() => _ActiveCustomersScreenState();
}

class _ActiveCustomersScreenState extends State<ActiveCustomersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _active = [];
  bool _isLoading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final res = await _apiService.getActiveCustomers(forceRefresh: true);
    if (mounted) {
      setState(() {
        _active = res?['users'] ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    if (!settings.hasPolicy('view_active_users')) {
      return const Center(child: Text('ACCESS RESTRICTED'));
    }

    final filtered = _active.where((u) => 
      (u['phone'] ?? '').toString().contains(_search) || 
      (u['mac'] ?? '').toString().toLowerCase().contains(_search.toLowerCase())
    ).toList();

    return Column(
      children: [
        _buildHeader(isDark),
        _buildSearchBox(isDark),
        _buildStatsBar(isDark, filtered.length),
        Expanded(
          child: _isLoading && _active.isEmpty
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 8))
            : RefreshIndicator(
                onRefresh: _fetchData,
                color: PaceColors.purple,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                  itemBuilder: (context, index) => _buildUserCard(filtered[index], isDark),
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
          Text('LIVE CONNECTIONS', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
          Text('CURRENTLY ONLINE HOTSPOT SESSIONS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildSearchBox(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
        child: TextField(
          onChanged: (val) => setState(() => _search = val),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'Filter by phone or MAC...', 
            hintStyle: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 11), 
            icon: Icon(LucideIcons.search, color: PaceColors.getDimText(isDark), size: 14), 
            border: InputBorder.none, 
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBar(bool isDark, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: PaceColors.emerald.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: PaceColors.emerald.withOpacity(0.2))),
            child: Row(children: [
               Container(width: 6, height: 6, decoration: const BoxDecoration(color: PaceColors.emerald, shape: BoxShape.circle)),
               const SizedBox(width: 8),
               Text('$count ONLINE NOW', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.black, color: PaceColors.emerald, letterSpacing: 1)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(dynamic u, bool isDark) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerHistoryScreen(phone: u['phone'].toString()))),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u['phone']?.toString() ?? 'PRIVATE', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w800, color: PaceColors.getPrimaryText(isDark))),
                const SizedBox(height: 2),
                Text(u['mac']?.toString().toUpperCase() ?? '00:00:00:00:00:00', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(u['ip']?.toString() ?? '0.0.0.0', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
              const PaceBadge(label: 'CONNECTED', variant: BadgeVariant.success),
            ]),
          ],
        ),
      ),
    );
  }
}
