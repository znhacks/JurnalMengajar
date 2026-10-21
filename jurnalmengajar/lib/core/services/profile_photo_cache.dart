import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Cache lokal foto profil agar avatar bisa tampil seketika saat aplikasi
/// dibuka kembali, tanpa harus menunggu unduhan dari jaringan.
class ProfilePhotoCache {
  ProfilePhotoCache._();

  static final ProfilePhotoCache _instance = ProfilePhotoCache._();

  factory ProfilePhotoCache() => _instance;

  static const String _keyPrefix = 'profile_photo_';
  static const int _maxStoredBytes = 2 * 1024 * 1024;
  static const Duration _fetchTimeout = Duration(seconds: 15);

  final Map<String, Uint8List> _memoryCache = {};
  final Map<String, Future<Uint8List?>> _inFlight = {};

  String _key(String userId, String photoUrl) =>
      '$_keyPrefix${userId}_${base64Url.encode(utf8.encode(photoUrl))}';

  /// Bytes yang sudah siap dipakai pada frame berikutnya, atau null.
  Uint8List? cached(String userId, String photoUrl) =>
      _memoryCache[_key(userId, photoUrl)];

  @visibleForTesting
  void resetForTesting() {
    _memoryCache.clear();
    _inFlight.clear();
  }

  /// Muat foto dari penyimpanan lokal ke memori.
  Future<void> loadFromStorage(String userId, String photoUrl) async {
    final key = _key(userId, photoUrl);
    if (_memoryCache.containsKey(key)) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return;
      _memoryCache[key] = base64Decode(raw);
    } catch (_) {
      // Cache lokal bersifat opsional; jangan ganggu alur utama.
    }
  }

  /// Ambil foto dari cache memori, lalu unduh dari jaringan bila belum ada.
  /// Permintaan untuk URL yang sama digabung agar tidak mengunduh berulang.
  Future<Uint8List?> fetch(String userId, String photoUrl) {
    final key = _key(userId, photoUrl);
    final cachedBytes = _memoryCache[key];
    if (cachedBytes != null) return Future.value(cachedBytes);

    return _inFlight.putIfAbsent(key, () async {
      try {
        final response = await http
            .get(Uri.parse(photoUrl))
            .timeout(_fetchTimeout);
        final contentType = response.headers['content-type'] ?? '';
        if (response.statusCode != 200 ||
            response.bodyBytes.isEmpty ||
            !contentType.startsWith('image/')) {
          return null;
        }

        final bytes = response.bodyBytes;
        _memoryCache[key] = bytes;
        unawaited(_persist(userId, key, bytes));
        return bytes;
      } catch (_) {
        return null;
      } finally {
        _inFlight.remove(key);
      }
    });
  }

  /// Mulai memuat foto lebih awal, misalnya sesudah data user tersedia.
  Future<void> preload(String userId, String? photoUrl) async {
    if (photoUrl == null || !photoUrl.startsWith('http')) return;
    await loadFromStorage(userId, photoUrl);
    if (cached(userId, photoUrl) == null) {
      await fetch(userId, photoUrl);
    }
  }

  Future<void> _persist(String userId, String key, Uint8List bytes) async {
    if (bytes.lengthInBytes > _maxStoredBytes) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userPrefix = '$_keyPrefix${userId}_';
      final staleKeys = prefs
          .getKeys()
          .where(
            (existingKey) =>
                existingKey.startsWith(userPrefix) && existingKey != key,
          )
          .toList();

      for (final staleKey in staleKeys) {
        await prefs.remove(staleKey);
      }
      await prefs.setString(key, base64Encode(bytes));

      _memoryCache.removeWhere(
        (existingKey, _) =>
            existingKey.startsWith(userPrefix) && existingKey != key,
      );
    } catch (_) {
      // Gagal menyimpan cache tidak boleh menggagalkan tampilan avatar.
    }
  }
}
