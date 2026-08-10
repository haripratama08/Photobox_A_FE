import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:photobox_pro/config/app_config.dart';
import 'package:photobox_pro/services/socket_services.dart';
import 'package:photobox_pro/services/storage_services.dart';
import 'package:photobox_pro/views/welcome_screen.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

void main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[APP] Linux touch diagnostic v2 aktif');
  GestureBinding.instance.pointerRouter.addGlobalRoute(_logPointerEvent);

  final configArgument = arguments.firstWhere(
    (argument) => argument.startsWith('--config='),
    orElse: () => '--config=.env',
  );
  final configFile = configArgument.substring('--config='.length);
  await dotenv.load(fileName: configFile);

  // Di Linux, runner GTK menyiapkan jendela sebelum FlView/GLX dibuat.
  // Mengubah bounds/fullscreen melalui plugin setelah surface aktif dapat
  // memicu GLX BadAccess pada mesin kiosk yang sedang diakses lewat AnyDesk.
  if (!Platform.isLinux) {
    await windowManager.ensureInitialized();
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
  }

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

DateTime _lastTouchMoveLog = DateTime.fromMillisecondsSinceEpoch(0);
Timer? _linuxTouchReleaseTimer;
bool _linuxTouchBridgeActive = false;
Offset _linuxTouchBridgePosition = Offset.zero;
int _linuxTouchBridgePointer = 900000;

void _logPointerEvent(PointerEvent event) {
  if (event.kind != PointerDeviceKind.touch &&
      event.kind != PointerDeviceKind.stylus &&
      event.kind != PointerDeviceKind.invertedStylus) {
    return;
  }

  final isMove = event is PointerMoveEvent;
  final now = DateTime.now();
  if (isMove && now.difference(_lastTouchMoveLog).inMilliseconds < 250) {
    return;
  }
  if (isMove) _lastTouchMoveLog = now;

  debugPrint(
    '[INPUT] ${event.runtimeType} kind=${event.kind.name} '
    'pointer=${event.pointer} position=${event.position}',
  );

  // Beberapa panel wch.cn pada X11/GTK dilaporkan Flutter sebagai rangkaian
  // Hover -> Added -> Scale -> Removed, bukan Down -> Move -> Up. Akibatnya
  // posisi terbaca tetapi tombol Flutter tidak pernah menerima klik. Ubah
  // hanya PointerScaleEvent bertipe touch menjadi urutan gesture normal.
  if (Platform.isLinux && event.runtimeType.toString() == 'PointerScaleEvent') {
    _bridgeLinuxScaleTouch(event.position);
  }
}

void _bridgeLinuxScaleTouch(Offset position) {
  scheduleMicrotask(() {
    if (!_linuxTouchBridgeActive) {
      _linuxTouchBridgeActive = true;
      _linuxTouchBridgePointer++;
      _linuxTouchBridgePosition = position;
      GestureBinding.instance.handlePointerEvent(
        PointerDownEvent(
          pointer: _linuxTouchBridgePointer,
          device: _linuxTouchBridgePointer,
          kind: PointerDeviceKind.touch,
          position: position,
        ),
      );
      debugPrint('[TOUCH-BRIDGE] down position=$position');
    } else {
      final delta = position - _linuxTouchBridgePosition;
      _linuxTouchBridgePosition = position;
      if (delta.distanceSquared > 0) {
        GestureBinding.instance.handlePointerEvent(
          PointerMoveEvent(
            pointer: _linuxTouchBridgePointer,
            device: _linuxTouchBridgePointer,
            kind: PointerDeviceKind.touch,
            position: position,
            delta: delta,
          ),
        );
      }
    }

    _linuxTouchReleaseTimer?.cancel();
    _linuxTouchReleaseTimer = Timer(const Duration(milliseconds: 120), () {
      GestureBinding.instance.handlePointerEvent(
        PointerUpEvent(
          pointer: _linuxTouchBridgePointer,
          device: _linuxTouchBridgePointer,
          kind: PointerDeviceKind.touch,
          position: _linuxTouchBridgePosition,
        ),
      );
      debugPrint('[TOUCH-BRIDGE] up position=$_linuxTouchBridgePosition');
      _linuxTouchBridgeActive = false;
    });
  });
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
