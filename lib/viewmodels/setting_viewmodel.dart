import 'package:flutter/material.dart';
import 'package:photobox_pro/services/socket_services.dart';
import 'package:photobox_pro/services/storage_services.dart';

class SettingsViewModel extends ChangeNotifier {
  final SocketService _socketService;
  final StorageService _storageService;

  bool isMirror = false;
  String selectedAperture = 'f/2.8';
  String selectedIso = 'Auto';
  bool isLoading = true;

  SettingsViewModel(this._socketService, this._storageService) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    isLoading = true;
    notifyListeners();
    final settings = await _storageService.loadSettings();
    isMirror = settings['setting_mirror'];
    selectedIso = settings['setting_iso'];
    selectedAperture = settings['setting_aperture'];
    isLoading = false;
    notifyListeners();
  }

  Future<void> saveSettings() async {
    await _storageService.saveSettings(
        isMirror: isMirror, iso: selectedIso, aperture: selectedAperture);
    _socketService.emit('set-mirror', isMirror);
    _socketService.emit('set-iso', selectedIso);
    _socketService.emit('set-aperture', selectedAperture);
  }

  void setMirror(bool value) {
    isMirror = value;
    notifyListeners();
  }

  void setIso(String value) {
    selectedIso = value;
    notifyListeners();
  }

  void setAperture(String value) {
    selectedAperture = value;
    notifyListeners();
  }

  void triggerAutoFocus() => _socketService.emit('auto-focus');
}
