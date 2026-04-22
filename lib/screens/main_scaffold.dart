import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import 'home_screen.dart';
import 'entries_screen.dart';
import 'vouchers_screen.dart';
import 'income_screen.dart';
import 'customers_screen.dart';
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
import '../services/lock_service.dart';

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

    // Authenticate first to avoid deadlock
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
    // Reset the trigger after a short delay or when the screen changes
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _triggerVouchersModal = false);
    });
  }

  void _onNavigateToRouters() {
    setState(() {
      _selectedIndex = 6; // Go to Routers tab
    });
  }

  List<Widget> get _screens => [
    HomeScreen(
      onGenerateVoucher: _onGenerateVoucher,
      onNavigateToRouters: _onNavigateToRouters,
    ),
    VouchersScreen(openModal: _triggerVouchersModal),
    const IncomeScreen(),
    const EntriesScreen(),
    const CustomersScreen(),
    const PlansScreen(),
    const RoutersScreen(),
    const ExpensesScreen(),
    const StaffScreen(),
    const WhatsAppAlertsScreen(),
    const FinancialReportScreen(),
    const MyBillScreen(),
    const SystemConfigScreen(),
    const MpesaTransactionsScreen(),
    const InvoicesScreen(),
    const SystemLogsScreen(),
    const SettingsScreen(),
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
          setState(() {
            _selectedIndex = 0;
          });
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
                  _buildDrawerItem(0, 'Dashboard', Icons.grid_view_rounded, isDark),
                  if (settings.hasPolicy('view_vouchers'))
                    _buildDrawerItem(1, 'Vouchers', Icons.confirmation_number_outlined, isDark),
                  if (settings.hasPolicy('view_income'))
                    _buildDrawerItem(2, 'Income', Icons.account_balance_wallet_outlined, isDark),
                  if (settings.hasPolicy('view_entries'))
                    _buildDrawerItem(3, 'Entries', Icons.history_rounded, isDark),
                  if (settings.hasPolicy('view_customers'))
                    _buildDrawerItem(4, 'Prepaid Users', Icons.people_outline, isDark),
                  if (settings.hasPolicy('manage_plans'))
                    _buildDrawerItem(5, 'Plans', Icons.layers_outlined, isDark),
                  if (settings.hasPolicy('view_routers'))
                    _buildDrawerItem(6, 'Your Mikrotiks', Icons.router_outlined, isDark),
                  if (settings.hasPolicy('manage_expenses'))
                    _buildDrawerItem(7, 'Expenses', Icons.receipt_rounded, isDark),
                  if (settings.hasPolicy('manage_users'))
                    _buildDrawerItem(8, 'Staff Management', Icons.badge_outlined, isDark),
                  if (settings.hasPolicy('wa_alerts'))
                    _buildDrawerItem(9, 'WhatsApp Alerts', Icons.whatsapp_rounded, isDark),
                  if (settings.hasPolicy('view_reports'))
                    _buildDrawerItem(10, 'Financial Reports', Icons.insert_chart_outlined_rounded, isDark),
                  if (settings.hasPolicy('view_mpesa'))
                    _buildDrawerItem(13, 'M-Pesa History', Icons.smartphone_rounded, isDark),
                  if (settings.hasPolicy('view_bills'))
                    _buildDrawerItem(14, 'Your Invoices', Icons.receipt_long_rounded, isDark),
                  if (settings.hasPolicy('view_bills'))
                    _buildDrawerItem(11, 'My Service Bill', Icons.receipt_rounded, isDark),
                  if (settings.hasPolicy('system_config'))
                    _buildDrawerItem(12, 'System Config', Icons.settings_input_component_rounded, isDark),
                  if (settings.hasPolicy('view_logs'))
                    _buildDrawerItem(15, 'System Logs', Icons.list_alt_rounded, isDark),
                  _buildDrawerItem(16, 'Settings', Icons.settings_outlined, isDark),
                  
                  if (settings.accounts.length > 1) ...[
                    const Divider(height: 32, indent: 20, endIndent: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Text('SWITCH ACCOUNT', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                    ...settings.accounts.asMap().entries.where((e) => e.key != settings.accounts.indexOf(settings.activeAccount!)).map((e) {
                      final acc = e.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: CircleAvatar(
                            radius: 12,
                            backgroundColor: PaceColors.purple.withOpacity(0.1),
                            child: const Icon(Icons.business, size: 12, color: PaceColors.purple),
                          ),
                          title: Text(acc.subdomain, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                          subtitle: Text(acc.domain, style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark))),
                          onTap: () {
                            settings.switchAccount(e.key);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    }).toList(),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: ListTile(
                        dense: true,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: PaceColors.purple.withOpacity(0.2))),
                        leading: const Icon(Icons.add_circle_outline, color: PaceColors.purple, size: 20),
                        title: const Text('ADD ANOTHER ACCOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 0.5)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.blueGrey),
              title: Text('Sign Out', style: TextStyle(color: PaceColors.getSecondaryText(isDark), fontSize: 13, fontWeight: FontWeight.bold)),
              onTap: () {
                settings.logout();
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LandingScreen()));
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: _selectedIndex < 4 ? BottomNavigationBar(
        elevation: 12,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: PaceColors.getCard(isDark),
        selectedItemColor: PaceColors.purple,
        unselectedItemColor: PaceColors.getDimText(isDark),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.confirmation_number_outlined), label: 'Vouchers'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Income'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Entries'),
        ],
      ) : null,
      ),
    );
  }

  Widget _buildDrawerHeader(SettingsProvider settings, bool isDark) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/sidebar.png'),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 56, bottom: 20, left: 20, right: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [PaceColors.purple.withOpacity(0.85), PaceColors.purple.withOpacity(0.4)],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              settings.accountName?.toUpperCase() ?? 'ADMINISTRATOR',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
            ),
            const SizedBox(height: 3),
            Text(
              settings.activeAccount != null ? "${settings.activeAccount!.subdomain}.${settings.activeAccount!.domain}" : 'PACE WISP',
              style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(int index, String title, IconData icon, bool isDark) {
    bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2),
      child: ListTile(
        dense: true,
        selected: isSelected,
        selectedTileColor: PaceColors.purple.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: isSelected ? PaceColors.purple : PaceColors.getSecondaryText(isDark), size: 22),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? PaceColors.purple : PaceColors.getPrimaryText(isDark),
          ),
        ),
        onTap: () {
          setState(() => _selectedIndex = index);
          Navigator.pop(context);
        },
      ),
    );
  }
}
