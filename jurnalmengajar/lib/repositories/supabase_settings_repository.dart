import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/settings_model.dart';
import 'settings_repository.dart';

class SupabaseSettingsRepository implements SettingsRepository {
  final SupabaseClient _supabase;
  static const String _settingsId = 'default';

  SupabaseSettingsRepository(this._supabase);

  @override
  Future<SettingsModel> getSettings() async {
    try {
      final response = await _supabase
          .from('settings')
          .select()
          .eq('id', _settingsId)
          .single();

      return SettingsModel.fromJson(response);
    } catch (e) {
      // Return default settings if not found
      return SettingsModel(id: _settingsId, maxJournalInputDays: 3);
    }
  }

  @override
  Future<void> saveSettings(SettingsModel settings) async {
    try {
      // Try to update first
      await _supabase
          .from('settings')
          .update(settings.toJson())
          .eq('id', settings.id);
    } catch (e) {
      // If update fails, insert new record
      try {
        await _supabase.from('settings').insert(settings.toJson());
      } catch (insertError) {
        throw Exception('Gagal menyimpan pengaturan: $insertError');
      }
    }
  }
}
