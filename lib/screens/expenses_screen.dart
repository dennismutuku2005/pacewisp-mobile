import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';

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
  
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchCachedThenLive();
  }

  Future<void> _fetchCachedThenLive() async {
    // 1. SILENT CACHE LOAD
    final cached = await _apiService.getExpenses(
      month: _selectedDate.month,
      year: _selectedDate.year,
      forceRefresh: false
    );
    if (mounted && cached != null && _expenses.isEmpty) {
      setState(() {
        _expenses = cached['data'] ?? [];
        _metrics = cached['metrics'];
        _isLoading = false;
      });
    }

    // 2. LIVE REFRESH
    final live = await _apiService.getExpenses(
      month: _selectedDate.month,
      year: _selectedDate.year,
      forceRefresh: true
    );
    if (mounted && live != null) {
      setState(() {
        _expenses = live['data'] ?? [];
        _metrics = live['metrics'];
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + offset);
      _isLoading = true;
    });
    _fetchCachedThenLive();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return RefreshIndicator(
      onRefresh: () => _fetchCachedThenLive(),
      color: PaceColors.purple,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 24),
          _buildMonthNavigator(isDark),
          const SizedBox(height: 32),
          _buildMetricsGrid(isDark),
          const SizedBox(height: 32),
          _buildRecentExpenses(isDark),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('EXPENSES MANAGEMENT', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
        Text('TRACK AND MANAGE OPERATIONAL COSTS', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
    ]);
  }

  Widget _buildMonthNavigator(bool isDark) {
    final label = DateFormat('MMMM yyyy').format(_selectedDate).toUpperCase();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2)),
      child: Row(children: [
        IconButton(onPressed: () => _changeMonth(-1), icon: Icon(Icons.chevron_left, color: PaceColors.getDimText(isDark))),
        Expanded(child: Center(child: Text(label, style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1.5)))),
        IconButton(onPressed: () => _changeMonth(1), icon: Icon(Icons.chevron_right, color: PaceColors.getDimText(isDark))),
      ]),
    );
  }

  Widget _buildMetricsGrid(bool isDark) {
    if (_isLoading && _metrics == null) return const SkeletonGrid(count: 4);
    
    final summary = _metrics?['summary'] ?? {};
    final total = _metrics?['total'] ?? 0;

    final cards = [
      {'label': 'TOTAL EXPENSES', 'value': total, 'color': Colors.red, 'icon': Icons.trending_down_rounded},
      {'label': 'BILLS', 'value': summary['bill'] ?? 0, 'color': Colors.blue, 'icon': Icons.receipt_long_rounded},
      {'label': 'RUNNING', 'value': summary['running expenses'] ?? 0, 'color': Colors.green, 'icon': Icons.bolt_rounded},
      {'label': 'UPGRADES', 'value': summary['upgrade'] ?? 0, 'color': Colors.orange, 'icon': Icons.bar_chart_rounded},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final c = cards[index];
        final color = c['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(c['icon'] as IconData, color: color, size: 16)),
            const Spacer(),
            Text(c['label'] as String, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
            Text('KSH ${_currencyFormat.format(c['value'])}', style: GoogleFonts.figtree(fontSize: 15, fontWeight: FontWeight.normal, color: PaceColors.getPrimaryText(isDark))),
          ]),
        );
      },
    );
  }

  Widget _buildRecentExpenses(bool isDark) {
    if (_isLoading && _expenses.isEmpty) return const SkeletonList(count: 5);
    if (_expenses.isEmpty) return Container(padding: const EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('NO EXPENSES RECORDED', style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 2))));

    return Container(
      decoration: BoxDecoration(color: PaceColors.getCard(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('RECENT EXPENSES', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w800, color: PaceColors.purple)),
            Text('OPERATIONAL COST LOGS', style: GoogleFonts.figtree(fontSize: 8, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ]),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _expenses.length,
          separatorBuilder: (_, __) => Divider(color: PaceColors.getBorder(isDark), height: 1),
          itemBuilder: (context, index) {
            final e = _expenses[index];
            return _buildExpenseItem(e, isDark);
          },
        ),
      ]),
    );
  }

  Widget _buildExpenseItem(dynamic e, bool isDark) {
    final cat = e['category']?.toString().toLowerCase() ?? '';
    BadgeVariant variant = BadgeVariant.primary;
    if (cat == 'bill') variant = BadgeVariant.info;
    else if (cat == 'upgrade') variant = BadgeVariant.warning;
    else variant = BadgeVariant.success;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.calendar_today_rounded, size: 10, color: PaceColors.getDimText(isDark)),
                const SizedBox(width: 6),
                Text(e['date'] ?? '', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.purple)),
                const SizedBox(width: 12),
                PaceBadge(label: cat.toUpperCase(), variant: variant),
              ]),
              const SizedBox(height: 8),
              Text(e['description'] ?? '', style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 16),
          Text('KSH ${_currencyFormat.format(e['amount'])}', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.normal, color: PaceColors.purple, letterSpacing: -0.5)),
        ],
      ),
    );
  }
}
