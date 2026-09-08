import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Helper utilitas untuk memastikan request jaringan tidak menggantung tanpa batas
/// saat sinyal internet lemah atau terputus-putus.
class NetworkResilience {
  /// Default timeout untuk request query Supabase agar tidak membuat UI loading selamanya
  static const Duration defaultQueryTimeout = Duration(seconds: 8);

  /// Default timeout untuk request write/mutasi (insert, update, delete)
  static const Duration defaultMutationTimeout = Duration(seconds: 12);

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
      final isNetworkIssue = e is TimeoutException ||
          e is SocketException ||
          e.toString().toLowerCase().contains('socketexception') ||
          e.toString().toLowerCase().contains('failed to connect') ||
          e.toString().toLowerCase().contains('connection refused') ||
          e.toString().toLowerCase().contains('network is unreachable') ||
          e.toString().toLowerCase().contains('clientexception');

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
