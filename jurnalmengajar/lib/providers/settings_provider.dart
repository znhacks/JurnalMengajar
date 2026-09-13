import 'package:flutter/material.dart';
import '../models/settings_model.dart';
import '../models/nobox_config_model.dart';
import '../repositories/settings_repository.dart';
import '../services/nobox_service.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsRepository settingsRepository;
  final NoboxService _noboxService;

  SettingsModel? _settings;
  bool _isLoading = false;
  String? _errorMessage;

  // NoBox AI multi-tenant states
  NoboxConfigModel? _noboxConfig;
  bool _isNoboxLoading = false;
  bool _isTestingNobox = false;
  String? _noboxErrorMessage;

  SettingsProvider({
    required this.settingsRepository,
    NoboxService? noboxService,
  }) : _noboxService = noboxService ?? NoboxService() {
    loadSettings();
  }

  SettingsModel? get settings => _settings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  NoboxConfigModel? get noboxConfig => _noboxConfig;
  bool get isNoboxLoading => _isNoboxLoading;
  bool get isTestingNobox => _isTestingNobox;
  String? get noboxErrorMessage => _noboxErrorMessage;

  Future<void> loadSettings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _settings = await settingsRepository.getSettings();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveSettings(SettingsModel settings) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await settingsRepository.saveSettings(settings);
      _settings = settings;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load NoBox configuration status for the specific active school
  Future<void> loadNoboxConfig(String schoolId) async {
    if (schoolId.isEmpty) return;
    _isNoboxLoading = true;
    _noboxErrorMessage = null;
    notifyListeners();

    try {
      _noboxConfig = await _noboxService.getSchoolNoboxStatus(schoolId);
    } catch (e) {
      _noboxErrorMessage = e.toString();
    } finally {
      _isNoboxLoading = false;
      notifyListeners();
    }
  }

  /// Save school NoBox API Key securely
  Future<bool> saveNoboxApiKey({
    required String schoolId,
    required String apiKey,
    String channelId = '1',
    String accountId = '',
  }) async {
    if (schoolId.isEmpty) {
      _noboxErrorMessage = 'ID Sekolah tidak valid.';
      notifyListeners();
      return false;
    }

    _isNoboxLoading = true;
    _noboxErrorMessage = null;
    notifyListeners();

    try {
      final success = await _noboxService.saveSchoolApiKey(
        schoolId: schoolId,
        apiKey: apiKey,
        channelId: channelId,
        accountId: accountId,
      );

      if (success) {
        // Refresh masked status for this school
        _noboxConfig = await _noboxService.getSchoolNoboxStatus(schoolId);
      }
      return success;
    } catch (e) {
      _noboxErrorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isNoboxLoading = false;
      notifyListeners();
    }
  }

  /// Test connection via Edge Function
  Future<Map<String, dynamic>> testNoboxConnection(String schoolId) async {
    if (schoolId.isEmpty) {
      return {'success': false, 'message': 'ID Sekolah tidak valid.'};
    }

    _isTestingNobox = true;
    _noboxErrorMessage = null;
    notifyListeners();

    try {
      final result = await _noboxService.testConnection(schoolId);
      // Refresh status after test to capture 'connected' or 'failed' state
      _noboxConfig = await _noboxService.getSchoolNoboxStatus(schoolId);
      return result;
    } catch (e) {
      final msg = 'Gagal tes koneksi: $e';
      _noboxErrorMessage = msg;
      return {'success': false, 'message': msg};
    } finally {
      _isTestingNobox = false;
      notifyListeners();
    }
  }
}
