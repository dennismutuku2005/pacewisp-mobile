import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cache_service.dart';

class ApiService {
  final Dio _dio = Dio();
  final CacheService _cache = CacheService();
  String? _subdomain;
  String? _domain;

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  
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
    '/',
  ];

  String? _detectedPath;

  Future<Map<String, dynamic>?> _requestWithFallback(String endpoint, {String method = 'GET', Map<String, dynamic>? data, Map<String, dynamic>? queryParameters}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    final protocols = ['https'];
    List<String> pathsToTry = _detectedPath != null ? [_detectedPath!] : _possibleApiPaths;

    Map<String, String> headers = {
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    for (var protocol in protocols) {
      for (var path in pathsToTry) {
        String cleanPath = path;
        if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
        if (cleanPath.endsWith('/') && cleanPath != '/') cleanPath = cleanPath.substring(0, cleanPath.length - 1);
        
        final separator = cleanPath == '/' ? '' : cleanPath;
        final url = '$protocol://$host$separator$endpoint';
        
        try {
          print('DEBUG: Probing URL: $url');
          final response = await _dio.request(
            url,
            data: data,
            queryParameters: queryParameters,
            options: Options(
              method: method,
              headers: headers,
            ),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            _detectedPath = cleanPath;
            if (response.data is Map) return response.data as Map<String, dynamic>;
            if (response.data is String) return jsonDecode(response.data) as Map<String, dynamic>;
          } else {
            print('DEBUG: Probe returned status ${response.statusCode} at $url');
          }
        } catch (e) {
          print('DEBUG: Probe failed at $url: $e');
        }
      }
    }
    return null;
  }

  // --- API ROUTING LOGIC ---

  Future<Map<String, dynamic>?> fetchData({
    required String slug,
    Map<String, dynamic>? params,
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
    else if (slug == 'plans') phpFile = '/hotspot_plans.php';
    else if (slug == 'logs') phpFile = '/logs.php';
    else if (slug == 'routers') phpFile = '/routers.php';

    final cacheKey = "${slug}_${params.toString()}";
    if (!forceRefresh) {
      final cached = await _cache.get(cacheKey, subdomain: subdomainKey, expiry: const Duration(minutes: 5));
      if (cached != null) return cached;
    }

    final data = await _requestWithFallback(phpFile, queryParameters: params);
    if (data != null && (data['status'] == 'success' || data['status'] == 200)) {
      await _cache.save(cacheKey, data, subdomain: subdomainKey);
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
  Future<Map<String, dynamic>?> getSummaryWidgets({bool forceRefresh = false}) async => fetchData(slug: 'widgets', params: {'action': 'widgets'}, forceRefresh: forceRefresh);
  Future<Map<String, dynamic>?> getSummaryCharts({bool forceRefresh = false}) async => fetchData(slug: 'charts', params: {'action': 'charts'}, forceRefresh: forceRefresh);
  Future<Map<String, dynamic>?> getRecentTransactions({int limit = 5, bool forceRefresh = false}) async => fetchData(slug: 'recent_transactions', params: {'action': 'recent_transactions', 'limit': limit}, forceRefresh: forceRefresh);

  // Vouchers
  Future<Map<String, dynamic>?> getVouchers({String? search, String? router, int page = 1, bool forceRefresh = false}) async => fetchData(slug: 'vouchers', params: {'search': search, 'router_name': router, 'page': page}, forceRefresh: forceRefresh);
  Future<Map<String, dynamic>?> createVoucher(Map<String, dynamic> data) async => _requestWithFallback('/vouchers.php', method: 'POST', data: data);
  Future<Map<String, dynamic>?> deleteVoucher(String id) async => _requestWithFallback('/vouchers.php', method: 'DELETE', data: {'ids': [id]});
  Future<Map<String, dynamic>?> deleteVouchers(List<String> ids) async => _requestWithFallback('/vouchers.php', method: 'DELETE', data: {'ids': ids});

  // Customers
  Future<Map<String, dynamic>?> getCustomers({String? search, int page = 1, bool forceRefresh = false}) async => fetchData(slug: 'customers', params: {'search': search, 'page': page}, forceRefresh: forceRefresh);
  Future<Map<String, dynamic>?> deleteCustomer(String phone) async => _requestWithFallback('/customers.php?action=delete', method: 'POST', data: {'phone': phone});

  // Plans
  Future<Map<String, dynamic>?> getPlans(String routerId, {bool forceRefresh = false}) async => fetchData(slug: 'plans', params: {'router': routerId}, forceRefresh: forceRefresh);
  Future<Map<String, dynamic>?> createPlan(Map<String, dynamic> data) async => _requestWithFallback('/hotspot_plans.php?action=create', method: 'POST', data: data);
  Future<Map<String, dynamic>?> deletePlan(String id) async => _requestWithFallback('/hotspot_plans.php?action=delete', method: 'POST', data: {'id': id});

  // Income Report
  Future<Map<String, dynamic>?> getIncome({String? router, String? startDate, String? endDate, bool forceRefresh = false}) async => fetchData(slug: 'income', params: {'router': router, 'startDate': startDate, 'endDate': endDate}, forceRefresh: forceRefresh);

  // Entries
  Future<Map<String, dynamic>?> getEntries({String? search, String? router, int page = 1, bool forceRefresh = false}) async => fetchData(slug: 'entries', params: {'search': search, 'router': router, 'page': page}, forceRefresh: forceRefresh);

  // System Logs
  Future<Map<String, dynamic>?> getLogs({String? search, int page = 1, bool forceRefresh = false}) async => fetchData(slug: 'logs', params: {'search': search, 'page': page}, forceRefresh: forceRefresh);
  
  // Routers
  Future<Map<String, dynamic>?> getRouters({bool forceRefresh = false}) async => fetchData(slug: 'routers', params: {'action': 'get_routers'}, forceRefresh: forceRefresh);
}
