import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';

/// Singleton сервіс для Socket.IO з'єднання
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  late IO.Socket _socket;
  IO.Socket get socket => _socket;
  bool get isConnected => _socket.connected;

  /// [token] — JWT токен з AuthService.getToken()
  void init({required String token}) {
    _socket = IO.io(
      AppConfig.serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token}) // 🔐 JWT передається тут
          .build(),
    );
  }

  void connect() => _socket.connect();
  void disconnect() => _socket.disconnect();

  // ── Кімнати ──────────────────────────────
  void joinChat(String chatId) => _socket.emit('join_chat', chatId);
  void leaveChat(String chatId) => _socket.emit('leave_chat', chatId);

  // ── Повідомлення ─────────────────────────
  void sendMessage(Map<String, dynamic> data) =>
      _socket.emit('send_message', data);

  void deleteMessage(String msgId, String chatId) =>
      _socket.emit('delete_message', {'messageId': msgId, 'chatId': chatId});

  void editMessage(
    String msgId,
    String newText,
    String username,
    String chatId,
  ) => _socket.emit('edit_message', {
    'messageId': msgId,
    'newText': newText,
    'username': username,
    'chatId': chatId,
  });

  // ── Реакції та статуси ────────────────────
  void addReaction(
    String msgId,
    String emoji,
    String username,
    String chatId,
  ) => _socket.emit('add_reaction', {
    'messageId': msgId,
    'emoji': emoji,
    'username': username,
    'chatId': chatId,
  });

  void emitTyping(String username, String chatId) =>
      _socket.emit('typing', {'username': username, 'chatId': chatId});

  void markRead(String chatId, String username) =>
      _socket.emit('mark_read', {'chatId': chatId, 'username': username});

  void registerToken(String token, String username) =>
      _socket.emit('register_token', {'token': token, 'username': username});

  void requestHistory(String chatId) => _socket.emit('request_history', chatId);

  // ── Слухачі ───────────────────────────────
  void on(String event, dynamic Function(dynamic) handler) =>
      _socket.on(event, handler);

  void off(String event) => _socket.off(event);

  void onConnect(dynamic Function(dynamic) handler) =>
      _socket.onConnect(handler);

  void onDisconnect(dynamic Function(dynamic) handler) =>
      _socket.onDisconnect(handler);

  void dispose() => _socket.dispose();
}
