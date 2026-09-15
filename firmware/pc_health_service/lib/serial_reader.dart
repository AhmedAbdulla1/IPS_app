import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

/// بيغلّف منفذ الـSerial ويطلع Stream من الأسطر النصية الكاملة (مقسّمة
/// على '\n')، بنفس فلسفة `Serial.readStringUntil('\n')` المستخدمة في
/// فيرموير الـRoot.
class SerialLineReader {
  SerialLineReader({required String portName, required int baudRate})
      : _portName = portName,
        _baudRate = baudRate {
    _openPort();
  }

  final String _portName;
  final int _baudRate;
  late final SerialPort _port;
  late final SerialPortReader _reader;
  late final StreamController<String> _controller;
  final StringBuffer _buffer = StringBuffer();

  void _openPort() {
    _controller = StreamController<String>();
    try {
      _port = SerialPort(_portName);
      if (!_port.openReadWrite()) {
        if (!_port.openRead()) {
          throw StateError(
            'مش قادر يفتح منفذ الـSerial "$_portName"',
          );
        }
      }
      final config = _port.config;
      config.baudRate = _baudRate;
      _port.config = config;

      _reader = SerialPortReader(_port);
      _setupListener();
    } catch (e) {
      throw StateError(
        'مش قادر يفتح منفذ الـSerial "$_portName": $e',
      );
    }
  }

  void _setupListener() {
    _reader.stream.listen((Uint8List chunk) {
      _buffer.write(String.fromCharCodes(chunk));
      final text = _buffer.toString();
      final parts = text.split('\n');

      // آخر جزء ممكن يكون سطر لسه مكتملش - نرجّعه للـbuffer.
      _buffer
        ..clear()
        ..write(parts.removeLast());

      for (final line in parts) {
        final cleaned = line.trim();
        if (cleaned.isNotEmpty) {
          _controller.add(cleaned);
        }
      }
    });
  }

  /// Stream بيطلع سطر كامل كل ما '\n' توصل.
  Stream<String> lines() {
    return _controller.stream;
  }

  void dispose() {
    _controller.close();
    _reader.close();
    _port.close();
  }
}
