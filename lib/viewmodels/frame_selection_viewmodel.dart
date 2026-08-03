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

    _socketService.emit('get-frames');
    _socketService.once('frames-list', (data) {
      frames = List<Map<String, dynamic>>.from(data);
      isLoading = false;
      notifyListeners();
    });
  }
}
