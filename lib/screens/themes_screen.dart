import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/empty_state.dart';
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
  int _totalPages = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _isActivating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreThemes();
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      await Future.wait([
        _fetchThemes(page: 1, isInitial: true),
        _fetchRouters(),
        _fetchActiveThemes(),
      ]);
    } catch (e) {
      _error = "Failed to sync with library. Check connection.";
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchThemes({required int page, bool isInitial = false}) async {
    final res = await _apiService.getMarketplaceThemes(page: page, limit: 10);
    
    if (mounted && (res?['status'] == 'success' || res?['status'] == 200)) {
      final List<dynamic> newThemes = res?['data'] ?? [];
      final pagination = res?['pagination'];
      
      setState(() {
        if (isInitial) {
          _themes = newThemes;
        } else {
          // Filter duplicates
          final existingIds = _themes.map((t) => t['id'].toString()).toSet();
          final filtered = newThemes.where((t) => !existingIds.contains(t['id'].toString())).toList();
          _themes.addAll(filtered);
        }
        
        if (pagination != null) {
          _page = int.tryParse(pagination['page'].toString()) ?? page;
          _totalPages = int.tryParse(pagination['pages'].toString()) ?? 1;
          _hasMore = _page < _totalPages;
        } else {
          _hasMore = newThemes.length >= 10;
        }
      });
    } else if (isInitial) {
      _error = res?['message'] ?? "Marketplace currently unavailable.";
    }
  }

  Future<void> _loadMoreThemes() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    await _fetchThemes(page: _page + 1);
    if (mounted) setState(() => _isLoadingMore = false);
  }

  Future<void> _fetchRouters() async {
    final res = await _apiService.getRouters(forceRefresh: true);
    if (mounted) _routers = res?['data'] ?? [];
  }

  Future<void> _fetchActiveThemes() async {
    final res = await _apiService.getActiveThemes(forceRefresh: true);
    if (mounted && (res?['status'] == 'success' || res?['status'] == 200)) {
      setState(() => _activeThemes = res?['data'] ?? []);
    }
  }

  Future<void> _activateTheme(String themeId, String routerId) async {
    setState(() => _isActivating = true);
    final res = await _apiService.activateTheme(themeId, routerId);
    
    if (mounted) {
      if (res?['status'] == 'success' || res?['status'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Theme Activated and Synced Successfully'), 
          backgroundColor: PaceColors.emerald,
          behavior: SnackBarBehavior.floating,
        ));
        _fetchActiveThemes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res?['message'] ?? 'Activation Failed'), 
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
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
        if (_error != null) _buildErrorBanner(isDark),
        Expanded(
          child: _isLoading 
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 8))
            : RefreshIndicator(
                onRefresh: _loadInitialData,
                color: PaceColors.purple,
                child: _themes.isEmpty
                  ? SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: PaceEmptyState(onRetry: _loadInitialData, isDark: isDark))
                  : ListView.separated(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      itemCount: _themes.length + (_hasMore ? 1 : 1),
                      separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark).withOpacity(0.5), height: 1),
                      itemBuilder: (ctx, i) {
                        if (i == _themes.length) {
                          if (_hasMore) {
                            return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)));
                          } else {
                            return Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 48), child: Text('LIBRARY COMPLETED', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark).withOpacity(0.3), letterSpacing: 3))));
                          }
                        }
                        return _buildThemeItem(_themes[i], isDark);
                      },
                    ),
              ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent.withOpacity(0.2))),
      child: Row(children: [
        const Icon(LucideIcons.alertTriangle, color: Colors.redAccent, size: 16),
        const SizedBox(width: 12),
        Expanded(child: Text(_error!, style: GoogleFonts.figtree(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w600))),
        TextButton(onPressed: _loadInitialData, child: const Text('RETRY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.redAccent))),
      ]),
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
          Text('INFINITE SCROLL THROUGH PREMIUM PORTAL DESIGNS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildThemeItem(dynamic t, bool isDark) {
    final activeInstances = _activeThemes.where((at) => at['theme_id']?.toString() == t['id']?.toString()).toList();
    final bool isActive = activeInstances.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          InkWell(
            onTap: () => _showPreview(t, isDark),
            child: Container(
              width: 72, height: 54,
              decoration: BoxDecoration(
                color: PaceColors.getSurface(isDark), 
                borderRadius: BorderRadius.circular(12), 
                border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (t['preview_url'] != null) 
                    Image.network(t['preview_url'], fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(LucideIcons.image, size: 16, color: Colors.grey))
                  else 
                    const Icon(LucideIcons.image, size: 16, color: Colors.grey),
                  Container(color: Colors.black.withOpacity(0.1)),
                  const Center(child: Icon(LucideIcons.maximize, color: Colors.white, size: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(t['theme_name'] ?? 'THEME', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w700, color: PaceColors.getPrimaryText(isDark), letterSpacing: -0.2))),
              if (isActive) ...[
                 const SizedBox(width: 8),
                 PaceBadge(label: activeInstances.length > 1 ? 'ACTIVE (${activeInstances.length})' : 'ACTIVE', variant: BadgeVariant.success),
              ],
            ]),
            const SizedBox(height: 2),
            Text(t['theme_category']?.toString().toUpperCase() ?? 'GENERAL', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1.2)),
            if (t['theme_description'] != null)
              Text(t['theme_description'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w500)),
          ])),
          const SizedBox(width: 8),
          Column(
            children: [
              ElevatedButton(
                onPressed: () => _showActivateModal(t, isDark),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PaceColors.purple, 
                  foregroundColor: Colors.white, 
                  elevation: 0,
                  minimumSize: const Size(80, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), 
                  padding: const EdgeInsets.symmetric(horizontal: 12)
                ),
                child: const Text('ACTIVATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
            ],
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
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 280, height: 560,
              decoration: BoxDecoration(
                color: Colors.black, 
                borderRadius: BorderRadius.circular(44), 
                border: Border.all(color: PaceColors.getBorder(isDark), width: 8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20))]
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: t['preview_url'] != null 
                      ? Image.network(t['preview_url'], fit: BoxFit.cover, errorBuilder: (_,__,___) => const Center(child: Icon(LucideIcons.image, color: Colors.white24, size: 48))) 
                      : const Center(child: Icon(LucideIcons.image, color: Colors.white24, size: 48)),
                  ),
                  // Mockup notch
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(width: 80, height: 20, decoration: const BoxDecoration(color: Colors.black, borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx), 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), 
                  child: const Text('CLOSE'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showActivateModal(t, isDark);
                  }, 
                  style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), 
                  child: const Text('ACTIVATE THIS'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showActivateModal(dynamic t, bool isDark) {
    String? selectedRouterId = _routers.isNotEmpty ? _routers.first['id'].toString() : null;
    
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
              Text('ACTIVATE DESIGN', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w800, color: PaceColors.purple, letterSpacing: 1.5)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16), 
                decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark))), 
                child: Row(children: [
                  Container(width: 60, height: 45, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)), clipBehavior: Clip.antiAlias, child: Image.network(t['preview_url'] ?? '', fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(LucideIcons.image, size: 16))),
                  const SizedBox(width: 16),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['theme_name'] ?? 'Theme', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('${t['theme_category']?.toString().toUpperCase()} PORTAL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark))),
                    ],
                  )),
                ]),
              ),
              const SizedBox(height: 24),
              Text('TARGET ROUTER', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark))),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedRouterId,
                    icon: const Icon(LucideIcons.chevronDown, size: 16),
                    hint: const Text('Select a router...'),
                    style: TextStyle(fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark), fontSize: 13),
                    items: _routers.map((r) => DropdownMenuItem<String>(value: r['id'].toString(), child: Text(r['router_name'] ?? 'NODE'))).toList(),
                    onChanged: (val) => setM(() => selectedRouterId = val),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.withOpacity(0.2))),
                child: Row(children: [
                  const Icon(LucideIcons.alertTriangle, color: Colors.amber, size: 16),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Activation will sync all hotspot files (login, status, logout) to the selected router immediately.', style: TextStyle(fontSize: 10, color: Colors.amber.shade700, fontWeight: FontWeight.w600))),
                ]),
              ),
              const SizedBox(height: 32),
              SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
                onPressed: (selectedRouterId == null || _isActivating) ? null : () async {
                   Navigator.pop(ctx);
                   await _activateTheme(t['id'].toString(), selectedRouterId!);
                },
                style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _isActivating ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('ACTIVATE NOW', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
