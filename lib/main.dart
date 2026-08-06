import 'dart:ui';
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

  final windowOptions = WindowOptions(
    size: Size(AppConfig.windowWidth, AppConfig.windowHeight),
    center: false,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    title: AppConfig.boxTitle,
    titleBarStyle: TitleBarStyle.hidden,
    fullScreen: false,
    alwaysOnTop: true,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setPosition(
      Offset(AppConfig.windowX, AppConfig.windowY),
    );
    await windowManager.show();
    if (AppConfig.fullScreen) {
      await windowManager.setFullScreen(true);
    }
    await windowManager.focus();
  });

  // Init Services
  final socketService = SocketService();
  socketService.initSocket();
  final storageService = StorageService();

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

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}

class PhotoboxProApp extends StatelessWidget {
  const PhotoboxProApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photobox Pro',
      scrollBehavior: AppScrollBehavior(),
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        primaryColor: AppConfig.primaryColor,
        colorScheme: ColorScheme.dark(
          primary: AppConfig.primaryColor,
        ),
      ),
      home: const WelcomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
