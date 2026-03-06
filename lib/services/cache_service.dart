import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  String _getKey(String key, String? subdomain) {
    if (subdomain == null) return 'pace_cache_$key';
    return 'pace_cache_${subdomain}_$key';
  }

  Future<void> save(String key, dynamic data, {String? subdomain}) async {
    final prefs = await SharedPreferences.getInstance();
    final wrapper = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    };
    await prefs.setString(_getKey(key, subdomain), jsonEncode(wrapper));
  }

  Future<dynamic> get(String key, {String? subdomain, Duration? expiry}) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_getKey(key, subdomain));
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached);
        final timestamp = decoded['timestamp'] as int;
        final data = decoded['data'];
        
        if (expiry != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - timestamp > expiry.inMilliseconds) {
            await delete(key, subdomain: subdomain);
            return null;
          }
        }
        return data;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> delete(String key, {String? subdomain}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getKey(key, subdomain));
  }

  Future<void> clearAll(String subdomain) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('pace_cache_${subdomain}_')) {
        await prefs.remove(key);
      }
    }
  }
}
