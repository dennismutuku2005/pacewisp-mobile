import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/skeleton.dart';

class MyBillScreen extends StatefulWidget {
  const MyBillScreen({super.key});

  @override
  State<MyBillScreen> createState() => _MyBillScreenState();
}

class _MyBillScreenState extends State<MyBillScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: _isLoading 
        ? const SkeletonList()
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 32),
              _buildBillCard(isDark),
              const SizedBox(height: 32),
              _buildStatusRow('SERVICE TIER', 'Standard Enterprise', isDark),
              _buildStatusRow('RENEWAL DATE', '05 APR 2026', isDark),
              _buildStatusRow('ACCOUNT STATUS', 'ACTIVE', isDark, isEmerald: true),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: PaceColors.purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('GENERATE PDF INVOICE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 13)),
              ),
            ],
          ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('MY SERVICE BILL', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
      Text('TRACK YOUR ACCOUNT BILLING & SUBSCRIPTIONS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
    ]);
  }

  Widget _buildBillCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5),
        boxShadow: isDark ? [] : [
          BoxShadow(color: PaceColors.purple.withOpacity(0.05), blurRadius: 40, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: PaceColors.purple, size: 20),
              const SizedBox(width: 12),
              Text('CURRENT BALANCE', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 16),
          Text('KSH 2,450.00', style: GoogleFonts.figtree(fontSize: 40, fontWeight: FontWeight.normal, color: PaceColors.getPrimaryText(isDark), letterSpacing: -1)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: PaceColors.emerald.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Text('NO OUTSTANDING BILL', style: TextStyle(color: PaceColors.emerald, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, bool isDark, {bool isEmerald = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
          Text(value, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold, color: isEmerald ? PaceColors.emerald : PaceColors.getPrimaryText(isDark))),
        ],
      ),
    );
  }
}
