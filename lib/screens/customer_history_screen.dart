import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/api_service.dart';
import '../theme/pace_theme.dart';

class CustomerHistoryScreen extends StatefulWidget {
  final String phone;
  const CustomerHistoryScreen({super.key, required this.phone});

  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getCustomerHistory(widget.phone);
      if (res != null && res['status'] == 'success') {
        setState(() {
          _data = res['data'];
          _history = res['data']?['history'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("History load error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaceColors.bgSubtle,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "CUSTOMER PROFILE",
          style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w800, color: PaceColors.purple, letterSpacing: 1),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: PaceColors.outline),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(LucideIcons.user, color: PaceColors.purple, size: 30),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.phone,
                        style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.w800, color: PaceColors.purple),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem("SESSIONS", _data?['sessions']?.toString() ?? '0'),
                          _buildStatItem("SPENT", "KES ${_data?['totalSpent']?.toString() ?? '0'}"),
                          _buildStatItem("STATUS", _data?['status'] ?? 'N/A'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  "TRANSACTION HISTORY",
                  style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey[400], letterSpacing: 1.5),
                ),
                const SizedBox(height: 12),

                if (_history.isEmpty)
                  _buildEmpty()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _history.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 10),
                    itemBuilder: (c, i) {
                      final item = _history[i];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PaceColors.outline),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(LucideIcons.ticket, color: PaceColors.purple, size: 16),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['plan_name'] ?? 'Plan', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text(item['date_created'] ?? 'Date', style: GoogleFonts.figtree(fontSize: 10, color: Colors.grey[400])),
                                ],
                              ),
                            ),
                            Text(
                              "KES ${item['amount']}",
                              style: GoogleFonts.jetbrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.purple),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[400], letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(LucideIcons.clock, color: Colors.grey[200], size: 40),
          const SizedBox(height: 12),
          Text("NO HISTORY FOUND", style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[300])),
        ],
      ),
    );
  }
}
