import 'package:flutter/material.dart';
import 'dart:async';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'sms_screen.dart';
import 'sms_logs_screen.dart';

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
    _initializeDefaultIndex();
    _setupHomeWidgetListener();
  }

  void _initializeDefaultIndex() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.hasPolicy('view_dashboard')) {
      // Find first allowed index
      if (settings.hasPolicy('view_entries')) _selectedIndex = 3;
      else if (settings.hasPolicy('view_vouchers')) _selectedIndex = 1;
      else if (settings.hasPolicy('view_income')) _selectedIndex = 2;
    }
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

    if (_isAuthenticating) return;

    if (_lastUnlockTime != null) {
      final diff = DateTime.now().difference(_lastUnlockTime!).inSeconds;
      if (diff < 10) return;
    }

    // Force lock screen immediately
    if (mounted) {
      setState(() => _isLocked = true);
    }
  }

  Future<bool> _authenticate() async {
    if (_isAuthenticating) return false;
    setState(() => _isAuthenticating = true);
    
    try {
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
    } catch (e) {
      if (mounted) setState(() => _isAuthenticating = false);
      return false;
    }
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
    const SmsScreen(),
    const SmsLogsScreen(),
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
                    if (settings.hasPolicy('view_dashboard'))
                      _buildDrawerItem(0, 'Dashboard', LucideIcons.layoutDashboard, isDark),
                    if (settings.hasPolicy('view_entries'))
                      _buildDrawerItem(3, 'Entries', LucideIcons.activity, isDark),
                    if (settings.hasPolicy('view_notifications'))
                      _buildDrawerItem(4, 'Notifications', LucideIcons.bell, isDark),

                    _buildDrawerSection('PREPAID MANAGEMENT', isDark),
                    if (settings.hasPolicy('view_vouchers'))
                      _buildDrawerItem(1, 'Browse Vouchers', LucideIcons.ticket, isDark),
                    if (settings.hasPolicy('manage_plans'))
                      _buildDrawerItem(7, 'Hotspot Plans', LucideIcons.layers, isDark),

                    _buildDrawerSection('FINANCIALS', isDark),
                    if (settings.hasPolicy('view_income'))
                      _buildDrawerItem(2, 'Revenue Analytics', LucideIcons.pieChart, isDark),
                    if (settings.hasPolicy('manage_expenses'))
                      _buildDrawerItem(9, 'Expense Tracker', LucideIcons.receipt, isDark),
                    if (settings.hasPolicy('view_reports'))
                      _buildDrawerItem(12, 'System Reports', LucideIcons.fileText, isDark),
                    if (settings.hasPolicy('view_mpesa'))
                      _buildDrawerItem(13, 'M-Pesa History', LucideIcons.smartphone, isDark),

                    _buildDrawerSection('CUSTOMER BASE', isDark),
                    if (settings.hasPolicy('view_customers'))
                      _buildDrawerItem(5, 'Monthly Distinct', LucideIcons.calendarDays, isDark),
                    if (settings.hasPolicy('view_active_users'))
                      _buildDrawerItem(6, 'Live Connections', LucideIcons.zap, isDark),
                    if (settings.hasPolicy('manage_customers'))
                      _buildDrawerItem(19, 'Blocked STK Push', LucideIcons.shieldAlert, isDark),

                    _buildDrawerSection('INFRASTRUCTURE', isDark),
                    if (settings.hasPolicy('view_routers'))
                      _buildDrawerItem(8, 'Your Mikrotiks', LucideIcons.router, isDark),
                    if (settings.hasPolicy('wa_alerts'))
                      _buildDrawerItem(11, 'Automated Alerts', LucideIcons.messageSquare, isDark),

                    _buildDrawerSection('CONFIGURATION', isDark),
                    if (settings.hasPolicy('manage_users'))
                      _buildDrawerItem(10, 'Staff Accounts', LucideIcons.badgeCheck, isDark),
                    if (settings.hasPolicy('system_config'))
                      _buildDrawerItem(16, 'Hotspot Config', LucideIcons.sliders, isDark),
                    if (settings.hasPolicy('manage_themes'))
                      _buildDrawerItem(20, 'Design Library', LucideIcons.palette, isDark),
                    if (settings.hasPolicy('view_logs'))
                      _buildDrawerItem(17, 'System Logs', LucideIcons.terminal, isDark),

                    /*
                    _buildDrawerSection('COMMUNICATION', isDark),
                    if (settings.hasPolicy('view_sms'))
                      _buildDrawerItem(21, 'SMS Center', LucideIcons.smartphone, isDark),
                    if (settings.hasPolicy('view_sms'))
                      _buildDrawerItem(22, 'SMS History', LucideIcons.history, isDark),
                    */

                    _buildDrawerSection('YOUR BILLING', isDark),
                    if (settings.hasPolicy('view_bills'))
                      _buildDrawerItem(15, 'My Service Bill', LucideIcons.creditCard, isDark),
                    if (settings.hasPolicy('view_bills'))
                      _buildDrawerItem(14, 'Past Invoices', LucideIcons.history, isDark),

                    const Divider(height: 32),
                    _buildDrawerItem(18, 'App Preferences', LucideIcons.settings, isDark),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(LucideIcons.logOut, color: Colors.blueGrey, size: 20),
                title: Text('Sign Out Session', style: TextStyle(color: PaceColors.getSecondaryText(isDark), fontSize: 13, fontWeight: FontWeight.w600)),
                onTap: () async {
                  int countdown = 4;
                  bool canLogout = false;
                  
                  await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => StatefulBuilder(
                      builder: (context, setDialogState) {
                        Timer? timer;
                        if (timer == null && countdown > 0) {
                          timer = Timer.periodic(const Duration(seconds: 1), (t) {
                            if (countdown > 0) {
                              setDialogState(() => countdown--);
                            } else {
                              setDialogState(() => canLogout = true);
                              t.cancel();
                            }
                          });
                        }
                        
                        return AlertDialog(
                          backgroundColor: PaceColors.getBackground(isDark),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Row(
                            children: [
                              const Icon(LucideIcons.shieldAlert, color: Colors.orange, size: 20),
                              const SizedBox(width: 12),
                              Text('SECURITY LOGOUT', style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w700, color: PaceColors.getPrimaryText(isDark))),
                            ],
                          ),
                          content: Text(
                            'Are you sure you want to end your active session and return to the landing screen?',
                            style: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getSecondaryText(isDark)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                timer?.cancel();
                                Navigator.pop(ctx);
                              },
                              child: Text('CANCEL', style: TextStyle(color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w700)),
                            ),
                            ElevatedButton(
                              onPressed: !canLogout ? null : () {
                                timer?.cancel();
                                Navigator.pop(ctx);
                                settings.logout();
                                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LandingScreen()));
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.withOpacity(0.1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: Text(
                                canLogout ? 'CONFIRM LOGOUT' : 'LOGOUT IN ${countdown}s',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        );
                      }
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        body: _screens[_selectedIndex],
        bottomNavigationBar: _selectedIndex < 4 ? BottomNavigationBar(
          elevation: 12,
          currentIndex: _selectedIndex > 3 ? 0 : _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: PaceColors.getCard(isDark),
          selectedItemColor: PaceColors.purple,
          unselectedItemColor: PaceColors.getDimText(isDark),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
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
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/sidebar.png'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              PaceColors.purple.withOpacity(0.92),
              PaceColors.purple.withOpacity(0.80),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  settings.activeAccount?.type.toUpperCase() ?? 'ADMIN',
                  style: GoogleFonts.figtree(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (settings.accounts.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: PaceColors.green.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PaceColors.green.withOpacity(0.6)),
                  ),
                  child: Text(
                    '${settings.accounts.length} ACCOUNTS',
                    style: GoogleFonts.figtree(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            settings.accountName ?? 'Administrator',
            style: GoogleFonts.figtree(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            settings.activeAccount != null
                ? "${settings.activeAccount!.subdomain}.${settings.activeAccount!.domain}"
                : 'pacewisp.co.ke',
            style: GoogleFonts.figtree(
              fontSize: 11,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (settings.accounts.length > 1) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isDense: true,
                  isExpanded: true,
                  dropdownColor: PaceColors.purple,
                  icon: const Icon(LucideIcons.chevronsUpDown, size: 14, color: Colors.white),
                  value: settings.accounts.indexWhere((a) =>
                      a.subdomain == settings.activeAccount?.subdomain &&
                      a.domain == settings.activeAccount?.domain),
                  items: List.generate(settings.accounts.length, (i) {
                    final acc = settings.accounts[i];
                    return DropdownMenuItem<int>(
                      value: i,
                      child: Text(
                        '${acc.accountName} (${acc.subdomain})',
                        style: GoogleFonts.figtree(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    );
                  }),
                  onChanged: (newIdx) {
                    if (newIdx != null) {
                      settings.switchAccount(newIdx);
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawerSection(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        title,
        style: GoogleFonts.figtree(
          color: PaceColors.getDimText(isDark),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(int index, String title, IconData icon, bool isDark) {
    bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 1),
      child: ListTile(
        dense: true,
        selected: isSelected,
        selectedTileColor: PaceColors.purple.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          icon,
          color: isSelected ? PaceColors.purple : PaceColors.getSecondaryText(isDark),
          size: 16,
        ),
        title: Text(
          title,
          style: GoogleFonts.figtree(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? PaceColors.purple : PaceColors.getPrimaryText(isDark),
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: PaceColors.purple,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () {
          setState(() => _selectedIndex = index);
          Navigator.pop(context);
        },
      ),
    );
  }
}
