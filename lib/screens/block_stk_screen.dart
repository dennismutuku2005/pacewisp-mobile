import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

class BlockStkScreen extends StatefulWidget {
  const BlockStkScreen({super.key});

  @override
  State<BlockStkScreen> createState() => _BlockStkScreenState();
}

class _BlockStkScreenState extends State<BlockStkScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _blocked = [];
  bool _isLoading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final res = await _apiService.fetchData('customers', params: {'action': 'get_blocked'});
    if (mounted && res != null) {
      setState(() {
        _blocked = res['data'] ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    if (!settings.hasPolicy('manage_customers')) {
       return const Center(child: Text('ACCESS RESTRICTED'));
    }

    final filtered = _blocked.where((u) => (u['phone'] ?? '').toString().contains(_search)).toList();

    return Column(
      children: [
        _buildHeader(isDark),
        _buildSearchBox(isDark),
        Expanded(
          child: _isLoading && _blocked.isEmpty
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 8))
            : RefreshIndicator(
                onRefresh: _fetchData,
                color: PaceColors.purple,
                child: filtered.isEmpty 
                  ? _buildEmpty(isDark)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                      itemBuilder: (context, index) => _buildBlockedItem(filtered[index], isDark),
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
          Text('STK PUSH BLACKLIST', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
          Text('RESTRICTED NUMBERS FROM AUTO-PAYMENT PROMPTS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildSearchBox(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
        child: TextField(
          onChanged: (val) => setState(() => _search = val),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'Search blocked number...', 
            hintStyle: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 11), 
            icon: Icon(LucideIcons.search, color: PaceColors.getDimText(isDark), size: 14), 
            border: InputBorder.none, 
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.shieldCheck, size: 48, color: PaceColors.getBorder(isDark)),
          const SizedBox(height: 16),
          Text('CLEAN BLACKLIST', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
          Text('NO NUMBERS ARE CURRENTLY BLOCKED', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
        ],
      ),
    );
  }

  Widget _buildBlockedItem(dynamic item, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['phone']?.toString() ?? 'PRIVATE', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w800, color: PaceColors.purple)),
              Text('REASON: ${item['reason'] ?? 'MANUAL BLOCK'}', style: GoogleFonts.figtree(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold)),
            ]),
          ),
          ElevatedButton(
            onPressed: () => _handleUnblock(item['phone']),
            style: ElevatedButton.styleFrom(backgroundColor: PaceColors.emerald.withOpacity(0.1), foregroundColor: PaceColors.emerald, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('UNBLOCK', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUnblock(String phone) async {
    final res = await _apiService.unblockNumber(phone);
    if (res?['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Number unblocked successfully'), backgroundColor: PaceColors.emerald));
      _fetchData();
    }
  }
}
