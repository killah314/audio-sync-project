import "package:socket_io_client/socket_io_client.dart" as IO;

class SocketClient {
  IO.Socket? socket;
  static SocketClient? _instance;

  SocketClient._internal() {
    socket = IO.io(
        'http://192.168.1.213:3000', //ALWAYS CHANGE ACCORDING TO CURRENT IP ADDRESS
        <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': false, // Do not connect automatically
        });
    socket!.connect();
  }

  static SocketClient get instance {
    _instance ??= SocketClient._internal();
    return _instance!;
  }
}
