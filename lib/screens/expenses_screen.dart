import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/empty_state.dart';
import '../components/skeleton.dart';
import '../components/overlay_loader.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ApiService _apiService = ApiService();
  final _currencyFormat = NumberFormat("#,###", "en_US");

  List<dynamic> _expenses = [];
  Map<String, dynamic>? _metrics;
  bool _isLoading = true;
  bool _isSaving = false;

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  Future<void> _fetchExpenses({bool forceRefresh = true}) async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getExpenses(
        month: _selectedDate.month,
        year: _selectedDate.year,
        forceRefresh: forceRefresh,
      );
      if (mounted && res != null) {
        setState(() {
          _expenses = res['data'] ?? [];
          _metrics = res['metrics'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + offset);
    });
    _fetchExpenses();
  }

  Future<void> _handleAddExpense() async {
    final isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = 'running expenses';
    DateTime expenseDate = DateTime.now();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PaceColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                      'Record New Expense',
                      style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                    ),
                    IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(ctx, false)),
                  ],
                ),
                Text(
                  'Track operational costs, hardware maintenance, or utility bills.',
                  style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getDimText(isDark)),
                ),
                const SizedBox(height: 20),
                _modalField('Description', descCtrl, LucideIcons.fileText, isDark, hint: 'e.g. Fiber lease, Router repair'),
                const SizedBox(height: 14),
                _modalField('Amount (KES)', amountCtrl, LucideIcons.dollarSign, isDark, hint: 'e.g. 1500', keyboardType: TextInputType.number),
                const SizedBox(height: 14),
                Text('Category', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: PaceColors.getSurface(isDark),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: PaceColors.getBorder(isDark)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: category,
                      isExpanded: true,
                      dropdownColor: PaceColors.getCard(isDark),
                      items: const [
                        DropdownMenuItem(value: 'running expenses', child: Text('Running Expenses / Operational')),
                        DropdownMenuItem(value: 'bill', child: Text('Fixed Bills / ISP Lease')),
                        DropdownMenuItem(value: 'upgrade', child: Text('Infrastructure / Hardware Upgrade')),
                        DropdownMenuItem(value: 'other', child: Text('Other Overhead')),
                      ],
                      onChanged: (v) => setM(() => category = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
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
                        onPressed: () {
                          if (descCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Description and amount are required')));
                            return;
                          }
                          Navigator.pop(ctx, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PaceColors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Save Expense', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == true) {
      setState(() => _isSaving = true);
      try {
        final res = await _apiService.fetchData(
          slug: 'expenses',
          method: 'POST',
          body: {
            'action': 'add',
            'description': descCtrl.text.trim(),
            'amount': amountCtrl.text.trim(),
            'category': category,
            'date': DateFormat('yyyy-MM-dd').format(expenseDate),
          },
        );
        if (res?['status'] == 'success') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Expense recorded successfully', style: GoogleFonts.figtree()), backgroundColor: PaceColors.emerald),
            );
          }
          await _fetchExpenses();
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Widget _modalField(String label, TextEditingController c, IconData icon, bool isDark, {String? hint, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: PaceColors.getSurface(isDark),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PaceColors.getBorder(isDark)),
          ),
          child: TextField(
            controller: c,
            keyboardType: keyboardType,
            style: GoogleFonts.figtree(fontSize: 14, color: PaceColors.getPrimaryText(isDark)),
            decoration: InputDecoration(
              icon: Icon(icon, size: 16, color: PaceColors.getDimText(isDark)),
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

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return PaceOverlayLoader(
      isLoading: _isSaving,
      message: 'Saving expense...',
      child: RefreshIndicator(
        onRefresh: () => _fetchExpenses(),
        color: PaceColors.purple,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 16),
            _buildMonthNavigator(isDark),
            const SizedBox(height: 20),
            if (_isLoading && _metrics == null)
              const GridSkeleton(count: 4)
            else if (_metrics == null && _expenses.isEmpty)
              PaceEmptyState(
                title: 'No Expenses Recorded',
                subtitle: 'We couldn\'t find any operational costs for this period.',
                onRetry: () => _fetchExpenses(),
                isDark: isDark,
              )
            else ...[
              _buildMetricsGrid(isDark),
              const SizedBox(height: 24),
              _buildRecentExpenses(isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expenses',
              style: GoogleFonts.figtree(
                color: PaceColors.getPrimaryText(isDark),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Track and audit operational network overheads',
              style: GoogleFonts.figtree(
                color: PaceColors.getDimText(isDark),
                fontSize: 12,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _handleAddExpense,
          icon: const Icon(LucideIcons.plus, size: 16),
          label: Text('Record', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: PaceColors.purple,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthNavigator(bool isDark) {
    final label = DateFormat('MMMM yyyy').format(_selectedDate);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: Icon(LucideIcons.chevronLeft, size: 18, color: PaceColors.getDimText(isDark)),
          ),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.figtree(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: PaceColors.getPrimaryText(isDark),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _changeMonth(1),
            icon: Icon(LucideIcons.chevronRight, size: 18, color: PaceColors.getDimText(isDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(bool isDark) {
    if (_isLoading && _metrics == null) return const GridSkeleton(count: 4);

    final summary = _metrics?['summary'] ?? {};
    final total = _metrics?['total'] ?? 0;

    final cards = [
      {'label': 'Total Outflow', 'value': total, 'color': Colors.red.shade600, 'icon': LucideIcons.trendingDown},
      {'label': 'Fixed Bills', 'value': summary['bill'] ?? 0, 'color': Colors.blue.shade600, 'icon': LucideIcons.receipt},
      {'label': 'Operational', 'value': summary['running expenses'] ?? 0, 'color': PaceColors.emerald, 'icon': LucideIcons.zap},
      {'label': 'Infrastructure', 'value': summary['upgrade'] ?? 0, 'color': Colors.orange.shade600, 'icon': LucideIcons.layers},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final c = cards[index];
        final color = c['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PaceColors.getCard(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PaceColors.getBorder(isDark)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    c['label'] as String,
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PaceColors.getDimText(isDark),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(c['icon'] as IconData, color: color, size: 14),
                  ),
                ],
              ),
              Text(
                'KES ${_currencyFormat.format(c['value'])}',
                style: GoogleFonts.figtree(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: PaceColors.getPrimaryText(isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentExpenses(bool isDark) {
    if (_isLoading && _expenses.isEmpty) return const SkeletonList(count: 4);
    if (_expenses.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        alignment: Alignment.center,
        child: Text(
          'No expenses recorded for this period',
          style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getDimText(isDark)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Expense Breakdown',
          style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _expenses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final e = _expenses[index];
            return _buildExpenseItem(e, isDark);
          },
        ),
      ],
    );
  }

  Widget _buildExpenseItem(dynamic e, bool isDark) {
    final cat = e['category']?.toString().toLowerCase() ?? '';
    BadgeVariant variant = BadgeVariant.primary;
    if (cat == 'bill') {
      variant = BadgeVariant.info;
    } else if (cat == 'upgrade') {
      variant = BadgeVariant.warning;
    } else {
      variant = BadgeVariant.success;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      e['date'] ?? '',
                      style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark)),
                    ),
                    const SizedBox(width: 8),
                    PaceBadge(label: cat.toUpperCase(), variant: variant),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  e['description'] ?? 'Expense',
                  style: GoogleFonts.figtree(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PaceColors.getPrimaryText(isDark),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'KES ${_currencyFormat.format(e['amount'])}',
            style: GoogleFonts.figtree(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
