import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

class ThemesScreen extends StatefulWidget {
  const ThemesScreen({super.key});

  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<ThemesScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _themes = [];
  List<dynamic> _routers = [];
  List<dynamic> _activeThemes = [];
  
  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isActivating = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreThemes();
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchThemes(page: 1),
      _fetchRouters(),
      _fetchActiveThemes(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchThemes({required int page}) async {
    final res = await _apiService.fetchData(slug: 'themes', params: {'page': page, 'limit': 10});
    if (mounted && res?['success'] == true) {
      setState(() {
        if (page == 1) {
          _themes = res?['data'] ?? [];
        } else {
          _themes.addAll(res?['data'] ?? []);
        }
        _hasMore = res?['pagination']?['has_more'] ?? false;
        _page = page;
      });
    }
  }

  Future<void> _loadMoreThemes() async {
    setState(() => _isLoadingMore = true);
    await _fetchThemes(page: _page + 1);
    if (mounted) setState(() => _isLoadingMore = false);
  }

  Future<void> _fetchRouters() async {
    final res = await _apiService.getRouters(forceRefresh: true);
    if (mounted) _routers = res?['data'] ?? [];
  }

  Future<void> _fetchActiveThemes() async {
    final res = await _apiService.fetchData(slug: 'active_themes');
    if (mounted && res?['success'] == true) {
      setState(() => _activeThemes = res?['data'] ?? []);
    }
  }

  Future<void> _activateTheme(String themeId, String routerId) async {
    setState(() => _isActivating = true);
    final res = await _apiService.fetchData(slug: 'activate_theme', method: 'POST', body: {
      'theme_id': themeId,
      'router_id': routerId,
    });
    if (mounted) {
      if (res?['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Theme Activated Successfully'), backgroundColor: PaceColors.emerald));
        _fetchActiveThemes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Activation Failed'), backgroundColor: Colors.red));
      }
      setState(() => _isActivating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    if (!settings.hasPolicy('manage_themes')) return const Center(child: Text('ACCESS RESTRICTED'));

    return Column(
      children: [
        _buildHeader(isDark),
        Expanded(
          child: _isLoading 
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 8))
            : RefreshIndicator(
                onRefresh: _loadInitialData,
                color: PaceColors.purple,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: _themes.length + (_isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
                  itemBuilder: (ctx, i) {
                    if (i == _themes.length) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)));
                    return _buildThemeItem(_themes[i], isDark);
                  },
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
          Text('THEME LIBRARY', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
          Text('PREMIUM PORTAL DESIGNS FOR YOUR HOTSPOT', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildThemeItem(dynamic t, bool isDark) {
    final bool isActive = _activeThemes.any((at) => at['theme_id'].toString() == t['id'].toString());
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          InkWell(
            onTap: () => _showPreview(t, isDark),
            child: Container(
              width: 64, height: 48,
              decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: PaceColors.getBorder(isDark))),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (t['preview_url'] != null) Image.network(t['preview_url'], fit: BoxFit.cover) else const Icon(LucideIcons.image, size: 16, color: Colors.grey),
                  Center(child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)), child: const Icon(LucideIcons.maximize, color: Colors.white, size: 12))),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(t['theme_name'] ?? 'THEME', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark))),
              if (isActive) ...[
                 const SizedBox(width: 8),
                 PaceBadge(label: 'ACTIVE', variant: BadgeVariant.success),
              ],
            ]),
            Text(t['theme_category']?.toString().toUpperCase() ?? 'GENERAL', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1)),
          ])),
          ElevatedButton(
            onPressed: () => _showActivateModal(t, isDark),
            style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: const Text('ACTIVATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPreview(dynamic t, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 260, height: 520,
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(40), border: Border.all(color: PaceColors.getBorder(isDark), width: 6)),
              clipBehavior: Clip.antiAlias,
              child: t['preview_url'] != null ? Image.network(t['preview_url'], fit: BoxFit.cover) : const Center(child: Icon(LucideIcons.image, color: Colors.white24, size: 48)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black), child: const Text('CLOSE PREVIEW')),
          ],
        ),
      ),
    );
  }

  void _showActivateModal(dynamic t, bool isDark) {
    String? selectedRouterId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Container(
          padding: EdgeInsets.fromLTRB(24, 32, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ACTIVATE DESIGN', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1)),
              const SizedBox(height: 24),
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(16)), child: Row(children: [
                Container(width: 48, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)), clipBehavior: Clip.antiAlias, child: Image.network(t['preview_url'], fit: BoxFit.cover)),
                const SizedBox(width: 16),
                Text(t['theme_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              ])),
              const SizedBox(height: 24),
              Text('TARGET ROUTER', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
              DropdownButton<String>(
                isExpanded: true,
                value: selectedRouterId,
                hint: const Text('Select a router...'),
                items: _routers.map((r) => DropdownMenuItem<String>(value: r['id'].toString(), child: Text(r['router_name'] ?? 'NODE'))).toList(),
                onChanged: (val) => setM(() => selectedRouterId = val),
              ),
              const SizedBox(height: 32),
              SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
                onPressed: (selectedRouterId == null || _isActivating) ? null : () async {
                   Navigator.pop(ctx);
                   await _activateTheme(t['id'].toString(), selectedRouterId!);
                },
                style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _isActivating ? const CircularProgressIndicator(color: Colors.white) : const Text('ACTIVATE NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
