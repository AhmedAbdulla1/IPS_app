import 'dart:convert';
import 'dart:typed_data';

import 'package:libserialport/libserialport.dart';

/// بيغلّف منفذ الـSerial ويطلع Stream من الأسطر النصية الكاملة (مقسّمة
/// على '\n')، بنفس فلسفة `Serial.readStringUntil('\n')` المستخدمة في
/// فيرموير الـRoot.
class SerialLineReader {
  SerialLineReader({required String portName, required int baudRate})
      : _port = SerialPort(portName) {
    if (!_port.openRead()) {
      throw StateError(
        'مش قادر يفتح منفذ الـSerial "$portName": ${SerialPort.lastError}',
      );
    }
    final config = SerialPortConfig()
      ..baudRate = baudRate
      ..bits = 8
      ..parity = SerialPortParity.none
      ..stopBits = 1;
    _port.config = config;
    _reader = SerialPortReader(_port);
  }

  final SerialPort _port;
  late final SerialPortReader _reader;
  final StringBuffer _buffer = StringBuffer();

  /// Stream بيطلع سطر كامل كل ما '\n' توصل. بيتجاهل الـbytes الفاضية.
  Stream<String> lines() async* {
    await for (final Uint8List chunk in _reader.stream) {
      _buffer.write(utf8.decode(chunk, allowMalformed: true));
      final text = _buffer.toString();
      final parts = text.split('\n');

      // آخر جزء ممكن يكون سطر لسه مكتملش - نرجّعه للـbuffer.
      _buffer
        ..clear()
        ..write(parts.removeLast());

      for (final line in parts) {
        final cleaned = line.trim();
        if (cleaned.isNotEmpty) yield cleaned;
      }
    }
  }

  void dispose() {
    _port.close();
    _port.dispose();
  }
}
