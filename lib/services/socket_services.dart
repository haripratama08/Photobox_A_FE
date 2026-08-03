import 'package:photobox_pro/config/app_config.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  late IO.Socket _socket;
  IO.Socket get socket => _socket;

  void initSocket() {
    _socket = IO.io(AppConfig.socketBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    _socket.connect();
  }

  void emit(String event, [dynamic data]) => _socket.emit(event, data);
  void on(String event, dynamic Function(dynamic) handler) =>
      _socket.on(event, handler);
  void once(String event, dynamic Function(dynamic) handler) =>
      _socket.once(event, handler);
  void off(String event) => _socket.off(event);
}
