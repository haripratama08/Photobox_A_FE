import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:photobox_pro/config/app_config.dart';
import 'package:photobox_pro/services/socket_services.dart';
import 'package:photobox_pro/services/storage_services.dart';
import 'package:photobox_pro/widgets/app_close_button.dart';
import 'package:provider/provider.dart';
import '../viewmodels/capture_viewmodel.dart';
import 'welcome_screen.dart';
import 'settings_screen.dart';

class StudioCaptureScreen extends StatelessWidget {
  final Map<String, dynamic> frameConfig;
  final String userName, userWA, userEmail;

  StudioCaptureScreen({
    Key? key,
    required this.frameConfig,
    required this.userName,
    required this.userWA,
    required this.userEmail,
  }) : super(key: key);

  final GlobalKey _previewKey = GlobalKey();

  Future<void> _processFinalImage(
      BuildContext context, CaptureViewModel vm) async {
    vm.stopSession();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                  color: AppConfig.primaryColor, strokeWidth: 4),
              const SizedBox(height: 30),
              Text(
                "Mencetak & Mengirim Foto...",
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9), fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 300));

    // Langsung kirim data ke Node.js tanpa render RepaintBoundary
    context.read<SocketService>().emit('send-results', {
      'userName': userName,
      'userWA': userWA,
      'userEmail': userEmail,
      'photos': vm.capturedPhotos,
      'printCopies': vm.printCopies,
      'frameName': frameConfig['name'],
    });

    Future.delayed(const Duration(seconds: 4), () {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final vm = CaptureViewModel(
            context.read<SocketService>(), context.read<StorageService>());
        vm.initSession(frameConfig, userName, userWA, userEmail);
        return vm;
      },
      child: Consumer<CaptureViewModel>(
        builder: (context, vm, child) {
          bool isAllCaptured =
              vm.capturedPhotos.length == frameConfig['slot_count'];

          return Scaffold(
            backgroundColor: const Color(0xFF0F0F0F),
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 96,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.86),
                      Colors.black.withOpacity(0.48),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              title: Row(
                children: [
                  _buildCameraStatus(vm),
                  const SizedBox(width: 12),
                  _buildGlassPill(
                    icon: Icons.photo_library_rounded,
                    text:
                        "${vm.capturedPhotos.length}/${frameConfig['slot_count']} Foto",
                    color: AppConfig.primaryColor,
                  ),
                  const Spacer(),
                  _buildSessionTimer(vm),
                ],
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SettingsScreen())),
                  ),
                ),
                const AppCloseButton(),
              ],
            ),
            body: Stack(
              children: [
                // LAYER 1: LIVE VIEW KAMERA
                Positioned.fill(
                  child: isAllCaptured
                      ? _buildPrintOptionsPanel(context, vm)
                      : RepaintBoundary(
                          child: ValueListenableBuilder(
                            valueListenable: vm.liveView,
                            builder: (context, liveViewBytes, child) {
                              if (liveViewBytes == null) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              return Transform(
                                alignment: Alignment.center,
                                transform: vm.isMirror
                                    ? Matrix4.rotationY(math.pi)
                                    : Matrix4.identity(),
                                child: Image.memory(
                                  liveViewBytes,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  filterQuality: FilterQuality.none,
                                  isAntiAlias: false,
                                ),
                              );
                            },
                          ),
                        ),
                ),

                // LAYER 1.5: EFEK FLASH KAMERA
                Positioned.fill(
                  child: CameraFlashEffect(
                    isTriggered: vm.isCapturing &&
                        vm.countdown == 0 &&
                        vm.tempPreviewPhoto == null,
                  ),
                ),

                // LAYER 2: COUNTDOWN MENGAMBANG
                // Uses ValueListenableBuilder to avoid full Consumer rebuild on each tick
                Positioned.fill(
                  child: ValueListenableBuilder<int>(
                    valueListenable: vm.countdownNotifier,
                    builder: (context, countdown, _) {
                      if (countdown <= 0) return const SizedBox.shrink();
                      return _buildCountdownContent(countdown);
                    },
                  ),
                ),

                // LAYER 3: PREVIEW FOTO YANG BARU DIAMBIL
                if (vm.tempPreviewPhoto != null) _buildPreviewOverlay(vm),

                // LAYER 4: TOMBOL SHUTTER KAMERA
                if (!vm.isCapturing &&
                    vm.tempPreviewPhoto == null &&
                    !isAllCaptured &&
                    !vm.isSessionExpired)
                  Positioned(
                    left: 0,
                    right: 350,
                    bottom: 34,
                    child: _buildCaptureButton(vm),
                  ),

                // LAYER 5: PANEL HASIL FOTO (SIDEBAR KANAN)
                Positioned(
                  right: 30,
                  top: 110, // Menghindari bentrok dengan AppBar
                  bottom: 40,
                  width: 320,
                  child: Column(
                    children: [
                      _buildPreviewHeader(vm),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A)
                                .withOpacity(0.9), // Glassmorphism solid
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10)),
                            ],
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: _buildCollagePreview(vm),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (!vm.isFinalizing && !isAllCaptured)
                        Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      AppConfig.primaryColor.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5)),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConfig.primaryColor,
                              minimumSize: const Size(double.infinity, 60),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              elevation: 0,
                            ),
                            onPressed: vm.capturedPhotos.isNotEmpty
                                ? () => _processFinalImage(context, vm)
                                : null,
                            child: const Text(
                              "SELESAI LEBIH AWAL",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                if (vm.isSessionExpired) _buildExpiredOverlay(context),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Color _sessionTimerColor(int remainingSeconds) {
    if (remainingSeconds <= 60) return Colors.redAccent;
    if (remainingSeconds <= 120) return Colors.orangeAccent;
    return AppConfig.primaryColor;
  }

  Widget _buildCameraStatus(CaptureViewModel vm) {
    return ValueListenableBuilder(
      valueListenable: vm.liveView,
      builder: (context, liveViewBytes, child) =>
          _buildCameraStatusContent(liveViewBytes != null),
    );
  }

  Widget _buildCameraStatusContent(bool isReady) {
    final color = isReady ? Colors.greenAccent : Colors.orangeAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.55), blurRadius: 9),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Text(
            isReady ? 'Kamera Aktif' : 'Menghubungkan Kamera',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTimer(CaptureViewModel vm) {
    // Uses its own ValueListenableBuilder so timer ticks don't rebuild the
    // entire screen via Consumer. Only this timer widget rebuilds each second.
    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: vm.sessionDurationNotifier,
        builder: (context, duration, _) {
          final color = _sessionTimerColor(duration);
          final progress =
              (duration / CaptureViewModel.totalSessionDuration)
                  .clamp(0.0, 1.0);

          return Container(
            width: 230,
            padding: const EdgeInsets.fromLTRB(16, 9, 16, 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.68),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.65), width: 1.4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_outlined, color: color, size: 22),
                    const SizedBox(width: 9),
                    Text(
                      duration <= 60 ? 'SEGERA BERAKHIR' : 'SISA WAKTU',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDuration(duration),
                      style: TextStyle(
                        color: color,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: Colors.white.withOpacity(0.13),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Countdown overlay content — called from ValueListenableBuilder.
  /// Takes the countdown value directly instead of reading from ViewModel,
  /// so only this widget rebuilds on each countdown tick.
  Widget _buildCountdownContent(int countdown) {
    return Container(
      color: Colors.black.withOpacity(0.48),
      padding: const EdgeInsets.only(right: 350),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.62),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.22)),
              ),
              child: const Text(
                'SIAPKAN POSE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.38),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 7),
                boxShadow: [
                  BoxShadow(
                    color: AppConfig.primaryColor.withOpacity(0.45),
                    blurRadius: 48,
                    spreadRadius: 8,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '$countdown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 132,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Foto akan diambil otomatis',
              style: TextStyle(
                color: Colors.white.withOpacity(0.82),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureButton(CaptureViewModel vm) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: vm.startCaptureSequence,
            child: Container(
              width: 106,
              height: 106,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.28),
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppConfig.primaryColor,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.62),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'AMBIL FOTO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewHeader(CaptureViewModel vm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.68),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_mosaic_rounded,
              color: AppConfig.primaryColor, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Preview Frame',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppConfig.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${vm.capturedPhotos.length}/${frameConfig['slot_count']}',
              style: TextStyle(
                color: AppConfig.primaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.86),
        alignment: Alignment.center,
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(38),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 40),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_off_rounded,
                  color: Colors.redAccent, size: 72),
              const SizedBox(height: 22),
              const Text(
                'Waktu Sesi Habis',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Silakan kembali ke halaman awal untuk memulai sesi foto baru.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.68),
                  fontSize: 17,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (context) => const WelcomeScreen()),
                  (route) => false,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.primaryColor,
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.home_rounded, color: Colors.white),
                label: const Text(
                  'KEMBALI KE HALAMAN AWAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Komponen Indikator Atas
  Widget _buildGlassPill(
      {required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildCollagePreview(CaptureViewModel vm) {
    return RepaintBoundary(
      key: _previewKey,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slots = frameConfig['slots'] as List<dynamic>;
            return Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.white),
                ...List.generate(slots.length, (index) {
                  if (index >= vm.capturedPhotos.length)
                    return const SizedBox.shrink();
                  final slot = slots[index] as Map<String, dynamic>;
                  return Positioned(
                    top: constraints.maxHeight * (slot['t'] as double),
                    left: constraints.maxWidth * (slot['l'] as double),
                    width: constraints.maxWidth * (slot['w'] as double),
                    height: constraints.maxHeight * (slot['h'] as double),
                    child: Container(
                      clipBehavior: Clip.hardEdge,
                      decoration: const BoxDecoration(color: Color(0xFF121212)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Transform.flip(
                              flipX: vm.isMirror,
                              child: Image.network(vm.capturedPhotos[index],
                                  fit: BoxFit.cover),
                            ),
                          ),
                          if (!vm.isFinalizing)
                            Positioned(
                              top: 5,
                              right: 5,
                              child: GestureDetector(
                                onTap: () => vm.removePhoto(index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                IgnorePointer(
                  child: Image.network(
                    frameConfig['asset_path'],
                    fit: BoxFit.fill,
                    errorBuilder: (c, e, s) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.white24)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreviewOverlay(CaptureViewModel vm) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.5), // Latar belakang meredup sedikit
        child: Padding(
          // Menggeser titik tengah ke kiri sebesar 350px agar menghindari Sidebar Kanan
          padding: const EdgeInsets.only(right: 350.0),
          child: Center(
            child: Container(
              width: 480, // Ukuran lebar pop-up
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A), // Warna card gelap elegan
                borderRadius: BorderRadius.circular(25),
                border:
                    Border.all(color: Colors.white.withOpacity(0.15), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 40,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min, // Tinggi otomatis menyesuaikan isi
                children: [
                  const Text(
                    "Hasil Jepretan",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 320, // Preview foto dibuat lebih kecil
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3), width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Transform.flip(
                      flipX: vm.isMirror,
                      child: Image.network(vm.tempPreviewPhoto!,
                          fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 35),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: Colors.white.withOpacity(0.6), width: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 25, vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                        ),
                        icon: const Icon(Icons.refresh_rounded,
                            color: Colors.white, size: 22),
                        onPressed: vm.retakePhoto,
                        label: const Text("ULANGI",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff0000cd),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 25, vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          elevation: 10,
                          shadowColor: const Color(0xff0000cd).withOpacity(0.5),
                        ),
                        icon: const Icon(Icons.check_circle_outline,
                            color: Colors.white, size: 22),
                        onPressed: vm.acceptPhoto,
                        label: const Text("SIMPAN",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrintOptionsPanel(BuildContext context, CaptureViewModel vm) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF0F0F0F)],
          center: Alignment.center,
          radius: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(
            right: 360.0), // Mencegah tumpang tindih dengan pratinjau kolase
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: Colors.greenAccent, size: 90),
            ),
            const SizedBox(height: 25),
            const Text("Sesi Foto Selesai!",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Text("Pilih jumlah cetak fisik yang diinginkan.",
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 20)),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [1, 2, 3].map((n) {
                bool isSelected = vm.printCopies == n;
                return GestureDetector(
                  onTap: () => vm.setPrintCopies(n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 15),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xff0000cd)
                          : const Color(0xFF1A1A1A),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withOpacity(0.1),
                          width: isSelected ? 3 : 1.5),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color:
                                      const Color(0xff0000cd).withOpacity(0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8))
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text("$n",
                          style: TextStyle(
                              fontSize: 36,
                              color: isSelected ? Colors.white : Colors.white54,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 60),
            Container(
              decoration: BoxDecoration(boxShadow: [
                BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10))
              ]),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 50, vertical: 25),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                onPressed: () => _processFinalImage(context, vm),
                icon: const Icon(Icons.print_rounded,
                    color: Colors.white, size: 30),
                label: Text("CETAK SEKARANG (${vm.printCopies} Lbr)",
                    style: const TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class CameraFlashEffect extends StatefulWidget {
  final bool isTriggered;
  const CameraFlashEffect({Key? key, required this.isTriggered})
      : super(key: key);

  @override
  State<CameraFlashEffect> createState() => _CameraFlashEffectState();
}

class _CameraFlashEffectState extends State<CameraFlashEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    // Tween goes to 0.9 for bright white flash effect.
    // Using FadeTransition below avoids widget rebuilds on every animation tick.
    _opacity = Tween<double>(begin: 0.0, end: 0.9)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    if (widget.isTriggered) {
      _triggerFlash();
    }
  }

  @override
  void didUpdateWidget(covariant CameraFlashEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTriggered && !oldWidget.isTriggered) {
      _triggerFlash();
    }
  }

  void _triggerFlash() {
    _controller.forward(from: 0.0).then((_) {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FadeTransition animates opacity at the render-object level,
    // avoiding widget tree rebuilds on every animation frame.
    // ColoredBox is lighter than Container for a single solid color.
    return IgnorePointer(
      child: FadeTransition(
        opacity: _opacity,
        child: const ColoredBox(color: Colors.white),
      ),
    );
  }
}
