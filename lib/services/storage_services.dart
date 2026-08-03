import 'package:shared_preferences/shared_preferences.dart';
import 'package:photobox_pro/config/app_config.dart';

class StorageService {
  String _key(String name) => '${AppConfig.boxId}_$name';

  Future<void> saveSettings(
      {required bool isMirror,
      required String iso,
      required String aperture}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key('setting_mirror'), isMirror);
    await prefs.setString(_key('setting_iso'), iso);
    await prefs.setString(_key('setting_aperture'), aperture);
  }

  Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'setting_mirror': prefs.getBool(_key('setting_mirror')) ?? false,
      'setting_iso': prefs.getString(_key('setting_iso')) ?? 'Auto',
      'setting_aperture':
          prefs.getString(_key('setting_aperture')) ?? 'f/2.8',
    };
  }
}
