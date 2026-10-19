import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'gateway_view.dart';

final _healthService = Guid('1840');
final _liveObservations = Guid('2B8B');
final _controlPoint = Guid('2BF4');

const _heartRateCode = 0x0002481A;
const _spo2Code = 0x00024BB8;
const _temperatureCode = 0x00024A00;

void main() => runApp(const SmartAmbulanceApp());

class SmartAmbulanceApp extends StatelessWidget {
  const SmartAmbulanceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Smart Ambulance',
    debugShowCheckedModeBanner: false,
    theme: gatewayTheme,
    home: const GatewayPage(),
  );
}

class GatewayPage extends StatefulWidget {
  const GatewayPage({super.key});

  @override
  State<GatewayPage> createState() => _GatewayPageState();
}

class _GatewayPageState extends State<GatewayPage> {
  final _devices = <ScanResult>[];
  final _events = <String>[];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _observationsSubscription;
  StreamSubscription<List<int>>? _controlSubscription;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _observations;
  BluetoothCharacteristic? _control;
  bool _scanning = false;
  bool _scanCompleted = false;
  bool _disconnecting = false;
  bool _controlPending = false;
  Timer? _controlFeedbackTimer;
  String? _selectedId;
  bool _connecting = false;
  bool _streaming = false;
  String _status = 'Ready to scan for Smart_Ambulance';
  int? _heartRate;
  int? _spo2;
  double? _temperature;

  @override
  void initState() {
    super.initState();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        _devices
          ..clear()
          ..addAll(results.where(_isHealthSensor));
      });
    });
  }

  @override
  void dispose() {
    _controlFeedbackTimer?.cancel();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _observationsSubscription?.cancel();
    _controlSubscription?.cancel();
    _device?.disconnect();
    super.dispose();
  }

  bool _isHealthSensor(ScanResult result) =>
      result.advertisementData.serviceUuids.contains(_healthService) ||
      result.device.platformName == 'Smart_Ambulance';

  Future<bool> _requestPermissions() async {
    final statuses = await <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final granted =
        statuses[Permission.bluetoothScan]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true;
    if (!granted && mounted) {
      setState(() => _status = 'Bluetooth permission is required to scan.');
    }
    return granted;
  }

  Future<void> _scan() async {
    if (_scanning || _connecting || _disconnecting) return;
    setState(() => _scanning = true);
    try {
      if (!await _requestPermissions()) return;
      // adapterStateNow begins as `unknown` until the Android plugin has read
      // the adapter. Await the stream's first value instead of misreporting it
      // as Bluetooth being off.
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (!mounted) return;
      if (adapterState != BluetoothAdapterState.on) {
        setState(() => _status = _adapterStateMessage(adapterState));
        return;
      }
      await FlutterBluePlus.stopScan();
      if (!mounted) return;
      setState(() {
        _devices.clear();
        _scanCompleted = false;
        _scanning = true;
        _status = 'Scanning for Generic Health Sensor Service…';
      });
      await FlutterBluePlus.startScan(
        withServices: [_healthService],
        timeout: const Duration(seconds: 10),
      );
      // startScan completes when scanning starts; observe the actual scan end.
      await FlutterBluePlus.isScanning.firstWhere((active) => !active);
      if (mounted && !_connecting) {
        setState(() {
          _scanCompleted = true;
          _status = _devices.isEmpty
              ? 'No matching devices found. Keep your ESP32 nearby and powered on.'
              : 'Scan complete. Select your ESP32.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Scan failed: $error');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  String _adapterStateMessage(BluetoothAdapterState state) => switch (state) {
    BluetoothAdapterState.unauthorized =>
      'Nearby devices permission is not allowed. Enable it in App info.',
    BluetoothAdapterState.unavailable =>
      'Bluetooth is not available on this phone.',
    BluetoothAdapterState.turningOn =>
      'Bluetooth is turning on. Wait a moment and scan again.',
    BluetoothAdapterState.turningOff =>
      'Bluetooth is turning off. Turn it back on and scan again.',
    BluetoothAdapterState.off => 'Turn on Bluetooth, then scan again.',
    BluetoothAdapterState.unknown =>
      'Bluetooth is still initialising. Wait a moment and scan again.',
    BluetoothAdapterState.on => 'Bluetooth is ready.',
  };

  Future<void> _connect(ScanResult result) async {
    if (_connecting || _disconnecting) return;
    setState(() {
      _connecting = true;
      _selectedId = result.device.remoteId.str;
    });
    try {
      await FlutterBluePlus.stopScan();
      await _connectionSubscription?.cancel();
      await _observationsSubscription?.cancel();
      await _controlSubscription?.cancel();
      if (!mounted) return;
      setState(() {
        _connecting = true;
        _status = 'Connecting to ${result.device.platformName}…';
        _streaming = false;
        _observations = null;
        _control = null;
      });
      await result.device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
      );
      _device = result.device;
      _connectionSubscription = _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && mounted) {
          setState(() {
            _controlFeedbackTimer?.cancel();
            _controlPending = false;
            _streaming = false;
            _observations = null;
            _control = null;
            _status = 'Disconnected. You can scan again.';
          });
        }
      });
      await _discoverHealthService();
    } catch (error) {
      if (mounted) setState(() => _status = 'Connection failed: $error');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _discoverHealthService() async {
    final device = _device;
    if (device == null) return;
    setState(() => _status = 'Discovering GHSS characteristics…');
    final services = await device.discoverServices();
    BluetoothService? healthService;
    for (final service in services) {
      if (service.uuid == _healthService) healthService = service;
    }
    if (healthService == null) {
      setState(() => _status = 'GHSS (0x1840) was not found on this device.');
      return;
    }
    for (final characteristic in healthService.characteristics) {
      if (characteristic.uuid == _liveObservations) {
        _observations = characteristic;
      }
      if (characteristic.uuid == _controlPoint) _control = characteristic;
    }
    if (_observations == null || _control == null) {
      setState(() => _status = 'GHSS is missing required characteristics.');
      return;
    }
    _observationsSubscription = _observations!.lastValueStream.listen(
      _decodeObservation,
    );
    _controlSubscription = _control!.lastValueStream.listen(
      _handleControlResponse,
    );
    await _observations!.setNotifyValue(true);
    await _control!.setNotifyValue(true);
    if (mounted) {
      setState(() => _status = 'Connected and ready to start telemetry.');
      _addEvent('GHSS notifications and control indications enabled.');
    }
  }

  Future<void> _writeControl(int command) async {
    final control = _control;
    if (control == null || _controlPending || _disconnecting) return;
    setState(() => _controlPending = true);
    _controlFeedbackTimer?.cancel();
    _controlFeedbackTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted || !_controlPending) return;
      setState(() {
        _controlPending = false;
        _status = 'No control acknowledgement received. You can retry.';
      });
    });
    try {
      await control.write([command], withoutResponse: false);
      if (mounted && _controlPending) {
        setState(
          () => _status = command == 0x01
              ? 'Start command sent; waiting for acknowledgement…'
              : 'Stop command sent; waiting for acknowledgement…',
        );
      }
    } catch (error) {
      _controlFeedbackTimer?.cancel();
      if (mounted) {
        setState(() {
          _controlPending = false;
          _status = 'Control command failed: $error';
        });
      }
    }
  }

  Future<void> _disconnect() async {
    final device = _device;
    if (device == null || _disconnecting) return;

    setState(() => _disconnecting = true);
    setState(() => _status = 'Disconnecting from Smart_Ambulance…');
    try {
      if (_streaming && _control != null) {
        try {
          await _control!.write([0x02], withoutResponse: false);
        } catch (_) {
          _addEvent(
            'Telemetry stop could not be acknowledged before disconnecting.',
          );
        }
      }
      await device.disconnect();
      if (mounted) {
        setState(() {
          _controlFeedbackTimer?.cancel();
          _controlPending = false;
          _streaming = false;
          _observations = null;
          _control = null;
          _device = null;
          _status = 'Disconnected. You can scan again.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Disconnect failed: $error');
    } finally {
      if (mounted) setState(() => _disconnecting = false);
    }
  }

  void _handleControlResponse(List<int> value) {
    if (value.isEmpty || !mounted) return;
    _controlFeedbackTimer?.cancel();
    setState(() => _controlPending = false);
    if (value.first == 0x80) {
      setState(() {
        _streaming = !_streaming;
        _status = _streaming ? 'Telemetry streaming' : 'Telemetry stopped';
      });
      _addEvent(
        _streaming
            ? 'ESP32 accepted start command.'
            : 'ESP32 accepted stop command.',
      );
    } else {
      _addEvent('Control response: ${_hex(value)}');
    }
  }

  void _decodeObservation(List<int> frame) {
    if (frame.length < 16 || !mounted) return;
    final code = _uint32(frame, 6);
    final mantissa = _int24(frame, 12);
    final exponent = frame[15] > 127 ? frame[15] - 256 : frame[15];
    final value = mantissa * math.pow(10, exponent);
    setState(() {
      if (code == _heartRateCode) {
        _heartRate = value.round();
      } else if (code == _spo2Code) {
        _spo2 = value.round();
      } else if (code == _temperatureCode) {
        _temperature = value.toDouble();
      } else {
        return;
      }
      _status = 'Telemetry streaming';
    });
  }

  int _uint32(List<int> data, int offset) =>
      data[offset] |
      (data[offset + 1] << 8) |
      (data[offset + 2] << 16) |
      (data[offset + 3] << 24);

  int _int24(List<int> data, int offset) {
    final value =
        data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16);
    return value & 0x800000 == 0 ? value : value - 0x1000000;
  }

  String _hex(List<int> value) =>
      value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');

  void _addEvent(String event) {
    if (!mounted) return;
    setState(() {
      _events.insert(0, event);
      if (_events.length > 5) _events.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) => GatewayView(
    status: _status,
    connected: _device != null && _observations != null,
    scanning: _scanning,
    connecting: _connecting,
    disconnecting: _disconnecting,
    streaming: _streaming,
    controlPending: _controlPending,
    scanCompleted: _scanCompleted,
    deviceName: _device?.platformName,
    deviceId: _device?.remoteId.str,
    selectedId: _selectedId,
    heartRate: _heartRate,
    spo2: _spo2,
    temperature: _temperature,
    events: _events,
    devices: [
      for (final result in _devices)
        GatewayDevice(
          name: result.device.platformName,
          id: result.device.remoteId.str,
          rssi: result.rssi,
          onConnect: () => _connect(result),
        ),
    ],
    onScan: _scan,
    onStart: () => _writeControl(0x01),
    onStop: () => _writeControl(0x02),
    onDisconnect: _disconnect,
  );
}
