import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import 'home_screen.dart';
import 'entries_screen.dart';
import 'vouchers_screen.dart';
import 'income_screen.dart';
import 'customers_screen.dart';
import 'monthly_customers_screen.dart';
import 'active_customers_screen.dart';
import 'plans_screen.dart';
import 'routers_screen.dart';
import 'system_logs_screen.dart';
import 'settings_screen.dart';
import 'landing_screen.dart';
import 'loading_screen.dart';
import 'lock_screen.dart';
import 'expenses_screen.dart';
import 'staff_screen.dart';
import 'whatsapp_alerts_screen.dart';
import 'financial_report_screen.dart';
import 'my_bill_screen.dart';
import 'system_config_screen.dart';
import 'mpesa_transactions_screen.dart';
import 'invoices_screen.dart';
import 'notifications_screen.dart';
import '../services/lock_service.dart';
import 'block_stk_screen.dart';
import 'themes_screen.dart';
import 'login_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isLocked = false;
  bool _isAuthenticating = false;
  DateTime? _lastUnlockTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuth();
    _checkLock();
    _setupHomeWidgetListener();
  }

  void _setupHomeWidgetListener() {
    HomeWidget.widgetClicked.listen((Uri? uri) => _handleWidgetClick(uri));
    HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) => _handleWidgetClick(uri));
  }

  void _handleWidgetClick(Uri? uri) {
    if (uri?.host == 'toggle_blur') {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      settings.toggleWidgetBlur();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLock();
    }
  }

  Future<void> _checkLock() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.isAppLockEnabled) {
      if (mounted && _isLocked) setState(() => _isLocked = false);
      return;
    }

    if (_isLocked || _isAuthenticating) return;

    if (_lastUnlockTime != null) {
      if (DateTime.now().difference(_lastUnlockTime!).inSeconds < 5) {
        return;
      }
    }

    final success = await _authenticate();
    if (!success && mounted) {
      setState(() => _isLocked = true);
    }
  }

  Future<bool> _authenticate() async {
    if (_isAuthenticating) return false;
    setState(() => _isAuthenticating = true);
    
    final lockService = LockService();
    final bool success = await lockService.authenticate();

    if (mounted) {
      setState(() {
        _isAuthenticating = false;
        if (success) {
          _isLocked = false;
          _lastUnlockTime = DateTime.now();
        }
      });
    }
    return success;
  }

  void _checkAuth() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.isAuthenticated) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LandingScreen()));
    }
  }

  bool _triggerVouchersModal = false;

  void _onGenerateVoucher() {
    setState(() {
      _selectedIndex = 1; // Go to Vouchers tab
      _triggerVouchersModal = true;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _triggerVouchersModal = false);
    });
  }

  void _onNavigateToRouters() {
    setState(() {
      _selectedIndex = 8; // Go to Routers index
    });
  }

  List<Widget> get _screens => [
    HomeScreen(onGenerateVoucher: _onGenerateVoucher, onNavigateToRouters: _onNavigateToRouters),
    VouchersScreen(openModal: _triggerVouchersModal),
    const IncomeScreen(),
    const EntriesScreen(),
    const NotificationsScreen(),
    const CustomersScreen(),
    const MonthlyCustomersScreen(),
    const ActiveCustomersScreen(),
    const PlansScreen(),
    const RoutersScreen(),
    const ExpensesScreen(),
    const StaffScreen(),
    const WhatsAppAlertsScreen(),
    const FinancialReportScreen(),
    const MpesaTransactionsScreen(),
    const InvoicesScreen(),
    const MyBillScreen(),
    const SystemConfigScreen(),
    const SystemLogsScreen(),
    const SettingsScreen(),
    const BlockStkScreen(),
    const ThemesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    if (settings.isLoading) return const LoadingScreen();
    
    if (_isLocked) {
      return LockScreen(onUnlocked: () {
        setState(() {
          _isLocked = false;
          _lastUnlockTime = DateTime.now();
        });
      });
    }

    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: PaceColors.getBackground(isDark),
        appBar: AppBar(
          centerTitle: false,
          title: Image.asset('assets/images/logoc.png', height: 26, errorBuilder: (_, __, ___) => const Text('PaceWISP')),
          backgroundColor: PaceColors.getBackground(isDark),
          foregroundColor: PaceColors.getPrimaryText(isDark),
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 20, color: PaceColors.getPrimaryText(isDark)),
              onPressed: () => settings.toggleDarkMode(),
            ),
            const SizedBox(width: 8),
          ],
        ),
        drawer: Drawer(
          backgroundColor: PaceColors.getBackground(isDark),
          child: Column(
            children: [
              _buildDrawerHeader(settings, isDark),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildDrawerSection('OVERVIEW', isDark),
                    _buildDrawerItem(0, 'Dashboard', LucideIcons.layoutDashboard, isDark),
                    if (settings.hasPolicy('view_entries'))
                      _buildDrawerItem(3, 'Entries', LucideIcons.activity, isDark),
                    if (settings.hasPolicy('view_notifications'))
                      _buildDrawerItem(4, 'Notifications', LucideIcons.bell, isDark),

                    _buildDrawerSection('PREPAID MANAGEMENT', isDark),
                    if (settings.hasPolicy('view_vouchers'))
                      _buildDrawerItem(1, 'Browse Vouchers', LucideIcons.ticket, isDark),
                    if (settings.hasPolicy('manage_plans'))
                      _buildDrawerItem(8, 'Hotspot Plans', LucideIcons.layers, isDark),

                    _buildDrawerSection('FINANCIALS', isDark),
                    if (settings.hasPolicy('view_income'))
                      _buildDrawerItem(2, 'Revenue Analytics', LucideIcons.pieChart, isDark),
                    if (settings.hasPolicy('manage_expenses'))
                      _buildDrawerItem(10, 'Expense Tracker', LucideIcons.receipt, isDark),
                    if (settings.hasPolicy('view_reports'))
                      _buildDrawerItem(13, 'System Reports', LucideIcons.fileText, isDark),
                    if (settings.hasPolicy('view_mpesa'))
                      _buildDrawerItem(14, 'M-Pesa History', LucideIcons.smartphone, isDark),

                    _buildDrawerSection('CUSTOMER BASE', isDark),
                    if (settings.hasPolicy('view_customers'))
                      _buildDrawerItem(5, 'Master List', LucideIcons.users, isDark),
                    if (settings.hasPolicy('view_customers'))
                      _buildDrawerItem(6, 'Monthly Distinct', LucideIcons.calendarDays, isDark),
                    if (settings.hasPolicy('view_active_users'))
                      _buildDrawerItem(7, 'Live Connections', LucideIcons.zap, isDark),
                    if (settings.hasPolicy('manage_customers'))
                      _buildDrawerItem(20, 'Blocked STK Push', LucideIcons.shieldAlert, isDark),

                    _buildDrawerSection('INFRASTRUCTURE', isDark),
                    if (settings.hasPolicy('view_routers'))
                      _buildDrawerItem(9, 'Your Mikrotiks', LucideIcons.router, isDark),
                    if (settings.hasPolicy('wa_alerts'))
                      _buildDrawerItem(12, 'Automated Alerts', LucideIcons.messageSquare, isDark),

                    _buildDrawerSection('CONFIGURATION', isDark),
                    if (settings.hasPolicy('manage_users'))
                      _buildDrawerItem(11, 'Staff Accounts', LucideIcons.badgeCheck, isDark),
                    if (settings.hasPolicy('system_config'))
                      _buildDrawerItem(17, 'System Setup', LucideIcons.sliders, isDark),
                    if (settings.hasPolicy('manage_themes'))
                      _buildDrawerItem(21, 'Design Library', LucideIcons.palette, isDark),
                    if (settings.hasPolicy('view_logs'))
                      _buildDrawerItem(18, 'System Debug Logs', LucideIcons.terminal, isDark),

                    _buildDrawerSection('YOUR BILLING', isDark),
                    if (settings.hasPolicy('view_bills'))
                      _buildDrawerItem(16, 'My Service Bill', LucideIcons.creditCard, isDark),
                    if (settings.hasPolicy('view_bills'))
                      _buildDrawerItem(15, 'Past Invoices', LucideIcons.history, isDark),

                    const Divider(height: 32),
                    _buildDrawerItem(19, 'Preferences', LucideIcons.settings, isDark),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(LucideIcons.logOut, color: Colors.blueGrey, size: 20),
                title: Text('Sign Out Session', style: TextStyle(color: PaceColors.getSecondaryText(isDark), fontSize: 13, fontWeight: FontWeight.bold)),
                onTap: () {
                  settings.logout();
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LandingScreen()));
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        body: IndexedStack(index: _selectedIndex, children: _screens),
        bottomNavigationBar: _selectedIndex < 4 ? BottomNavigationBar(
          elevation: 12,
          currentIndex: _selectedIndex > 3 ? 0 : _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: PaceColors.getCard(isDark),
          selectedItemColor: PaceColors.purple,
          unselectedItemColor: PaceColors.getDimText(isDark),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(LucideIcons.layoutDashboard), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.ticket), label: 'Vouchers'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.pieChart), label: 'Income'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.activity), label: 'Entries'),
          ],
        ) : null,
      ),
    );
  }

  Widget _buildDrawerHeader(SettingsProvider settings, bool isDark) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: const BoxDecoration(
        image: DecorationImage(image: AssetImage('assets/images/sidebar.png'), fit: BoxFit.cover, alignment: Alignment.centerRight),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [PaceColors.purple, PaceColors.purple.withOpacity(0.5)], begin: Alignment.bottomLeft, end: Alignment.topRight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(settings.accountName?.toUpperCase() ?? 'ADMINISTRATOR', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(settings.activeAccount != null ? "${settings.activeAccount!.subdomain}.${settings.activeAccount!.domain}" : 'PACE WISP', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerSection(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(title, style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.black, letterSpacing: 1.5)),
    );
  }

  Widget _buildDrawerItem(int index, String title, IconData icon, bool isDark) {
    bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 1),
      child: ListTile(
        dense: true,
        selected: isSelected,
        selectedTileColor: PaceColors.purple.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: isSelected ? PaceColors.purple : PaceColors.getSecondaryText(isDark), size: 18),
        title: Text(title, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? PaceColors.purple : PaceColors.getPrimaryText(isDark))),
        onTap: () {
          setState(() => _selectedIndex = index);
          Navigator.pop(context);
        },
      ),
    );
  }
}
