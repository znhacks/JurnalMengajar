import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'web_connectivity.dart';

/// Service pendeteksi koneksi internet global (lintas platform Web, Android, iOS, Desktop)
/// tanpa ketergantungan plugin native eksternal.
class ConnectivityService with ChangeNotifier {
  static final ConnectivityService instance = ConnectivityService._internal();
  factory ConnectivityService() => instance;

  ConnectivityService._internal() {
    _startPeriodicCheck();
  }

  bool _isOffline = false;
  bool _justReconnected = false;
  bool _isChecking = false;
  Timer? _periodicTimer;
  Timer? _reconnectedResetTimer;

  bool get isOffline => _isOffline;
  bool get isOnline => !_isOffline;
  bool get justReconnected => _justReconnected;

  void _startPeriodicCheck() {
    if (kIsWeb) {
      initWebOnlineListeners((online) {
        _updateState(!online);
      });
    }

    // Cek awal setelah aplikasi mulai
    checkConnectivity();

    // Cek berkala setiap 8 detik
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      checkConnectivity();
    });
  }

  /// Pengecekan aktif koneksi internet
  Future<bool> checkConnectivity() async {
    if (_isChecking) return !_isOffline;
    _isChecking = true;

    bool online = false;
    try {
      if (kIsWeb) {
        // Pada Web:
        // 1. Cek status perangkat di browser (navigator.onLine)
        if (!isWebBrowserOnline) {
          online = false;
        } else {
          // 2. Ping same-origin asset (manifest.json) untuk menghindari error CORS
          try {
            final uri = Uri.base.resolve('manifest.json?_t=${DateTime.now().millisecondsSinceEpoch}');
            final response = await http
                .get(uri, headers: {'Cache-Control': 'no-cache'})
                .timeout(const Duration(seconds: 3));
            online = response.statusCode >= 200 && response.statusCode < 400;
          } catch (_) {
            // Jika ping lokal gagal/terkendala di testing, percaya pada status browser online
            online = isWebBrowserOnline;
          }
        }
      } else {
        // Pada Native (Mobile & Desktop): Lookup DNS cepat dengan fallback multi-host
        try {
          final result = await InternetAddress.lookup('google.com')
              .timeout(const Duration(seconds: 3));
          online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        } catch (_) {
          try {
            final fallbackResult = await InternetAddress.lookup('cloudflare.com')
                .timeout(const Duration(seconds: 3));
            online = fallbackResult.isNotEmpty && fallbackResult[0].rawAddress.isNotEmpty;
          } catch (_) {
            online = false;
          }
        }
      }
    } catch (_) {
      online = false;
    } finally {
      _isChecking = false;
    }

    _updateState(!online);
    return online;
  }

  /// Dipanggil langsung oleh [NetworkResilience] saat ada request jaringan yang gagal
  void reportOffline() {
    _updateState(true);
  }

  /// Dipanggil saat request jaringan berhasil
  void reportOnline() {
    _updateState(false);
  }

  void _updateState(bool isOfflineNow) {
    if (_isOffline == isOfflineNow) return;

    final wasOfflineBefore = _isOffline;
    _isOffline = isOfflineNow;

    if (wasOfflineBefore && !_isOffline) {
      // Baru saja pulih dari offline
      _justReconnected = true;
      _reconnectedResetTimer?.cancel();
      _reconnectedResetTimer = Timer(const Duration(seconds: 3), () {
        _justReconnected = false;
        notifyListeners();
      });
    }

    notifyListeners();
  }

  /// Membatalkan timer background (berguna saat test teardown)
  void cancelTimersForTest() {
    _periodicTimer?.cancel();
    _reconnectedResetTimer?.cancel();
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _reconnectedResetTimer?.cancel();
    super.dispose();
  }
}
