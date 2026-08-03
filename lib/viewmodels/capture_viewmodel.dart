import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photobox_pro/services/socket_services.dart';
import 'package:photobox_pro/services/storage_services.dart';

class CaptureViewModel extends ChangeNotifier {
  static const int totalSessionDuration = 600;

  final SocketService _socketService;
  final StorageService _storageService;

  int sessionDuration = totalSessionDuration;
  Timer? sessionTimer;
  Timer? countdownTimer;

  final ValueNotifier<Uint8List?> liveView = ValueNotifier(null);
  List<String> capturedPhotos = [];

  int countdown = 0;
  bool isCapturing = false;
  String? tempPreviewPhoto;
  bool isFinalizing = false;
  bool isSessionExpired = false;

  int printCopies = 1;
  bool isMirror = false;

  late Map<String, dynamic> frameConfig;
  late String userName, userWA, userEmail;

  CaptureViewModel(this._socketService, this._storageService);

  Future<void> initSession(
      Map<String, dynamic> frame, String name, String wa, String email) async {
    frameConfig = frame;
    userName = name;
    userWA = wa;
    userEmail = email;

    final settings = await _storageService.loadSettings();
    isMirror = settings['setting_mirror'];

    _socketService.emit('set-active-user', userName);
    _socketService.emit('set-mirror', isMirror);

    _startSessionTimer();
    _setupCameraListeners();
    _socketService.emit('start-liveview');
  }

  void _startSessionTimer() {
    sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (sessionDuration <= 1) {
        sessionDuration = 0;
        _expireSession();
        return;
      }
      sessionDuration--;
      notifyListeners();
    });
  }

  void _expireSession() {
    sessionTimer?.cancel();
    countdownTimer?.cancel();
    countdown = 0;
    isCapturing = false;
    isSessionExpired = true;
    _socketService.emit('stop-liveview');
    notifyListeners();
  }

  void _setupCameraListeners() {
    _socketService.on('liveview-frame', (data) {
      if (tempPreviewPhoto == null && (!isCapturing || countdown > 0)) {
        liveView.value = base64Decode(data);
      }
    });

    _socketService.on('photo-ready', (data) {
      if (isCapturing) {
        tempPreviewPhoto =
            "${data['url']}?v=${DateTime.now().millisecondsSinceEpoch}";
        countdown = 0;
        notifyListeners();
      }
    });
  }

  void startCaptureSequence() {
    if (capturedPhotos.length >= frameConfig['slot_count'] ||
        isCapturing ||
        isSessionExpired) {
      return;
    }
    _socketService.emit('set-active-user', userName);
    isCapturing = true;
    countdown = 5;
    notifyListeners();

    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown > 1) {
        countdown--;
        notifyListeners();
      } else {
        timer.cancel();
        countdownTimer = null;
        countdown = 0;
        _socketService.emit('stop-liveview');
        _socketService.emit('take-photo');
        notifyListeners();
      }
    });
  }

  void acceptPhoto() {
    if (tempPreviewPhoto != null) {
      capturedPhotos.add(tempPreviewPhoto!);
      tempPreviewPhoto = null;
      isCapturing = false;
      notifyListeners();
      if (capturedPhotos.length != frameConfig['slot_count']) {
        _socketService.emit('start-liveview');
      }
    }
  }

  void retakePhoto() {
    tempPreviewPhoto = null;
    isCapturing = false;
    notifyListeners();
    _socketService.emit('start-liveview');
  }

  void removePhoto(int index) {
    capturedPhotos.removeAt(index);
    notifyListeners();
    if (!isSessionExpired && !isFinalizing) {
      _socketService.emit('start-liveview');
    }
  }

  void setPrintCopies(int copies) {
    printCopies = copies;
    notifyListeners();
  }

  void stopSession() {
    sessionTimer?.cancel();
    countdownTimer?.cancel();
    countdown = 0;
    _socketService.emit('stop-liveview');
    isFinalizing = true;
    notifyListeners();
  }

  @override
  void dispose() {
    sessionTimer?.cancel();
    countdownTimer?.cancel();
    _socketService.off('liveview-frame');
    _socketService.off('photo-ready');
    _socketService.emit('stop-liveview');
    liveView.dispose();
    super.dispose();
  }
}
