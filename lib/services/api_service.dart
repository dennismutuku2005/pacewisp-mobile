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

  String get baseUrl {
    if (_subdomain != null) {
      return 'https://$_subdomain.$_domain/pace-apis/dashboard/v1';
    }
    return 'https://localhost/pace.com/pace-apis/dashboard/v1';
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
    final subdomain = _subdomain ?? 'default';

    final cacheKey = "${action}_${router ?? 'all'}_${search ?? ''}_${startDate ?? 'na'}_${endDate ?? 'na'}_${page ?? 1}";

    if (!forceRefresh) {
      final cached = await _cache.get(cacheKey, subdomain: subdomain, expiry: const Duration(minutes: 5));
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

    try {
      final response = await _dio.get(
        '$baseUrl/dashboard.php',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['status'] == 'success') {
          await _cache.save(cacheKey, data, subdomain: subdomain);
        }
        return data;
      }
    } catch (e) {
      print('API Error (Dashboard): $e');
      return await _cache.get(cacheKey, subdomain: subdomain);
    }
    return null;
  }

  Future<bool> pingInstance() async {
    try {
      final response = await _dio.get('$baseUrl/auth.php?action=ping').timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '$baseUrl/auth.php?action=login',
        data: {'username': username, 'password': password},
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      print('API Error (Login): $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getEntries({String? search, String? router, int page = 1, bool forceRefresh = false}) async {
    return getDashboardData(
      action: 'entries',
      search: search,
      router: router,
      page: page,
      limit: 12,
      forceRefresh: forceRefresh,
    );
  }

  Future<Map<String, dynamic>?> getIncome({String? router, String? startDate, String? endDate, bool forceRefresh = false}) async {
    return getDashboardData(
      action: 'income',
      router: router,
      startDate: startDate,
      endDate: endDate,
      forceRefresh: forceRefresh,
    );
  }

  Future<Map<String, dynamic>?> getVouchers({String? search, String? router, int page = 1, bool forceRefresh = false}) async {
    return getDashboardData(
      action: 'vouchers',
      search: search,
      router: router,
      page: page,
      limit: 15,
      forceRefresh: forceRefresh,
    );
  }

  Future<Map<String, dynamic>?> getCustomers({String? search, int page = 1, bool forceRefresh = false}) async {
    return getDashboardData(
      action: 'customers',
      search: search,
      page: page,
      limit: 12,
      forceRefresh: forceRefresh,
    );
  }

  Future<Map<String, dynamic>?> getPlans(String routerId, {bool forceRefresh = false}) async {
    return getDashboardData(
      action: 'plans',
      router: routerId,
      forceRefresh: forceRefresh,
    );
  }

  Future<Map<String, dynamic>?> getRouters({bool forceRefresh = false}) async {
    return getDashboardData(
      action: 'routers',
      forceRefresh: forceRefresh,
    );
  }

  Future<Map<String, dynamic>?> getLogs({String? search, int page = 1, bool forceRefresh = false}) async {
    return getDashboardData(
      action: 'logs',
      search: search,
      page: page,
      limit: 20,
      forceRefresh: forceRefresh,
    );
  }
}
