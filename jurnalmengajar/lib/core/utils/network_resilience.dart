import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Helper utilitas untuk memastikan request jaringan tidak menggantung tanpa batas
/// saat sinyal internet lemah atau terputus-putus.
class NetworkResilience {
  /// Default timeout untuk request query Supabase agar tidak membuat UI loading selamanya (5 detik untuk responsivitas tinggi pada sinyal lemah)
  static const Duration defaultQueryTimeout = Duration(seconds: 5);

  /// Default timeout untuk request write/mutasi (insert, update, delete)
  static const Duration defaultMutationTimeout = Duration(seconds: 10);

  /// Eksekusi [networkTask] dengan batasan [timeout].
  /// Jika terjadi Timeout atau SocketException (sinyal sangat lemah/hilang),
  /// panggil [fallback] jika tersedia alih-alih melempar exception yang merusak UI.
  static Future<T> execute<T>({
    required Future<T> Function() networkTask,
    FutureOr<T> Function()? fallback,
    Duration timeout = defaultQueryTimeout,
    String operationName = 'NetworkOperation',
  }) async {
    try {
      return await networkTask().timeout(
        timeout,
        onTimeout: () {
          debugPrint('[NetworkResilience] TIMEOUT ($timeout) reached for $operationName (Weak Internet Signal)');
          throw TimeoutException('Koneksi internet sangat lambat atau tidak stabil.', timeout);
        },
      );
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      final isNetworkIssue = e is TimeoutException ||
          e is SocketException ||
          errStr.contains('socketexception') ||
          errStr.contains('failed to connect') ||
          errStr.contains('connection refused') ||
          errStr.contains('network is unreachable') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup') ||
          errStr.contains('handshake') ||
          errStr.contains('connection reset') ||
          errStr.contains('connection closed') ||
          errStr.contains('timeoutexception') ||
          errStr.contains('timed out') ||
          errStr.contains('koneksi internet sangat lambat');

      if (isNetworkIssue) {
        debugPrint('[NetworkResilience] Weak internet / offline detected in $operationName: $e');
        if (fallback != null) {
          debugPrint('[NetworkResilience] Using local cached fallback for $operationName');
          try {
            return await fallback();
          } catch (fallbackError) {
            debugPrint('[NetworkResilience] Fallback also encountered error: $fallbackError');
          }
        }
      }

      // Jika bukan issue jaringan atau fallback tidak tersedia, teruskan exception
      rethrow;
    }
  }
}
