import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_device.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';

/// Low-level USB serial communication (hardware only).
///
/// Exposes raw decoded text chunks. No protocol or temperature parsing.
class SerialService {
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _subscription;
  final StreamController<String> _incomingController =
      StreamController<String>.broadcast();

  String? _lastPortName;
  int _lastBaudRate = 115200;
  bool _disposed = false;

  /// Chains connect/disconnect/reconnect so they never interleave.
  Future<void> _lock = Future<void>.value();

  /// Raw UTF-8 text as received from the device (no framing assumed).
  Stream<String> get incoming => _incomingController.stream;

  bool get isConnected => _port?.isOpen ?? false;

  String? get connectedPortName => isConnected ? _lastPortName : null;

  int get baudRate => _lastBaudRate;

  /// Scan host serial ports. Does not open a persistent connection.
  List<SerialDevice> listPorts() {
    final names = SerialPort.availablePorts;
    final devices = <SerialDevice>[];

    for (final name in names) {
      final probe = SerialPort(name);
      try {
        final device = SerialDevice(
          name: name,
          description: probe.description,
          transport: _transportLabel(probe.transport),
          manufacturer: probe.manufacturer,
          productName: probe.productName,
          serialNumber: probe.serialNumber,
        );
        devices.add(device);
        AppLogger.info('Serial port discovered: ${device.displayLabel}');
      } catch (error) {
        AppLogger.error('Serial port probe failed for $name', error);
        devices.add(SerialDevice(name: name));
        AppLogger.info('Serial port discovered: $name');
      } finally {
        probe.dispose();
      }
    }

    return devices;
  }

  /// Open [portName] at [baudRate] (8N1). Port name is chosen by the caller.
  Future<void> connect(String portName, {int baudRate = 115200}) {
    return _serialized(() => _connectUnlocked(portName, baudRate: baudRate));
  }

  Future<void> _connectUnlocked(String portName, {int baudRate = 115200}) async {
    _ensureNotDisposed();
    final trimmed = portName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('portName must not be empty');
    }

    await _disconnectUnlocked(silent: true);

    _lastPortName = trimmed;
    _lastBaudRate = baudRate;

    final port = SerialPort(trimmed);
    final opened = port.openReadWrite();
    if (!opened) {
      final error = SerialPort.lastError;
      port.dispose();
      final message = 'Failed to open $trimmed: ${error ?? 'unknown error'}';
      AppLogger.error(message);
      throw StateError(message);
    }

    try {
      // Fresh config that the port setter will own. Do NOT call dispose() on it
      // after assignment — SerialPort.dispose() frees the same native pointer
      // (flutter_libserialport Windows double-free / CRT heap assert).
      final config = SerialPortConfig();
      config.baudRate = baudRate;
      config.bits = 8;
      config.stopBits = 1;
      config.parity = SerialPortParity.none;
      config.rts = SerialPortRts.on;
      config.dtr = SerialPortDtr.on;
      config.setFlowControl(SerialPortFlowControl.none);
      port.config = config;
    } catch (error) {
      port.close();
      port.dispose();
      AppLogger.error('Serial config failed for $trimmed', error);
      rethrow;
    }

    _port = port;
    _reader = SerialPortReader(port);
    _subscription = _reader!.stream.listen(
      _onBytes,
      onError: (Object error) {
        AppLogger.error('Serial read error on $trimmed', error);
      },
      onDone: () {
        AppLogger.info('Serial reader closed for $trimmed');
      },
      cancelOnError: false,
    );

    AppLogger.info('Serial connected: $trimmed @ $baudRate baud');
  }

  /// Close the active port and stop the reader.
  Future<void> disconnect({bool silent = false}) {
    return _serialized(() => _disconnectUnlocked(silent: silent));
  }

  Future<void> _disconnectUnlocked({bool silent = false}) async {
    final name = _lastPortName;

    await _subscription?.cancel();
    _subscription = null;

    final reader = _reader;
    _reader = null;
    if (reader != null) {
      try {
        reader.close();
      } catch (error) {
        AppLogger.error('Serial reader close failed', error);
      }
    }

    // Let the reader isolate settle before freeing the port (Windows).
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final port = _port;
    _port = null;
    if (port != null) {
      try {
        if (port.isOpen) {
          port.close();
        }
      } catch (error) {
        AppLogger.error('Serial close failed', error);
      }
      try {
        port.dispose();
      } catch (error) {
        AppLogger.error('Serial dispose failed', error);
      }
    }

    if (!silent && name != null) {
      AppLogger.info('Serial disconnected: $name');
    }
  }

  /// Re-open the last successful port/baud pair.
  Future<void> reconnect() {
    return _serialized(() async {
      _ensureNotDisposed();
      final portName = _lastPortName;
      if (portName == null || portName.isEmpty) {
        throw StateError('No previous serial port to reconnect');
      }
      AppLogger.info('Serial reconnecting: $portName');
      await _connectUnlocked(portName, baudRate: _lastBaudRate);
    });
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await disconnect(silent: true);
    await _incomingController.close();
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final previous = _lock;
    final gate = Completer<void>();
    _lock = gate.future;
    return previous.then((_) => action()).whenComplete(gate.complete);
  }

  void _onBytes(Uint8List data) {
    if (data.isEmpty || _incomingController.isClosed) {
      return;
    }
    final text = utf8.decode(data, allowMalformed: true);
    if (text.isEmpty) {
      return;
    }
    AppLogger.info('Serial raw message received (${data.length} bytes)');
    _incomingController.add(text);
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('SerialService has been disposed');
    }
  }

  static String? _transportLabel(int transport) {
    return switch (transport) {
      SerialPortTransport.native => 'native',
      SerialPortTransport.usb => 'usb',
      SerialPortTransport.bluetooth => 'bluetooth',
      _ => null,
    };
  }
}
