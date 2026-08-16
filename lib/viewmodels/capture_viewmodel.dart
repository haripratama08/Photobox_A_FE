import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:photobox_pro/services/socket_services.dart';
import 'package:photobox_pro/services/storage_services.dart';

/// Top-level function required for compute() — runs in a separate isolate
/// to avoid blocking the UI thread with heavy base64 decoding.
Uint8List _decodeBase64Frame(String data) => base64Decode(data);

class CaptureViewModel extends ChangeNotifier {
  static const int totalSessionDuration = 600;

  final SocketService _socketService;
  final StorageService _storageService;

  // =========================================================================
  // HOT-PATH ValueNotifiers
  // These update very frequently and should NOT trigger full Consumer rebuild.
  // Each has its own ValueListenableBuilder in the UI for granular updates.
  // =========================================================================

  /// Live camera feed — decoded JPEG bytes from background isolate.
  final ValueNotifier<Uint8List?> liveView = ValueNotifier(null);

  /// Session countdown timer — ticks every second.
  /// Uses ValueNotifier so only the timer widget rebuilds, not the full screen.
  final ValueNotifier<int> sessionDurationNotifier =
      ValueNotifier(totalSessionDuration);

  /// Capture countdown (5,4,3,2,1) — ticks every second during capture.
  /// Uses ValueNotifier so only the countdown overlay rebuilds.
  final ValueNotifier<int> countdownNotifier = ValueNotifier(0);

  // =========================================================================
  // REGULAR STATE — updated infrequently on user actions.
  // Uses notifyListeners() which is fine since it happens rarely (~10x/session).
  // =========================================================================

  List<String> capturedPhotos = [];

  /// Kept in sync with countdownNotifier for logic checks in Consumer builder.
  int countdown = 0;

  bool isCapturing = false;
  String? tempPreviewPhoto;
  bool isFinalizing = false;
  bool isSessionExpired = false;
  int printCopies = 1;
  bool isMirror = false;

  // =========================================================================
  // FRAME THROTTLING
  // =========================================================================

  /// When true, a frame is currently being decoded in the background isolate.
  /// New incoming frames are skipped until decoding finishes.
  /// This prevents frame queue buildup when the backend sends at 80fps
  /// but decoding + rendering can only handle ~60fps.
  bool _isProcessingFrame = false;

  Timer? sessionTimer;
  Timer? countdownTimer;

  late Map<String, dynamic> frameConfig;
  late String userName, userWA, userEmail;

  CaptureViewModel(this._socketService, this._storageService);

  /// Backward-compatible getter for code that reads sessionDuration directly.
  int get sessionDuration => sessionDurationNotifier.value;

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
      final current = sessionDurationNotifier.value;
      if (current <= 1) {
        sessionDurationNotifier.value = 0;
        _expireSession();
        return;
      }
      sessionDurationNotifier.value = current - 1;
      // ✅ NO notifyListeners() here!
      // Only the session timer ValueListenableBuilder rebuilds.
      // The rest of the screen stays untouched.
    });
  }

  void _expireSession() {
    sessionTimer?.cancel();
    countdownTimer?.cancel();
    countdown = 0;
    countdownNotifier.value = 0;
    isCapturing = false;
    isSessionExpired = true;
    _socketService.emit('stop-liveview');
    // Jangan membuang foto yang sudah berhasil diambil hanya karena waktu
    // habis. Backend akan membaca foto mentah pada folder sesi lalu mencetak
    // kolase dengan frame yang sedang dipilih.
    _socketService.emit('session-expired', {
      'userName': userName,
      'userWA': userWA,
      'userEmail': userEmail,
      'frameName': frameConfig['name'],
      'printCopies': printCopies,
    });
    notifyListeners(); // Full rebuild needed to show expired overlay
  }

  void _setupCameraListeners() {
    _socketService.on('liveview-frame', (data) {
      if (tempPreviewPhoto == null && (!isCapturing || countdown > 0)) {
        // ✅ Frame throttling: skip this frame if previous is still decoding.
        // At 80fps from backend, we receive a frame every ~12.5ms.
        // Decoding + rendering takes ~10-16ms, so we skip excess frames
        // rather than letting them queue up and cause memory pressure.
        if (_isProcessingFrame) return;
        _isProcessingFrame = true;

        // ✅ Decode base64 in a separate isolate via compute().
        // This frees the UI thread from ~5-10ms of blocking work per frame,
        // which is critical for maintaining 60fps (16.6ms budget per frame).
        compute(_decodeBase64Frame, data as String).then((bytes) {
          liveView.value = bytes;
          _isProcessingFrame = false;
        });
      }
    });

    _socketService.on('photo-ready', (data) {
      if (isCapturing) {
        tempPreviewPhoto =
            "${data['url']}?v=${DateTime.now().millisecondsSinceEpoch}";
        countdown = 0;
        countdownNotifier.value = 0;
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
    countdownNotifier.value = 5;
    notifyListeners(); // Needed: shows countdown overlay, hides shutter button

    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown > 1) {
        countdown--;
        countdownNotifier.value = countdown;
        // ✅ NO notifyListeners() for intermediate countdown ticks (5→4→3→2).
        // Only the countdown ValueListenableBuilder rebuilds the number display.
      } else {
        timer.cancel();
        countdownTimer = null;
        countdown = 0;
        countdownNotifier.value = 0;
        _socketService.emit('stop-liveview');
        _socketService.emit('take-photo');
        notifyListeners(); // Needed: triggers flash effect (isCapturing && countdown==0)
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
    countdownNotifier.value = 0;
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
    sessionDurationNotifier.dispose();
    countdownNotifier.dispose();
    super.dispose();
  }
}
