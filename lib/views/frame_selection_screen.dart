import 'package:flutter/material.dart';
import 'package:photobox_pro/services/socket_services.dart';
import 'package:provider/provider.dart';
import 'package:photobox_pro/widgets/app_close_button.dart';
import '../viewmodels/frame_selection_viewmodel.dart';
import 'studio_capture_screen.dart';

class FrameSelectionScreen extends StatefulWidget {
  final String userName, userWA, userEmail;

  const FrameSelectionScreen({
    Key? key,
    required this.userName,
    required this.userWA,
    required this.userEmail,
  }) : super(key: key);

  @override
  State<FrameSelectionScreen> createState() => _FrameSelectionScreenState();
}

class _FrameSelectionScreenState extends State<FrameSelectionScreen> {
  final ScrollController _frameScrollController = ScrollController();

  @override
  void dispose() {
    _frameScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          FrameSelectionViewModel(context.read<SocketService>()),
      child: Consumer<FrameSelectionViewModel>(
        builder: (context, vm, child) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: const [AppCloseButton()],
            ),
            body: Container(
              // Background senada dengan Registration Screen
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0xFF1E1E1E), Color(0xFF0F0F0F)],
                  center: Alignment.center,
                  radius: 1.5,
                ),
              ),
              child: Column(
                children: [
                  // Header Title
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 20),
                      child: Column(
                        children: [
                          const Text(
                            "Pilih Desain Frame",
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Geser dan ketuk desain favoritmu untuk memulai sesi foto.",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Content Area (Loading / Empty / ListView)
                  Expanded(
                    child: _buildContent(context, vm),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, FrameSelectionViewModel vm) {
    if (vm.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xff0000cd),
              strokeWidth: 4,
            ),
            const SizedBox(height: 25),
            Text(
              "Memuat koleksi frame...",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      );
    }

    if (vm.frames.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 80, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 20),
            Text(
              "Belum ada frame yang tersedia.",
              style:
                  TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 20),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        if (!_frameScrollController.hasClients) return;
        final position = _frameScrollController.position;
        final target = (_frameScrollController.offset - details.delta.dx)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
        _frameScrollController.jumpTo(target);
      },
      onHorizontalDragEnd: (details) {
        if (!_frameScrollController.hasClients) return;
        final position = _frameScrollController.position;
        final target = (_frameScrollController.offset -
                (details.primaryVelocity ?? 0) * 0.18)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
        _frameScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      },
      child: ListView.builder(
        controller: _frameScrollController,
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 30),
        itemCount: vm.frames.length,
        itemBuilder: (context, index) {
          final frame = vm.frames[index];
          return _buildFrameCard(context, frame);
        },
      ),
    );
  }

  Widget _buildFrameCard(BuildContext context, Map<String, dynamic> frame) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudioCaptureScreen(
            frameConfig: frame,
            userName: widget.userName,
            userWA: widget.userWA,
            userEmail: widget.userEmail,
          ),
        ),
      ),
      child: Container(
        width: 380, // Ukuran card yang proporsional
        margin: const EdgeInsets.only(right: 40),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A), // Warna card elegan
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 25,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        clipBehavior:
            Clip.antiAlias, // Memastikan isi mengikuti bentuk rounded corner
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Frame Image Preview
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Latar belakang area gambar
                  Container(color: const Color(0xFF121212)),
                  // Gambar Frame
                  Image.network(
                    frame['asset_path'],
                    fit: BoxFit
                        .contain, // Menyesuaikan bingkai agar terlihat utuh
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          color: const Color(0xff0000cd).withOpacity(0.5),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image_rounded,
                          size: 60, color: Colors.white24),
                    ),
                  ),
                ],
              ),
            ),
            // Frame Title Area
            Container(
              decoration: const BoxDecoration(
                color: Color(0xff0000cd), // Primary Blue
              ),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
              child: Text(
                frame['name'] ?? 'Untitled Frame',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow
                    .ellipsis, // Mencegah teks terlalu panjang merusak layout
              ),
            ),
          ],
        ),
      ),
    );
  }
}
