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

  // Common paths to try if 404 occurs
  final List<String> _possibleApiPaths = [
    '/dashboard/v1',
    '/pace-apis/dashboard/v1',
  ];

  String? _detectedPath;

  Future<Map<String, dynamic>?> _requestWithFallback(String endpoint, {String method = 'GET', Map<String, dynamic>? data, Map<String, dynamic>? queryParameters}) async {
    final protocols = ['https', 'http'];
    
    // Use detected path if we have it
    List<String> pathsToTry = _detectedPath != null ? [_detectedPath!] : _possibleApiPaths;

    for (var protocol in protocols) {
      for (var path in pathsToTry) {
        final url = '$protocol://$host$path$endpoint';
        try {
          print('DEBUG: Probing URL: $url');
          final options = Options(method: method);
          final response = await _dio.request(
            url,
            data: data,
            queryParameters: queryParameters,
            options: options,
          ).timeout(const Duration(seconds: 12));

          print('DEBUG: Response from $url: ${response.statusCode}');
          
          if (response.statusCode == 200) {
            _detectedPath = path; // Cache for next time
            return response.data as Map<String, dynamic>;
          }
        } catch (e) {
          print('DEBUG: Probe failed at $url: $e');
        }
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> getDashboardData({
    String? action,
    String? search,
    String? startDate,
    String? endDate,
    String? router,
    int? page,
    int? limit,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final subdomainKey = _subdomain ?? 'default';

    final cacheKey = "${action}_${router ?? 'all'}_${search ?? ''}_${startDate ?? 'na'}_${endDate ?? 'na'}_${page ?? 1}";

    if (!forceRefresh) {
      final cached = await _cache.get(cacheKey, subdomain: subdomainKey, expiry: const Duration(minutes: 5));
      if (cached != null) return cached;
    }

    final queryParams = <String, dynamic>{};
    if (action != null) queryParams['action'] = action;
    if (search != null) queryParams['search'] = search;
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;
    if (router != null && router != 'All Routers') queryParams['router'] = router;
    if (page != null) queryParams['page'] = page;
    if (limit != null) queryParams['limit'] = limit;
    if (token != null) queryParams['token'] = token;

    final data = await _requestWithFallback('/dashboard.php', queryParameters: queryParams);
    if (data != null && (data['status'] == 'success' || data['status'] == 200)) {
      await _cache.save(cacheKey, data, subdomain: subdomainKey);
    }
    return data;
  }

  Future<bool> pingInstance() async {
    // Reset path detection on ping if it's the first check
    _detectedPath = null; 
    final res = await _requestWithFallback('/auth.php?action=ping');
    return res != null && (res['status'] == 'success' || res['status'] == 200);
  }

  Future<Map<String, dynamic>?> login(String username, String password) async {
    return await _requestWithFallback(
      '/auth.php?action=login',
      method: 'POST',
      data: {'username': username, 'password': password},
    );
  }

  // APIs
  Future<Map<String, dynamic>?> getEntries({String? search, String? router, int page = 1, bool forceRefresh = false}) async => getDashboardData(action: 'entries', search: search, router: router, page: page, limit: 12, forceRefresh: forceRefresh);
  Future<Map<String, dynamic>?> getIncome({String? router, String? startDate, String? endDate, bool forceRefresh = false}) async => getDashboardData(action: 'income', router: router, startDate: startDate, endDate: endDate, forceRefresh: forceRefresh);
  Future<Map<String, dynamic>?> getVouchers({String? search, String? router, int page = 1, bool forceRefresh = false}) async => getDashboardData(action: 'vouchers', search: search, router: router, page: page, limit: 15, forceRefresh: forceRefresh);
  Future<Map<String, dynamic>?> getCustomers({String? search, int page = 1, bool forceRefresh = false}) async => getDashboardData(action: 'customers', search: search, page: page, limit: 12, forceRefresh: forceRefresh);
  Future<Map<String, dynamic>?> getPlans(String routerId, {bool forceRefresh = false}) async => getDashboardData(action: 'plans', router: routerId, forceRefresh: forceRefresh);
  Future<Map<String, dynamic>?> getRouters({bool forceRefresh = false}) async => getDashboardData(action: 'routers', forceRefresh: forceRefresh);
  Future<Map<String, dynamic>?> getLogs({String? search, int page = 1, bool forceRefresh = false}) async => getDashboardData(action: 'logs', search: search, page: page, limit: 20, forceRefresh: forceRefresh);
}
