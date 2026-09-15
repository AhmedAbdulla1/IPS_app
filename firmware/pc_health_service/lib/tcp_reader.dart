import 'dart:async';
import 'dart:io';

/// TCP Socket Client - بيتصل للـ Root server على localhost:9998
/// والـ Root بتبعت HEALTH: lines عليه
class TcpLineReader {
  TcpLineReader({this.host = '127.0.0.1', this.port = 9998});

  final String host;
  final int port;
  Socket? _socket;
  late final StreamController<String> _controller;
  bool _isConnected = false;

  /// بيحاول الاتصال بـ Root server
  /// لو فشلت المحاولة الأولى = تحاول تاني كل ثانية
  Future<void> start() async {
    _controller = StreamController<String>();
    
    // محاولة الاتصال الأولى
    await _connect();
    
    // لو فشل الاتصال = حاول تاني كل ثانية
    if (!_isConnected) {
      Timer.periodic(Duration(seconds: 1), (_) async {
        if (!_isConnected) {
          await _connect();
        }
      });
    }
  }

  Future<void> _connect() async {
    try {
      print('[tcp_reader] بيحاول الاتصال بـ $host:$port...');
      _socket = await Socket.connect(host, port, timeout: Duration(seconds: 5));
      _isConnected = true;
      print('[tcp_reader] ✅ متصل بـ $host:$port');
      
      // استقبال البيانات من الـ socket
      final buffer = StringBuffer();
      _socket!.listen(
        (data) {
          buffer.write(String.fromCharCodes(data));
          final text = buffer.toString();
          final lines = text.split('\n');
          
          // احتفظ بآخر سطر (قد يكون ناقص)
          buffer
            ..clear()
            ..write(lines.removeLast());

          // أرسل كل سطر كامل
          for (final line in lines) {
            final cleaned = line.trim();
            if (cleaned.isNotEmpty) {
              print('[tcp] $cleaned');
              _controller.add(cleaned);
            }
          }
        },
        onError: (error) {
          print('[tcp] ❌ خطأ: $error');
          _isConnected = false;
          _socket = null;
        },
        onDone: () {
          print('[tcp] ⚠️ الاتصال أغلق من الـ Root');
          _isConnected = false;
          _socket = null;
        },
      );
    } catch (e) {
      print('[tcp_reader] ❌ فشل الاتصال: $e');
      _isConnected = false;
    }
  }

  Stream<String> lines() {
    return _controller.stream;
  }

  bool get isConnected => _isConnected;

  Future<void> dispose() async {
    await _controller.close();
    await _socket?.close();
  }
}
