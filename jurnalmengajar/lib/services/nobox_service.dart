import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nobox_config_model.dart';

class NoboxService {
  final SupabaseClient? _client;

  NoboxService([SupabaseClient? client]) : _client = client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  /// Fetch school NoBox configuration status without exposing raw secrets
  Future<NoboxConfigModel> getSchoolNoboxStatus(String schoolId) async {
    try {
      final response = await _supabase.rpc(
        'get_school_nobox_status',
        params: {'p_school_id': schoolId},
      );

      if (response is Map<String, dynamic>) {
        return NoboxConfigModel.fromJson(schoolId, response);
      } else if (response is Map) {
        return NoboxConfigModel.fromJson(schoolId, Map<String, dynamic>.from(response));
      }

      return NoboxConfigModel(schoolId: schoolId);
    } catch (e) {
      if (kDebugMode) {
        // Do not print sensitive tokens in error logs
        print('Error fetching NoBox status for school: $e');
      }
      return NoboxConfigModel(
        schoolId: schoolId,
        connectionStatus: 'untested',
        lastErrorMessage: 'Gagal memuat status NoBox: $e',
      );
    }
  }

  /// Securely save or update the school's NoBox API Key
  Future<bool> saveSchoolApiKey({
    required String schoolId,
    required String apiKey,
    String channelId = '1',
    String accountId = '',
  }) async {
    final trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) {
      throw Exception('API Key NoBox.ai tidak boleh kosong.');
    }

    try {
      final response = await _supabase.rpc(
        'save_school_nobox_config',
        params: {
          'p_school_id': schoolId,
          'p_api_key': trimmedKey,
          'p_channel_id': channelId,
          'p_account_id': accountId,
        },
      );

      if (response is Map && response['success'] == true) {
        return true;
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving NoBox API key: $e');
      }
      throw Exception('Gagal menyimpan API Key: $e');
    }
  }

  /// Test connection via Supabase Edge Function
  Future<Map<String, dynamic>> testConnection(String schoolId) async {
    try {
      final res = await _supabase.functions.invoke(
        'send-nobox-wa-notification',
        body: {
          'action': 'test_connection',
          'school_id': schoolId,
        },
      );

      final data = res.data;
      if (data is Map) {
        final isSuccess = data['success'] == true;
        final message = data['message']?.toString() ??
            (isSuccess ? 'Koneksi NoBox.ai berhasil!' : 'Koneksi gagal.');
        return {
          'success': isSuccess,
          'message': message,
        };
      }

      final isSuccess = res.status == 200 || res.status == 201;
      return {
        'success': isSuccess,
        'message': isSuccess ? 'Koneksi NoBox.ai berhasil diverifikasi!' : 'Koneksi gagal (Status ${res.status}).',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error testing NoBox connection: $e');
      }
      return {
        'success': false,
        'message': 'Gagal melakukan tes koneksi: $e',
      };
    }
  }
}
