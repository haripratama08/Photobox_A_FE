import 'package:flutter/material.dart';
import 'package:photobox_pro/services/socket_services.dart';

class FrameSelectionViewModel extends ChangeNotifier {
  final SocketService _socketService;

  List<Map<String, dynamic>> frames = [];
  bool isLoading = true;

  FrameSelectionViewModel(this._socketService) {
    _fetchFrames();
  }

  void _fetchFrames() {
    isLoading = true;
    notifyListeners();

    _socketService.once('frames-list', (data) {
      frames = (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((frame) =>
              frame['asset_path'] is String && frame['asset_path'].isNotEmpty)
          .toList();
      isLoading = false;
      notifyListeners();
    });

    // Pasang listener lebih dahulu agar respons cepat dari API tidak terlewat.
    _socketService.emit('get-frames');
  }
}
