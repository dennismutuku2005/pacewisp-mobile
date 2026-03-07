import 'package:flutter/material.dart';
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

  List<Widget> get _screens => [
    HomeScreen(onGenerateVoucher: _onGenerateVoucher),
    VouchersScreen(openModal: _triggerVouchersModal),
    const IncomeScreen(),
    const EntriesScreen(),
    const CustomersScreen(),
    const PlansScreen(),
    const RoutersScreen(),
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

    return Scaffold(
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
                  _buildDrawerItem(1, 'Vouchers', Icons.confirmation_number_outlined, isDark),
                  _buildDrawerItem(2, 'Income', Icons.account_balance_wallet_outlined, isDark),
                  _buildDrawerItem(3, 'Entries', Icons.history_rounded, isDark),
                  _buildDrawerItem(4, 'Customers', Icons.people_outline, isDark),
                  _buildDrawerItem(5, 'Plans', Icons.layers_outlined, isDark),
                  _buildDrawerItem(6, 'Routers', Icons.router_outlined, isDark),
                  _buildDrawerItem(7, 'System Logs', Icons.list_alt_rounded, isDark),
                  _buildDrawerItem(8, 'Settings', Icons.settings_outlined, isDark),
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
    );
  }

  Widget _buildDrawerHeader(SettingsProvider settings, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 24, left: 24, right: 24),
      decoration: BoxDecoration(
        color: PaceColors.purple.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: PaceColors.getBorder(isDark), width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            settings.accountName?.toUpperCase() ?? 'ADMINISTRATOR',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
          ),
          Text(
            settings.activeAccount != null ? "${settings.activeAccount!.subdomain}.${settings.activeAccount!.domain}" : '',
            style: TextStyle(fontSize: 10, color: PaceColors.getSecondaryText(isDark), fontWeight: FontWeight.bold),
          ),
        ],
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
