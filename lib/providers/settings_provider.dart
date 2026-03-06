import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../services/api_service.dart';

class SettingsProvider with ChangeNotifier {
  List<PaceAccount> _accounts = [];
  int _activeAccountIndex = -1; // Restored this missing field
  bool _isDarkMode = false;
  bool _isLoading = true;
  bool _isAppLockEnabled = false;
  String? _appPin;

  List<PaceAccount> get accounts => _accounts;
  PaceAccount? get activeAccount => _activeAccountIndex != -1 && _activeAccountIndex < _accounts.length ? _accounts[_activeAccountIndex] : null;
  bool get isDarkMode => _isDarkMode;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => activeAccount != null;
  bool get isAppLockEnabled => _isAppLockEnabled;
  String? get appPin => _appPin;

  // Legacy getters for backward compatibility
  String? get accountName => activeAccount?.accountName;
  String? get subdomain => activeAccount?.subdomain;
  String? get token => activeAccount?.token;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _isAppLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
    _appPin = prefs.getString('app_pin');
    
    final accountsJson = prefs.getString('pace_accounts');
    if (accountsJson != null) {
      final List<dynamic> decoded = jsonDecode(accountsJson);
      _accounts = decoded.map((a) => PaceAccount.fromJson(a)).toList();
    }

    _activeAccountIndex = prefs.getInt('active_account_index') ?? (_accounts.isNotEmpty ? 0 : -1);
    
    if (activeAccount != null) {
      await ApiService().init();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pace_accounts', jsonEncode(_accounts.map((a) => a.toJson()).toList()));
    await prefs.setInt('active_account_index', _activeAccountIndex);
    await prefs.setBool('app_lock_enabled', _isAppLockEnabled);
    if (_appPin != null) await prefs.setString('app_pin', _appPin!);
    
    if (activeAccount != null) {
      await prefs.setString('subdomain', activeAccount!.subdomain);
      await prefs.setString('domain', activeAccount!.domain);
      await prefs.setString('token', activeAccount!.token);
      await ApiService().init();
    }
  }

  Future<void> setTemporaryConfig(String subdomain, String domain) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subdomain', subdomain);
    await prefs.setString('domain', domain);
    await ApiService().init();
  }

  void toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  void toggleAppLock(String? pin) async {
    _isAppLockEnabled = pin != null;
    _appPin = pin;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> login(String subdomain, String domain, String accountName, String token) async {
    final newAccount = PaceAccount(
      subdomain: subdomain,
      domain: domain,
      accountName: accountName,
      token: token,
      lastLogin: DateTime.now().toIso8601String(),
    );

    int existingIndex = _accounts.indexWhere((a) => a.subdomain == subdomain && a.domain == domain && a.accountName == accountName);
    if (existingIndex != -1) {
      _accounts[existingIndex] = newAccount;
      _activeAccountIndex = existingIndex;
    } else {
      _accounts.add(newAccount);
      _activeAccountIndex = _accounts.length - 1;
    }

    await _saveSettings();
    notifyListeners();
  }

  Future<void> switchAccount(int index) async {
    if (index >= 0 && index < _accounts.length) {
      _activeAccountIndex = index;
      await _saveSettings();
      notifyListeners();
    }
  }

  Future<void> removeAccount(int index) async {
    if (index >= 0 && index < _accounts.length) {
      _accounts.removeAt(index);
      if (_accounts.isEmpty) {
        _activeAccountIndex = -1;
      } else if (_activeAccountIndex >= _accounts.length) {
        _activeAccountIndex = 0;
      }
      await _saveSettings();
      notifyListeners();
    }
  }

  void logout() async {
    if (_activeAccountIndex != -1) {
      await removeAccount(_activeAccountIndex);
    }
  }
}
