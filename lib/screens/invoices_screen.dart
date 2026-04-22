import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/api_service.dart';
import '../services/settings_provider.dart';
import 'package:provider/provider.dart';
import '../theme/pace_theme.dart';
import 'package:intl/intl.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _invoices = [];
  bool _isLoading = true;
  Map<String, dynamic>? _accountDetails;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final acc = await _api.getAccountDetails(forceRefresh: forceRefresh);
      if (acc != null && acc['status'] == 'success') _accountDetails = acc['data'];

      final inv = await _api.getInvoices(forceRefresh: forceRefresh);
      if (inv != null && inv['status'] == 'success') {
        setState(() {
          _invoices = inv['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Invoices load error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    status = status.toLowerCase();
    if (status == 'paid') return Colors.emerald;
    if (status == 'overdue') return Colors.red;
    return Colors.amber;
  }

  void _showPayModal(dynamic invoice) {
    final TextEditingController phoneController = TextEditingController(text: _accountDetails?['phone'] ?? '');
    bool isPaying = false;
    String? payMessage;
    String? status; // 'pending', 'success', 'failed'

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(LucideIcons.creditCard, color: PaceColors.purple, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    "PAY INVOICE",
                    style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w800, color: PaceColors.purple, letterSpacing: 1),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PaceColors.bgSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PaceColors.outline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.between,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("AMOUNT DUE", style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1)),
                        Text(
                          "KES ${double.tryParse(invoice['amount'].toString())?.toStringAsFixed(2) ?? '0.00'}",
                          style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.w800, color: PaceColors.purple),
                        ),
                      ],
                    ),
                    const Icon(LucideIcons.receipt, color: Colors.grey, size: 24, opticalSize: 0.5),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (status == null || status == 'failed') ...[
                if (status == 'failed') ...[
                   Container(
                     padding: const EdgeInsets.all(10),
                     decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red[100]!)),
                     child: Text(payMessage ?? "Payment failed", style: GoogleFonts.figtree(fontSize: 11, color: Colors.red[700], fontWeight: FontWeight.w600)),
                   ),
                   const SizedBox(height: 10),
                ],
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: "M-Pesa Phone Number",
                    labelStyle: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                    prefixIcon: const Icon(LucideIcons.phone, size: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isPaying ? null : () async {
                      setModalState(() { isPaying = true; payMessage = null; });
                      try {
                        final res = await _api.payInvoice(invoice['id'].toString(), phoneController.text);
                        if (res != null && res['status'] == 'success') {
                          setModalState(() {
                            status = 'pending';
                            payMessage = "Please enter your M-Pesa PIN on your phone...";
                          });
                          // In a real app, we would start polling here. For now, we'll just show the success screen after a delay or manually refresh.
                        } else {
                          setModalState(() {
                            status = 'failed';
                            payMessage = res?['message'] ?? "Initiation failed";
                          });
                        }
                      } catch (e) {
                         setModalState(() { status = 'failed'; payMessage = e.toString(); });
                      } finally {
                        setModalState(() => isPaying = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PaceColors.purple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: isPaying 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text("PAY VIA M-PESA", style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                  ),
                ),
              ] else if (status == 'pending') ...[
                 Padding(
                   padding: const EdgeInsets.symmetric(vertical: 20),
                   child: Column(
                     children: [
                       const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, color: PaceColors.purple)),
                       const SizedBox(height: 16),
                       Text("WAITING FOR PAYMENT", style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w800, color: PaceColors.purple, letterSpacing: 1)),
                       const SizedBox(height: 4),
                       Text(payMessage ?? "", textAlign: TextAlign.center, style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[600])),
                     ],
                   ),
                 ),
              ] else if (status == 'success') ...[
                 Padding(
                   padding: const EdgeInsets.symmetric(vertical: 20),
                   child: Column(
                     children: [
                       Container(
                         padding: const EdgeInsets.all(12),
                         decoration: BoxDecoration(color: Colors.emerald[50], shape: BoxShape.circle),
                         child: const Icon(LucideIcons.checkCircle2, color: Colors.emerald, size: 40),
                       ),
                       const SizedBox(height: 16),
                       Text("PAYMENT SUCCESSFUL", style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.emerald, letterSpacing: 1)),
                       const SizedBox(height: 20),
                       SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: OutlinedButton(
                          onPressed: () { Navigator.pop(context); _loadData(forceRefresh: true); },
                          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: Text("CLOSE", style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w800, color: PaceColors.purple, letterSpacing: 1)),
                        ),
                      ),
                     ],
                   ),
                 ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaceColors.bgSubtle,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "INVOICES",
              style: GoogleFonts.figtree(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: PaceColors.purple,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              "Manage and pay your monthly bills",
              style: GoogleFonts.figtree(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey[400],
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _loadData(forceRefresh: true),
            icon: Icon(LucideIcons.refreshCw, size: 18, color: PaceColors.purple),
          ),
        ],
      ),
      body: _isLoading
          ? _buildShimmer()
          : _invoices.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: () => _loadData(forceRefresh: true),
                  color: PaceColors.purple,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _invoices.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final inv = _invoices[index];
                      final status = inv['status']?.toString() ?? 'pending';
                      final color = _getStatusColor(status);

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PaceColors.outline),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      status == 'paid' ? LucideIcons.checkCircle2 : status == 'overdue' ? LucideIcons.alertCircle : LucideIcons.clock,
                                      color: color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          inv['invoice_number'] ?? 'Inv-000',
                                          style: GoogleFonts.jetbrainsMono(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Due: ${inv['due_date']}",
                                          style: GoogleFonts.figtree(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "KES ${double.tryParse(inv['amount'].toString())?.toStringAsFixed(2) ?? '0.00'}",
                                        style: GoogleFonts.figtree(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: PaceColors.purple,
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: GoogleFonts.figtree(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900,
                                            color: color,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (status != 'paid')
                              Container(
                                decoration: BoxDecoration(
                                  color: PaceColors.bgSubtle.withOpacity(0.5),
                                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                                  border: Border(top: BorderSide(color: PaceColors.outline)),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _showPayModal(inv),
                                      icon: const Icon(LucideIcons.creditCard, size: 14),
                                      label: Text("PAY NOW", style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                      style: TextButton.styleFrom(
                                        foregroundColor: PaceColors.purple,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.receipt, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            "NO INVOICES YET",
            style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey[400], letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Your monthly generated invoices will appear here.",
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (c, i) => const SizedBox(height: 12),
      itemBuilder: (c, i) => Container(
        height: 100,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
