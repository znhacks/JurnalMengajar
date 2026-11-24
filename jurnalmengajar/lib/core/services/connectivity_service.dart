import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'web_connectivity.dart';

/// Service pendeteksi koneksi internet global (lintas platform Web, Android, iOS, Desktop)
/// tanpa ketergantungan plugin native eksternal.
class ConnectivityService with ChangeNotifier, WidgetsBindingObserver {
  static final ConnectivityService instance = ConnectivityService._internal();
  factory ConnectivityService() => instance;

  ConnectivityService._internal() {
    WidgetsBinding.instance.addObserver(this);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkConnectivity();
    }
  }

  void _startPeriodicCheck() {
    if (kIsWeb) {
      initWebOnlineListeners((online) {
        _updateState(!online);
      });
    }

    // Cek awal setelah aplikasi mulai
    checkConnectivity();

    _scheduleNextCheck();
  }

  void _scheduleNextCheck() {
    _periodicTimer?.cancel();
    final interval = _isOffline
        ? const Duration(seconds: 3)
        : const Duration(seconds: 12);
    _periodicTimer = Timer.periodic(interval, (_) {
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

    _scheduleNextCheck();

    if (wasOfflineBefore && !_isOffline) {
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
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    _reconnectedResetTimer?.cancel();
    super.dispose();
  }
}
