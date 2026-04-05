import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/skeleton.dart';

class ActiveUsersScreen extends StatefulWidget {
  const ActiveUsersScreen({super.key});

  @override
  State<ActiveUsersScreen> createState() => _ActiveUsersScreenState();
}

class _ActiveUsersScreenState extends State<ActiveUsersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _activeUsers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      // Re-using routers.php with action=active_connections if available, 
      // or using a generic dashboard call.
      final res = await _apiService.getRouterStatus(forceRefresh: true);
      if (res != null && res['status'] == 'success') {
         // This is a placeholder for real active users logic
         // For now, we use entries as a proxy if active_users isn't a separate endpoint yet
         final entriesRes = await _apiService.getEntries(limit: 50, forceRefresh: true);
         if (mounted && entriesRes != null) {
           setState(() {
             _activeUsers = entriesRes['data'] ?? [];
             _isLoading = false;
           });
         }
      }
    } catch (e) {
      if (mounted) setState(() { _error = "Failed to load active users"; _isLoading = false; });
    }
  }

  void _showSaleModal(dynamic user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SaleModal(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: RefreshIndicator(
        onRefresh: _fetchUsers,
        child: _isLoading 
          ? const SkeletonList()
          : _error != null
            ? Center(child: Text(_error!))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _activeUsers.length,
                itemBuilder: (context, index) {
                  final user = _activeUsers[index];
                  return _buildUserCard(user, isDark);
                },
              ),
      ),
    );
  }

  Widget _buildUserCard(dynamic user, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.person, color: PaceColors.purple, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['username'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(user['mac'] ?? user['ip'] ?? 'Unknown device', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 11)),
              ],
            ),
          ),
          if (_hasPolicy('create_voucher')) ElevatedButton(
            onPressed: () => _showSaleModal(user),
            child: const Text('TICK SALE', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  bool _hasPolicy(String p) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.activeAccount?.type == 'admin' || settings.activeAccount?.type == 'superadmin') return true;
    return settings.activeAccount?.policies.contains(p) ?? false;
  }
}

class _SaleModal extends StatefulWidget {
  final dynamic user;
  const _SaleModal({required this.user});

  @override
  State<_SaleModal> createState() => _SaleModalState();
}

class _SaleModalState extends State<_SaleModal> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: PaceColors.getBorder(isDark), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          const Icon(Icons.shopping_cart_outlined, size: 48, color: PaceColors.purple),
          const SizedBox(height: 16),
          const Text('CONVERT TO SALE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Register this voucher usage as a verified sale in the system?', textAlign: TextAlign.center, style: TextStyle(color: PaceColors.getDimText(isDark))),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: PaceColors.getBorder(isDark)),
                  ),
                  child: const Text('CANCEL'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : () async {
                    setState(() => _isProcessing = true);
                    final api = ApiService();
                    final res = await api.tickSale(widget.user['username']?.toString() ?? '');
                    
                    if (mounted) {
                       setState(() => _isProcessing = false);
                       if (res != null && (res['status'] == 'success' || res['status'] == 200)) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale successfully recorded')));
                       } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res?['message'] ?? 'Failed to record sale')));
                       }
                    }
                  },
                  child: _isProcessing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('CONFIRM'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
