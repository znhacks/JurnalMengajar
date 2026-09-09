import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service untuk menyimpan dan membaca cache lokal persisten (SharedPreferences)
/// dengan in-memory cache untuk rendering instan (0ms) pada sinyal lemah/offline.
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, dynamic> _memoryCache = {};
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
    } catch (e) {
      debugPrint('[CacheService] Error initializing SharedPreferences: $e');
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
    }
    return _prefs!;
  }

  /// Simpan data JSON ke cache
  Future<void> save(String key, dynamic data) async {
    try {
      _memoryCache[key] = data;
      final prefs = await _getPrefs();
      final encoded = jsonEncode({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      });
      await prefs.setString('cache_$key', encoded);
    } catch (e) {
      debugPrint('[CacheService] Error saving cache for key "$key": $e');
    }
  }

  /// Baca List JSON dari memory cache atau disk cache
  Future<List<Map<String, dynamic>>?> loadList(String key) async {
    try {
      // 1. Cek memory cache terlebih dahulu (0ms)
      if (_memoryCache.containsKey(key) && _memoryCache[key] is List) {
        final list = _memoryCache[key] as List;
        return list.map((item) {
          if (item is Map<String, dynamic>) return item;
          if (item is Map) return Map<String, dynamic>.from(item);
          return <String, dynamic>{};
        }).toList();
      }

      // 2. Baca dari SharedPreferences
      final prefs = await _getPrefs();
      final raw = prefs.getString('cache_$key');
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded.containsKey('data') && decoded['data'] is List) {
        final list = decoded['data'] as List;
        final parsed = list.map((item) {
          if (item is Map<String, dynamic>) return item;
          if (item is Map) return Map<String, dynamic>.from(item);
          return <String, dynamic>{};
        }).toList();
        _memoryCache[key] = parsed;
        return parsed;
      }
    } catch (e) {
      debugPrint('[CacheService] Error loading list cache for key "$key": $e');
    }
    return null;
  }

  /// Baca Map JSON dari memory cache atau disk cache
  Future<Map<String, dynamic>?> loadMap(String key) async {
    try {
      if (_memoryCache.containsKey(key) && _memoryCache[key] is Map) {
        final map = _memoryCache[key] as Map;
        return Map<String, dynamic>.from(map);
      }

      final prefs = await _getPrefs();
      final raw = prefs.getString('cache_$key');
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded.containsKey('data') && decoded['data'] is Map) {
        final map = Map<String, dynamic>.from(decoded['data'] as Map);
        _memoryCache[key] = map;
        return map;
      }
    } catch (e) {
      debugPrint('[CacheService] Error loading map cache for key "$key": $e');
    }
    return null;
  }

  /// Hapus cache tertentu
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    try {
      final prefs = await _getPrefs();
      await prefs.remove('cache_$key');
    } catch (_) {}
  }

  /// Hapus seluruh cache yang diawali prefix tertentu
  Future<void> purgePrefix(String prefix) async {
    try {
      _memoryCache.removeWhere((k, _) => k.startsWith(prefix));
      final prefs = await _getPrefs();
      final keys = prefs.getKeys().where((k) => k.startsWith('cache_$prefix') || k.startsWith(prefix));
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  /// Hapus seluruh cache yang berkaitan dengan sekolah tertentu
  Future<void> clearSchoolCache(String schoolId) async {
    try {
      _memoryCache.removeWhere((k, _) => k.contains(schoolId));
      final prefs = await _getPrefs();
      final keys = prefs.getKeys().where((k) => k.startsWith('cache_') && k.contains(schoolId));
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
