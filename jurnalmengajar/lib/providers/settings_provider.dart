import 'package:flutter/material.dart';
import '../models/settings_model.dart';
import '../repositories/settings_repository.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsRepository settingsRepository;

  SettingsModel? _settings;
  bool _isLoading = false;
  String? _errorMessage;

  SettingsProvider({required this.settingsRepository}) {
    loadSettings();
  }

  SettingsModel? get settings => _settings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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
}
