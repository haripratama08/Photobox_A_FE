import 'dart:io' show Directory, File, Platform, Process, ProcessException;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:photobox_pro/services/socket_services.dart';
import 'package:photobox_pro/services/storage_services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:photobox_pro/views/welcome_screen.dart';
import 'package:photobox_pro/config/app_config.dart';

void main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final configArgument = arguments.firstWhere(
    (argument) => argument.startsWith('--config='),
    orElse: () => '--config=.env',
  );
  final configFile = configArgument.substring('--config='.length);
  await dotenv.load(fileName: configFile);

  // Aktifkan dan petakan touchscreen X11 sebelum jendela Flutter dibuat.
  // Skrip ikut disalin ke bundle Linux, tetapi fallback ke folder proyek tetap
  // tersedia untuk `flutter run`.
  await _configureLinuxTouchscreen();

  // GTK fullscreen dapat mengubah monitor/bounds setelah Flutter membuat
  // surface. Pada kiosk Linux multi-monitor hal tersebut membuat koordinat
  // touch tidak lagi sama dengan koordinat widget. Window tanpa bingkai dengan
  // bounds sebesar monitor terlihat fullscreen, tetapi mempertahankan sistem
  // koordinat input yang stabil.
  final useNativeFullScreen = AppConfig.fullScreen && !Platform.isLinux;
  final windowBounds = Rect.fromLTWH(
    AppConfig.windowX,
    AppConfig.windowY,
    AppConfig.windowWidth,
    AppConfig.windowHeight,
  );

  final windowOptions = WindowOptions(
    size: Size(AppConfig.windowWidth, AppConfig.windowHeight),
    center: false,
    backgroundColor: const Color(0xFF1C0800),
    skipTaskbar: false,
    title: AppConfig.boxTitle,
    titleBarStyle: TitleBarStyle.hidden,
    fullScreen: false,
    alwaysOnTop: true,
  );

  await windowManager.waitUntilReadyToShow(windowOptions);
  await windowManager.setBounds(windowBounds);
  // window_manager tidak mengimplementasikan setIgnoreMouseEvents di Linux.
  // Secara default window GTK tetap menerima event mouse/touch, sehingga
  // pemanggilan ini hanya diperlukan pada platform yang mendukungnya.
  if (!Platform.isLinux) {
    await windowManager.setIgnoreMouseEvents(false);
  }

  // Tentukan monitor dari bounds lebih dahulu, baru aktifkan fullscreen native.
  // Urutan ini juga mencegah fullscreen berpindah ke monitor utama.
  if (useNativeFullScreen) {
    await windowManager.setFullScreen(true);
  }

  // Init Services
  final socketService = SocketService();
  socketService.initSocket();
  final storageService = StorageService();

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    MultiProvider(
      providers: [
        Provider<SocketService>.value(value: socketService),
        Provider<StorageService>.value(value: storageService),
      ],
      child: const PhotoboxProApp(),
    ),
  );
}

Future<void> _configureLinuxTouchscreen() async {
  if (!Platform.isLinux ||
      (Platform.environment['XDG_SESSION_TYPE'] ?? 'x11') != 'x11') {
    return;
  }

  final executableDirectory = File(Platform.resolvedExecutable).parent.path;
  final candidates = <String>[
    '$executableDirectory/configure_touchscreen.sh',
    '${Directory.current.path}/scripts/configure_touchscreen.sh',
  ];

  String? scriptPath;
  for (final candidate in candidates) {
    if (await File(candidate).exists()) {
      scriptPath = candidate;
      break;
    }
  }

  if (scriptPath == null) {
    debugPrint('[TOUCH] Skrip konfigurasi touchscreen tidak ditemukan.');
    return;
  }

  final environment = Map<String, String>.of(Platform.environment);
  for (final key in const ['TOUCH_OUTPUT', 'TOUCH_DEVICE', 'TOUCH_MATRIX']) {
    final value = dotenv.env[key];
    if (value != null && value.isNotEmpty) {
      environment[key] = value;
    }
  }

  try {
    final result = await Process.run(
      'bash',
      [scriptPath],
      environment: environment,
    );
    final output = result.stdout.toString().trim();
    final error = result.stderr.toString().trim();
    if (output.isNotEmpty) {
      debugPrint(output);
    }
    if (error.isNotEmpty) {
      debugPrint(error);
    }
  } on ProcessException catch (error) {
    // Kegagalan xinput tidak boleh mencegah aplikasi dibuka, misalnya ketika
    // dijalankan dari sesi Wayland atau mesin tanpa paket xinput.
    debugPrint('[TOUCH] Konfigurasi touchscreen gagal: $error');
  }
}

class PhotoboxProApp extends StatelessWidget {
  const PhotoboxProApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photobox Pro',
      scrollBehavior: const PhotoboxScrollBehavior(),
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1C0800),
        primaryColor: AppConfig.primaryColor,
        colorScheme: ColorScheme.dark(
          primary: AppConfig.primaryColor,
          secondary: const Color(0xFFFFC800),
          surface: const Color(0xFF321005),
        ),
      ),
      home: const WelcomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Mengizinkan swipe/drag pada kiosk baik touchscreen terdeteksi sebagai
/// touch, stylus, maupun emulasi mouse oleh driver Linux.
class PhotoboxScrollBehavior extends MaterialScrollBehavior {
  const PhotoboxScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.mouse,
      };
}
