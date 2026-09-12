import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
      _error = "Failed to sync with theme library. Please check your connection.";
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
      _error = res?['message'] ?? "Theme marketplace currently unavailable.";
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Theme activated and synced to router successfully', style: GoogleFonts.figtree()),
            backgroundColor: PaceColors.emerald,
          ),
        );
        _fetchActiveThemes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res?['message'] ?? 'Activation failed', style: GoogleFonts.figtree()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      setState(() => _isActivating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    if (!settings.hasPolicy('manage_themes')) {
      return Center(
        child: Text('Access Restricted', style: GoogleFonts.figtree(fontSize: 16, color: PaceColors.getDimText(isDark))),
      );
    }

    return Column(
      children: [
        _buildHeader(isDark),
        if (_error != null) _buildErrorBanner(isDark),
        Expanded(
          child: _isLoading
              ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 6))
              : RefreshIndicator(
                  onRefresh: _loadInitialData,
                  color: PaceColors.purple,
                  child: _themes.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: PaceEmptyState(
                            title: 'No Themes Available',
                            subtitle: 'Unable to retrieve captive portal designs.',
                            onRetry: _loadInitialData,
                            isDark: isDark,
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                          itemCount: _themes.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            if (i == _themes.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2),
                                ),
                              );
                            }
                            return _buildThemeCard(_themes[i], isDark);
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
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle, color: Colors.red, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_error!, style: GoogleFonts.figtree(fontSize: 12, color: Colors.red.shade700)),
          ),
          TextButton(
            onPressed: _loadInitialData,
            child: Text('Retry', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Portal Themes',
            style: GoogleFonts.figtree(
              color: PaceColors.getPrimaryText(isDark),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Choose and deploy captive portal templates to your routers',
            style: GoogleFonts.figtree(
              color: PaceColors.getDimText(isDark),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(dynamic t, bool isDark) {
    final activeInstances = _activeThemes.where((at) => at['theme_id']?.toString() == t['id']?.toString()).toList();
    final bool isActive = activeInstances.isNotEmpty;
    final name = t['theme_name'] ?? 'Captive Theme';
    final category = t['theme_category']?.toString() ?? 'General';
    final description = t['theme_description']?.toString() ?? 'Modern responsive captive portal design.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => _showPreview(t, isDark),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 72,
              height: 56,
              decoration: BoxDecoration(
                color: PaceColors.getSurface(isDark),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PaceColors.getBorder(isDark)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (t['preview_url'] != null)
                    Image.network(
                      t['preview_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(LucideIcons.image, size: 16, color: Colors.grey),
                    )
                  else
                    const Icon(LucideIcons.image, size: 16, color: Colors.grey),
                  Container(color: Colors.black.withOpacity(0.15)),
                  const Center(child: Icon(LucideIcons.maximize2, color: Colors.white, size: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: GoogleFonts.figtree(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: PaceColors.getPrimaryText(isDark),
                        ),
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 6),
                      PaceBadge(label: 'Active', variant: BadgeVariant.success),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  category.toUpperCase(),
                  style: GoogleFonts.figtree(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: PaceColors.purple,
                  ),
                ),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _showActivateModal(t, isDark),
            style: ElevatedButton.styleFrom(
              backgroundColor: PaceColors.purple,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Deploy',
              style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600),
            ),
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
              width: 280,
              height: 480,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: PaceColors.getBorder(isDark), width: 6),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 10))],
              ),
              clipBehavior: Clip.antiAlias,
              child: t['preview_url'] != null
                  ? Image.network(
                      t['preview_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(LucideIcons.image, color: Colors.white24, size: 48)),
                    )
                  : const Center(child: Icon(LucideIcons.image, color: Colors.white24, size: 48)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text('Close', style: GoogleFonts.figtree(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showActivateModal(t, isDark);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PaceColors.purple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text('Deploy to Router', style: GoogleFonts.figtree(fontWeight: FontWeight.w600)),
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
      backgroundColor: PaceColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Deploy Portal Theme',
                    style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                  ),
                  IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              Text(
                'Upload and activate ${t['theme_name'] ?? 'Theme'} on target Mikrotik node.',
                style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getDimText(isDark)),
              ),
              const SizedBox(height: 20),
              Text(
                'Target Router Node',
                style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark)),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: PaceColors.getSurface(isDark),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PaceColors.getBorder(isDark)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedRouterId,
                    icon: const Icon(LucideIcons.chevronDown, size: 16),
                    dropdownColor: PaceColors.getCard(isDark),
                    style: GoogleFonts.figtree(fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark), fontSize: 13),
                    items: _routers
                        .map((r) => DropdownMenuItem<String>(
                              value: r['id'].toString(),
                              child: Text(r['router_name'] ?? 'Node'),
                            ))
                        .toList(),
                    onChanged: (val) => setM(() => selectedRouterId = val),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: PaceColors.getBorder(isDark)),
                      ),
                      child: Text('Cancel', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: (selectedRouterId == null || _isActivating)
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              await _activateTheme(t['id'].toString(), selectedRouterId!);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PaceColors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Deploy Now', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
