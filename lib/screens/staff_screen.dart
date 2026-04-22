import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _staff = [];
  bool _isLoading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchCachedThenLive();
  }

  Future<void> _fetchCachedThenLive() async {
    final cached = await _apiService.getStaff(forceRefresh: false);
    if (mounted && cached != null && _staff.isEmpty) {
      setState(() {
        _staff = cached['data'] ?? [];
        _isLoading = false;
      });
    }

    final live = await _apiService.getStaff(forceRefresh: true);
    if (mounted && live != null) {
      setState(() {
        _staff = live['data'] ?? [];
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    final filtered = _staff.where((s) {
      final name = s['name']?.toString().toLowerCase() ?? '';
      final user = s['username']?.toString().toLowerCase() ?? '';
      return name.contains(_search.toLowerCase()) || user.contains(_search.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: () => _fetchCachedThenLive(),
      color: PaceColors.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('STAFF MANAGEMENT', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
              Text('ADMIN ACCESS & POLICY CONTROL', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ]),
          ),
          _buildSearchBox(isDark),
          Expanded(
            child: _isLoading && _staff.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 10))
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildStaffCard(filtered[index], isDark),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
        child: TextField(
          onChanged: (val) => setState(() => _search = val),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
          decoration: InputDecoration(
            hintText: 'Search staff members...', 
            hintStyle: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 12), 
            icon: Icon(Icons.search_rounded, color: PaceColors.getDimText(isDark), size: 20), 
            border: InputBorder.none, 
          ),
        ),
      ),
    );
  }

  Widget _buildStaffCard(dynamic s, bool isDark) {
    final type = s['type']?.toString().toUpperCase() ?? 'STAFF';
    final status = s['status']?.toString().toUpperCase() ?? 'ACTIVE';
    final isPrimary = s['is_primary'] == true || s['is_primary'] == 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: Row(children: [
        CircleAvatar(radius: 20, backgroundColor: PaceColors.purple.withOpacity(0.1), child: Icon(isPrimary ? Icons.shield_rounded : Icons.person_rounded, color: PaceColors.purple, size: 20)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s['name'] ?? 'STAFF', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w800, color: PaceColors.getPrimaryText(isDark), letterSpacing: -0.2)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.at_rounded, size: 8, color: PaceColors.getDimText(isDark)),
            const SizedBox(width: 4),
            Text(s['username'] ?? '', style: GoogleFonts.figtree(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          PaceBadge(label: type, variant: type == 'ADMIN' || type == 'SUPERADMIN' ? BadgeVariant.info : BadgeVariant.secondary),
          const SizedBox(height: 6),
          PaceBadge(label: status, variant: status == 'ACTIVE' ? BadgeVariant.success : BadgeVariant.error),
        ]),
      ]),
    );
  }
}
