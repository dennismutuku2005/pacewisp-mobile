import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'cache_service.dart';

class ApiService {
  final Dio _dio = Dio();
  final CacheService _cache = CacheService();
  String? _subdomain;
  String? _domain;

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  
  // Singleton memory cache to ensure instant UI transitions
  static final Map<String, dynamic> _memoryCache = {};
  
  Map<String, dynamic>? getMemoryCached(String slug, {Map<String, dynamic>? params}) {
    final key = "${_subdomain ?? 'default'}_${slug}_${params.toString()}";
    return _memoryCache[key];
  }
  
  ApiService._internal() {
    _dio.options.followRedirects = true;
    _dio.options.validateStatus = (status) => status != null && status < 500;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _subdomain = prefs.getString('subdomain');
    _domain = prefs.getString('domain') ?? 'pacewisp.co.ke';
  }

  String get host {
    if (_subdomain != null && _subdomain!.isNotEmpty) {
      if (_subdomain!.contains('.')) {
        return _subdomain!;
      }
      return '$_subdomain.$_domain';
    }
    return _domain ?? 'pacewisp.co.ke';
  }

  final List<String> _possibleApiPaths = [
    '/dashboard/v1',
    '/dashboard',
    '/portal',
    '/',
  ];

  String? _detectedPath;

  Future<Map<String, dynamic>?> _requestWithFallback(String endpoint, {String method = 'GET', Map<String, dynamic>? data, Map<String, dynamic>? queryParameters}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    debugPrint('API: Token presence check: ${token != null ? "HAS TOKEN" : "NO TOKEN"}');

    Map<String, String> headers = {
      'Accept': 'application/json',
      'X-Client': 'WispApp', // Triggers 1-year JWT token in backend
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final protocols = ['https'];
    List<String> pathsToTry = _detectedPath != null ? [_detectedPath!] : _possibleApiPaths;

    // If we have a detected path, try it first. If it fails with 404, we might be looking for a file in a different folder.
    List<String> currentTry = _detectedPath != null ? [_detectedPath!] : _possibleApiPaths;
    
    for (var path in currentTry) {
      final res = await _doRequest('https', host, path, endpoint, method, data, queryParameters, headers);
      if (res != null) return res;
    }

    // If we tried a specific detected path and it failed, try all others.
    if (_detectedPath != null) {
      for (var path in _possibleApiPaths) {
        if (path == _detectedPath) continue;
        final res = await _doRequest('https', host, path, endpoint, method, data, queryParameters, headers);
        if (res != null) return res;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _doRequest(String protocol, String host, String path, String endpoint, String method, Map<String, dynamic>? data, Map<String, dynamic>? queryParameters, Map<String, String> headers) async {
    String cleanPath = path;
    if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
    if (cleanPath.endsWith('/') && cleanPath != '/') cleanPath = cleanPath.substring(0, cleanPath.length - 1);
    
    final separator = cleanPath == '/' ? '' : cleanPath;
    final url = '$protocol://$host$separator$endpoint';
    
    try {
      debugPrint('API: Probing URL: $url');
      final response = await _dio.request(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          headers: headers,
          validateStatus: (s) => true,
        ),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        // Only set detected path if it's a "standard" data response or we don't have one
        if (_detectedPath == null) _detectedPath = cleanPath;
        if (response.data is Map) return response.data as Map<String, dynamic>;
        if (response.data is String) return jsonDecode(response.data) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('API: EXCEPTION at $url: $e');
    }
    return null;
  }

  void _showGlobalError(String message) {
    scaffoldMessengerKey.currentState?.clearSnackBars();
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- API ROUTING LOGIC ---

  Future<Map<String, dynamic>?> fetchData({
    required String slug,
    Map<String, dynamic>? params,
    String method = 'GET',
    Map<String, dynamic>? body,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final subdomainKey = _subdomain ?? 'default';

    // Map internal actions to correct PHP files
    String phpFile = '/dashboard.php';
    if (slug == 'vouchers') phpFile = '/vouchers.php';
    else if (slug == 'income') phpFile = '/income.php';
    else if (slug == 'entries') phpFile = '/entries.php';
    else if (slug == 'customers') phpFile = '/customers.php';
    else if (slug == 'customer_history') phpFile = '/customer_history.php';
    else if (slug == 'plans') phpFile = '/hotspot_plans.php';
    else if (slug == 'account') phpFile = '/account.php';
    else if (slug == 'logs') phpFile = '/logs.php';
    else if (slug == 'routers') phpFile = '/routers.php';
    else if (slug == 'expenses') phpFile = '/expenses.php';
    else if (slug == 'report') phpFile = '/income_report.php';
    else if (slug == 'staff') phpFile = '/staff.php';
    else if (slug == 'wa_alerts') phpFile = '/wa-alerts.php';
    else if (slug == 'mpesa') phpFile = '/mpesa_transactions.php';
    else if (slug == 'invoices') phpFile = '/invoices.php';
    else if (slug == 'notifications') phpFile = '/notifications.php';
    else if (slug == 'monthly_customers') phpFile = '/monthly_users.php';
    else if (slug == 'active_customers') phpFile = '/active_connections.php';
    else if (slug == 'themes') phpFile = '/themes.php';
    else if (slug == 'active_themes') phpFile = '/themes.php';
    else if (slug == 'system_settings') phpFile = '/system_data.php';
    else if (slug == 'profile') phpFile = '/account.php';
    else if (slug == 'prepaid_vouchers') phpFile = '/vouchers.php';
    else if (slug == 'prepaid_plans') phpFile = '/hotspot_plans.php';
    else if (slug == 'create_vouchers') phpFile = '/vouchers.php';
    else if (slug == 'delete_vouchers') phpFile = '/vouchers.php';
    else if (slug == 'activate_theme') phpFile = '/themes.php';
    else if (slug == 'save_plans') phpFile = '/hotspot_plans.php';

    final cacheKey = "${subdomainKey}_${slug}_${params.toString()}";
    if (!forceRefresh) {
      final cached = await _cache.get(cacheKey, subdomain: subdomainKey, expiry: const Duration(minutes: 5));
      if (cached != null) return cached;
    }

    final data = await _requestWithFallback(phpFile, method: method, data: body, queryParameters: params);
    if (data != null && (data['status'] == 'success' || data['status'] == 200 || data['status'] == '200')) {
      if (method == 'GET') {
        _memoryCache[cacheKey] = data; // Update memory cache
        await _cache.save(cacheKey, data, subdomain: subdomainKey);
      }
    }
    return data;
  }

  // --- ACTIONS ---

  Future<bool> pingInstance() async {
    _detectedPath = null; 
    final res = await _requestWithFallback('/auth.php?action=ping');
    if (res != null) {
      final message = res['message']?.toString();
      return message == 'PaceWISP API is online';
    }
    return false;
  }

  Future<Map<String, dynamic>?> login(String username, String password) async {
    return await _requestWithFallback('/auth.php?action=login', method: 'POST', data: {'username': username, 'password': password});
  }

  // Dashboard Summary (uses dashboard.php)
  Future<Map<String, dynamic>?> getSummaryWidgets({String? router, String? startDate, String? endDate, bool forceRefresh = false}) async => 
    fetchData(slug: 'widgets', params: {'action': 'widgets', 'router': router, 'startDate': startDate, 'endDate': endDate}, forceRefresh: forceRefresh);
    
  Future<Map<String, dynamic>?> getSummaryCharts({String? router, String? startDate, String? endDate, bool forceRefresh = false}) async => 
    fetchData(slug: 'charts', params: {'action': 'charts', 'router': router, 'startDate': startDate, 'endDate': endDate}, forceRefresh: forceRefresh);
    
  Future<Map<String, dynamic>?> getRecentTransactions({String? router, String? startDate, String? endDate, int limit = 5, bool forceRefresh = false}) async => 
    fetchData(slug: 'recent_transactions', params: {'action': 'recent_transactions', 'limit': limit, 'router': router, 'startDate': startDate, 'endDate': endDate}, forceRefresh: forceRefresh);

  // Vouchers
  Future<Map<String, dynamic>?> getVouchers({String? search, String? router, int page = 1, bool forceRefresh = false}) async => fetchData(slug: 'vouchers', params: {'search': search, 'router_name': router, 'page': page}, forceRefresh: forceRefresh);
  Future<Map<String, dynamic>?> createVoucher(Map<String, dynamic> data) async => _requestWithFallback('/vouchers.php', method: 'POST', data: data);
  Future<Map<String, dynamic>?> deleteVoucher(String id) async => _requestWithFallback('/vouchers.php', method: 'DELETE', data: {'ids': [id]});
  Future<Map<String, dynamic>?> deleteVouchers(List<String> ids) async => _requestWithFallback('/vouchers.php', method: 'DELETE', data: {'ids': ids});

  // Customers
  Future<Map<String, dynamic>?> getCustomers({String? search, int page = 1, bool forceRefresh = false}) async => fetchData(slug: 'customers', params: {'search': search, 'page': page}, forceRefresh: forceRefresh);
  Future<Map<String, dynamic>?> getMonthlyCustomers({bool forceRefresh = false}) async => fetchData(slug: 'monthly_customers', params: {'action': 'get_monthly'}, forceRefresh: forceRefresh);
  Future<Map<String, dynamic>?> getActiveCustomers({bool forceRefresh = false}) async => fetchData(slug: 'active_customers', params: {'action': 'get_active'}, forceRefresh: forceRefresh);
  Future<Map<String, dynamic>?> getCustomerHistory({required String phone, int page = 1, bool forceRefresh = false}) async => fetchData(slug: 'customer_history', params: {'phone': phone, 'page': page}, forceRefresh: forceRefresh);
  Future<Map<String, dynamic>?> deleteCustomer(String phone) async => _requestWithFallback('/customers.php?action=delete', method: 'POST', data: {'phone': phone});

  // Blacklist / STK Push Control (uses block_stk.php)
  Future<Map<String, dynamic>?> checkBlockStatus(String phone) async => _requestWithFallback('/block_stk.php?phone=$phone&t=${DateTime.now().millisecondsSinceEpoch}');
  Future<Map<String, dynamic>?> blockNumber(String phone, {String reason = 'Manual Block'}) async => _requestWithFallback('/block_stk.php', method: 'POST', data: {'phone': phone, 'reason': reason});
  Future<Map<String, dynamic>?> unblockNumber(String phone) async => _requestWithFallback('/block_stk.php?phone=$phone', method: 'DELETE');

  // Plans
  Future<Map<String, dynamic>?> getPlans(String routerId, {bool forceRefresh = false}) async => fetchData(slug: 'plans', params: {'router_id': routerId}, forceRefresh: forceRefresh);
  Future<Map<String, dynamic>?> createPlan(Map<String, dynamic> data) async => _requestWithFallback('/hotspot_plans.php?action=create', method: 'POST', data: data);
  Future<Map<String, dynamic>?> deletePlan(String id) async => _requestWithFallback('/hotspot_plans.php?action=delete', method: 'POST', data: {'id': id});

  // Income Report
  Future<Map<String, dynamic>?> getIncome({String? router, String? startDate, String? endDate, bool forceRefresh = false}) async {
    final params = <String, dynamic>{};
    if (router != null && router.isNotEmpty) params['router'] = router;
    if (startDate != null && startDate.isNotEmpty) params['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
    return fetchData(slug: 'income', params: params, forceRefresh: forceRefresh);
  }

  // Entries
  Future<Map<String, dynamic>?> getEntries({String? search, String? router, String? startDate, String? endDate, int page = 1, bool forceRefresh = false}) async => 
    fetchData(slug: 'entries', params: {'search': search, 'router': router, 'startDate': startDate, 'endDate': endDate, 'page': page}, forceRefresh: forceRefresh);

  // System Logs
  Future<Map<String, dynamic>?> getLogs({String? search, int page = 1, bool forceRefresh = false}) async => fetchData(slug: 'logs', params: {'search': search, 'page': page}, forceRefresh: forceRefresh);
  
  // Routers
  Future<Map<String, dynamic>?> getRouters({bool forceRefresh = false}) async => 
    fetchData(slug: 'routers', params: {'limit': 100}, forceRefresh: forceRefresh);

  Future<Map<String, dynamic>?> getRouterStatus({int limit = 5, bool forceRefresh = false}) async => 
    fetchData(slug: 'widgets', params: {'action': 'router_status', 'limit': limit}, forceRefresh: forceRefresh);

  Future<Map<String, dynamic>?> updateRouter(String id, Map<String, dynamic> data) async => 
    _requestWithFallback('/routers.php?id=$id', method: 'POST', data: data);

  Future<Map<String, dynamic>?> pingRouter(String ip, dynamic port) async => 
    _requestWithFallback('/routers.php?action=ping', method: 'POST', data: {'ip': ip, 'port': int.tryParse(port.toString()) ?? 8728});

  Future<Map<String, dynamic>?> restartRouter(String ip, dynamic port) async => 
    _requestWithFallback('/routers.php?action=restart', method: 'POST', data: {'ip': ip, 'port': int.tryParse(port.toString()) ?? 8728});

  // Expenses
  Future<Map<String, dynamic>?> getExpenses({int? month, int? year, bool forceRefresh = false}) async => 
    fetchData(slug: 'expenses', params: {'month': month, 'year': year}, forceRefresh: forceRefresh);

  // Staff
  Future<Map<String, dynamic>?> getStaff({bool forceRefresh = false}) async => 
    fetchData(slug: 'staff', forceRefresh: forceRefresh);
  
  Future<Map<String, dynamic>?> createStaff(Map<String, dynamic> data) async => 
    _requestWithFallback('/staff.php', method: 'POST', data: data);

  Future<Map<String, dynamic>?> updateStaff(String id, Map<String, dynamic> data) async => 
    _requestWithFallback('/staff.php?id=$id', method: 'POST', data: data);

  Future<Map<String, dynamic>?> deleteStaff(String id) async => 
    _requestWithFallback('/staff.php?id=$id', method: 'DELETE');

  // Notifications
  Future<Map<String, dynamic>?> getNotifications({int page = 1, bool forceRefresh = false}) async => 
    fetchData(slug: 'notifications', params: {'page': page}, forceRefresh: forceRefresh);

  Future<Map<String, dynamic>?> markNotificationRead(String? id) async => 
    _requestWithFallback('/notifications.php', method: 'POST', data: {'action': 'mark_read', 'id': id});

  // WhatsApp Alerts
  Future<Map<String, dynamic>?> getWhatsAppAlertsConfig() async => 
    fetchData(slug: 'wa_alerts', forceRefresh: true);

  Future<Map<String, dynamic>?> performWhatsAppAlertAction(String action, Map<String, dynamic> data) async => 
    _requestWithFallback('/wa-alerts.php?action=$action', method: 'POST', data: data);

  // My Bill
  Future<Map<String, dynamic>?> getAccountDetails({bool forceRefresh = false}) async => 
    fetchData(slug: 'account', forceRefresh: forceRefresh);

  Future<Map<String, dynamic>?> getFinancialReport({int? month, int? year, String? startDate, String? endDate, bool forceRefresh = false}) async => 
    fetchData(slug: 'report', params: {'month': month, 'year': year, 'startDate': startDate, 'endDate': endDate}, forceRefresh: forceRefresh);

  // System Config
  Future<Map<String, dynamic>?> getSystemConfig(String routerId) async => 
    _requestWithFallback('/hotspot_plans.php?action=get_system_config&router_id=$routerId');

  Future<Map<String, dynamic>?> saveSystemConfig(String routerId, Map<String, dynamic> data) async => 
    _requestWithFallback('/hotspot_plans.php?action=save_system_config&router_id=$routerId', method: 'POST', data: data);

  // M-Pesa Transactions
  Future<Map<String, dynamic>?> getMpesaTransactions({int page = 1, String search = '', bool forceRefresh = false}) async => 
    fetchData(slug: 'mpesa', params: {'page': page, 'search': search}, forceRefresh: forceRefresh);

  // Invoices & Billing
  Future<Map<String, dynamic>?> getInvoices({bool forceRefresh = false}) async => 
    fetchData(slug: 'invoices', forceRefresh: forceRefresh);

  Future<Map<String, dynamic>?> payInvoice(String invoiceId, String phone) async => 
    _requestWithFallback('/pay_invoice.php', method: 'POST', data: {'invoice_id': invoiceId, 'phone_number': phone});

  Future<Map<String, dynamic>?> verifyPayment({String? checkoutId, String? mpesaCode, String? invoiceId}) async => 
    _requestWithFallback('/verify_payment.php', method: 'POST', data: {
      'checkout_id': checkoutId ?? '',
      'mpesa_code': mpesaCode ?? '',
      'invoice_id': invoiceId ?? '',
    });
}
