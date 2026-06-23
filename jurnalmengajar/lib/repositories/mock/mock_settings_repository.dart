import '../settings_repository.dart';
import '../../models/settings_model.dart';
import 'mock_database.dart';

class MockSettingsRepository implements SettingsRepository {
  final MockDatabase _db = MockDatabase();

  @override
  Future<SettingsModel> getSettings() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _db.settings;
  }

  @override
  Future<void> saveSettings(SettingsModel settings) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _db.settings = settings;
  }
}
