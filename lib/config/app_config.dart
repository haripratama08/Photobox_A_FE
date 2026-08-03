import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get boxId => dotenv.env['BOX_ID'] ?? 'box-a';
  static String get boxTitle => dotenv.env['BOX_TITLE'] ?? 'Photobox A';
  static String get socketBaseUrl =>
      dotenv.env['SOCKET_BASE_URL'] ?? 'http://127.0.0.1:3000';
  static String get welcomeAsset =>
      dotenv.env['WELCOME_ASSET'] ?? 'assets/box_a/IMG_5576.PNG';

  static double get windowX =>
      double.tryParse(dotenv.env['WINDOW_X'] ?? '') ?? 0;
  static double get windowY =>
      double.tryParse(dotenv.env['WINDOW_Y'] ?? '') ?? 0;
  static double get windowWidth =>
      double.tryParse(dotenv.env['WINDOW_WIDTH'] ?? '') ?? 1920;
  static double get windowHeight =>
      double.tryParse(dotenv.env['WINDOW_HEIGHT'] ?? '') ?? 1080;
  static bool get fullScreen =>
      (dotenv.env['WINDOW_FULLSCREEN'] ?? 'true').toLowerCase() == 'true';

  static Color get primaryColor {
    final raw = (dotenv.env['PRIMARY_COLOR'] ?? 'E85D04')
        .replaceAll('#', '')
        .replaceAll('0x', '');
    final normalized = raw.length == 6 ? 'FF$raw' : raw;
    return Color(int.tryParse(normalized, radix: 16) ?? 0xFFE85D04);
  }
}
