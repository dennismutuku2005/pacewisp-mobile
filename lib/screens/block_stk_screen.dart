import 'dart:async';
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
import '../components/search_bar.dart';
import '../components/overlay_loader.dart';

class BlockStkScreen extends StatefulWidget {
  const BlockStkScreen({super.key});

  @override
  State<BlockStkScreen> createState() => _BlockStkScreenState();
}

class _BlockStkScreenState extends State<BlockStkScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  List<dynamic> _blocked = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getBlockedNumbers();
      if (mounted && res != null) {
        setState(() {
          _blocked = res['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBlock() async {
    final phone = _phoneController.text.trim();
    final reason = _reasonController.text.trim();

    if (phone.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      final check = await _apiService.getBlockedNumbers(phone: phone);
      if (check?['is_blocked'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('This number is already restricted.', style: GoogleFonts.figtree()),
              backgroundColor: Colors.orange.shade700,
            ),
          );
        }
        setState(() => _isProcessing = false);
        return;
      }

      final res = await _apiService.blockNumber(phone, reason: reason.isEmpty ? 'Manual Security Restriction' : reason);
      if (res?['status'] == 'success') {
        _phoneController.clear();
        _reasonController.clear();
        await _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Number restricted successfully', style: GoogleFonts.figtree()),
              backgroundColor: PaceColors.emerald,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Block Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleUnblock(String phone) async {
    final isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Restriction',
          style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
        ),
        content: Text(
          'Allow $phone to initiate payment requests and STK push prompts again?',
          style: GoogleFonts.figtree(fontSize: 14, color: PaceColors.getDimText(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: PaceColors.purple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Allow Access', style: GoogleFonts.figtree(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final res = await _apiService.unblockNumber(phone);
      if (res?['status'] == 'success') {
        await _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Restriction removed for $phone', style: GoogleFonts.figtree()),
              backgroundColor: PaceColors.emerald,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    final filtered = _blocked.where((u) {
      final phone = (u['phone'] ?? '').toString();
      final reason = (u['reason'] ?? '').toString().toLowerCase();
      final q = _search.toLowerCase();
      return phone.contains(q) || reason.contains(q);
    }).toList();

    return PaceOverlayLoader(
      isLoading: _isProcessing,
      message: 'Processing security rule...',
      child: Column(
        children: [
          _buildHeader(isDark),
          _buildQuickActions(isDark),
          Expanded(
            child: _isLoading && _blocked.isEmpty
                ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 6))
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    color: PaceColors.purple,
                    child: filtered.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: PaceEmptyState(
                              title: 'No Security Restrictions',
                              subtitle: 'All customer phone numbers have unrestricted payment and STK checkout access.',
                              onRetry: _fetchData,
                              isDark: isDark,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) => _buildBlockedCard(filtered[index], isDark),
                          ),
                  ),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Blacklist',
                  style: GoogleFonts.figtree(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: PaceColors.purple,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Restrict suspicious phone numbers',
                  style: GoogleFonts.figtree(
                    fontSize: 11,
                    color: PaceColors.getDimText(isDark),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _showBlockModal,
            icon: const Icon(LucideIcons.shieldAlert, size: 15),
            label: Text('Block Number', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: PaceColors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: PaceSearchBar(
        hint: 'Search by phone number or reason...',
        isDark: isDark,
        onChanged: (val) => setState(() => _search = val),
      ),
    );
  }

  Widget _buildBlockedCard(dynamic item, bool isDark) {
    final phone = item['phone']?.toString() ?? 'Unknown';
    final reason = item['reason']?.toString() ?? 'Security Policy';
    final attempts = item['trial_count'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      phone,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: PaceColors.getPrimaryText(isDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (attempts > 0)
                      PaceBadge(
                        label: '$attempts attempts',
                        variant: BadgeVariant.danger,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: GoogleFonts.figtree(
                    fontSize: 12,
                    color: PaceColors.getDimText(isDark),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => _handleUnblock(phone),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: BorderSide(color: PaceColors.emerald.withOpacity(0.5)),
              foregroundColor: PaceColors.emerald,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Unblock',
              style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockModal() {
    final isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PaceColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Block Phone Number',
                    style: GoogleFonts.figtree(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: PaceColors.getPrimaryText(isDark),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                'Prevent this phone number from receiving STK push triggers or checking out on hotspot portals.',
                style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getDimText(isDark)),
              ),
              const SizedBox(height: 20),
              _modalField('Phone Number', _phoneController, LucideIcons.phone, isDark, hint: 'e.g. 0712345678 or 254712...'),
              const SizedBox(height: 14),
              _modalField('Reason for Restriction', _reasonController, LucideIcons.alertTriangle, isDark, hint: 'e.g. Fraud attempts, spam, invalid charges'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: PaceColors.getBorder(isDark)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.figtree(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: PaceColors.getDimText(isDark),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_phoneController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Phone number is required')),
                          );
                          return;
                        }
                        Navigator.pop(context);
                        _handleBlock();
                      },
                      icon: const Icon(LucideIcons.shieldAlert, size: 16),
                      label: Text('Apply Restriction', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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

  Widget _modalField(String label, TextEditingController controller, IconData icon, bool isDark, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: PaceColors.getSurface(isDark),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PaceColors.getBorder(isDark)),
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.figtree(fontSize: 14, color: PaceColors.getPrimaryText(isDark)),
            decoration: InputDecoration(
              icon: Icon(icon, color: PaceColors.getDimText(isDark), size: 16),
              border: InputBorder.none,
              hintText: hint,
              hintStyle: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getDimText(isDark).withOpacity(0.6)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
