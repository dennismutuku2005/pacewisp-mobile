import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final ApiService _apiService = ApiService();
  final _currencyFormat = NumberFormat("#,###", "en_US");
  
  List<dynamic> _invoices = [];
  bool _isLoading = true;
  Map<String, dynamic>? _accountDetails;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final acc = await _apiService.getAccountDetails(forceRefresh: true);
      final res = await _apiService.getInvoices(forceRefresh: true);
      
      if (mounted) {
        setState(() {
          _accountDetails = acc?['data'];
          _invoices = res?['data'] ?? [];
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Column(
      children: [
        _buildHeader(isDark),
        _buildSummary(isDark),
        Expanded(
          child: _isLoading && _invoices.isEmpty
            ? const Padding(padding: EdgeInsets.all(16.0), child: SkeletonList(count: 8))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: PaceColors.purple,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: _invoices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildInvoiceCard(_invoices[index], isDark),
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
          Text('INVOICES', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
          Text('MANAGE AND PAY YOUR MONTHLY BILLS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildSummary(bool isDark) {
    final unpaidInvoices = _invoices.where((i) => i['status']?.toString().toLowerCase() != 'paid').toList();
    final totalDue = unpaidInvoices.fold<double>(0, (sum, i) => sum + (double.tryParse(i['amount'].toString()) ?? 0));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark), 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('OUTSTANDING BALANCE', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Text('KES ${_currencyFormat.format(totalDue)}', style: GoogleFonts.figtree(fontSize: 28, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark), letterSpacing: -1)),
          ]),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: const Icon(LucideIcons.receipt, color: PaceColors.purple, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(dynamic inv, bool isDark) {
    final status = inv['status']?.toString().toLowerCase() ?? 'pending';
    final isPaid = status == 'paid';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: isPaid ? PaceColors.emerald.withOpacity(0.1) : Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(isPaid ? LucideIcons.checkCircle : LucideIcons.clock, color: isPaid ? PaceColors.emerald : Colors.amber, size: 18),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv['invoice_number'] ?? 'INV-000', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
                    Text('DUE DATE: ${inv['due_date']}', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('KES ${_currencyFormat.format(inv['amount'])}', style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w600, color: PaceColors.purple)),
                  PaceBadge(label: status.toUpperCase(), variant: isPaid ? BadgeVariant.success : BadgeVariant.warning),
                ],
              ),
            ],
          ),
          if (!isPaid) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _handlePayment(inv),
                  icon: const Icon(LucideIcons.creditCard, size: 14),
                  label: Text('PAY VIA M-PESA', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
                  style: TextButton.styleFrom(foregroundColor: PaceColors.purple),
                ),
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Please login to the Web Portal to download PDF invoices and receipts.'),
                      backgroundColor: PaceColors.purple,
                    ));
                  },
                  icon: const Icon(LucideIcons.download, size: 14),
                  label: Text('DOWNLOAD', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handlePayment(dynamic invoice) async {
    final phoneController = TextEditingController(text: _accountDetails?['phone'] ?? '');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PaceColors.getBackground(Provider.of<SettingsProvider>(context).isDarkMode),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('SETTLE INVOICE', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600, color: PaceColors.purple)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confirm payment of KES ${_currencyFormat.format(invoice['amount'])} for invoice ${invoice['invoice_number']}.', style: GoogleFonts.figtree(fontSize: 12)),
            const SizedBox(height: 20),
            _buildField('M-PESA PHONE NUMBER', phoneController, LucideIcons.phone, TextInputType.phone, isDark: Provider.of<SettingsProvider>(context).isDarkMode),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: PaceColors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('INITIATE', style: GoogleFonts.figtree(fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment initiation successful. Check your phone for M-Pesa prompt.')));
      await _apiService.payInvoice(invoice['id'].toString(), phoneController.text);
      _loadData();
    }
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, TextInputType type, {required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: PaceColors.getBorder(isDark))),
          child: TextField(
            controller: controller,
            keyboardType: type,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(icon: Icon(icon, size: 14, color: PaceColors.purple), border: InputBorder.none),
          ),
        ),
      ],
    );
  }
}
