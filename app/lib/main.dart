import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff00695c)),
          useMaterial3: true,
        ),
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
    final granted = statuses[Permission.bluetoothScan]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true;
    if (!granted && mounted) {
      setState(() => _status = 'Bluetooth permission is required to scan.');
    }
    return granted;
  }

  Future<void> _scan() async {
    if (!await _requestPermissions()) return;
    // adapterStateNow begins as `unknown` until the Android plugin has read
    // the adapter. Await the stream's first value instead of misreporting it
    // as Bluetooth being off.
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      setState(() => _status = _adapterStateMessage(adapterState));
      return;
    }
    await FlutterBluePlus.stopScan();
    setState(() {
      _devices.clear();
      _scanning = true;
      _status = 'Scanning for Generic Health Sensor Service…';
    });
    try {
      await FlutterBluePlus.startScan(
        withServices: [_healthService],
        timeout: const Duration(seconds: 10),
      );
      if (mounted) setState(() => _status = 'Scan complete. Select your ESP32.');
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
    await FlutterBluePlus.stopScan();
    await _connectionSubscription?.cancel();
    await _observationsSubscription?.cancel();
    await _controlSubscription?.cancel();
    setState(() {
      _connecting = true;
      _status = 'Connecting to ${result.device.platformName}…';
      _streaming = false;
      _observations = null;
      _control = null;
    });
    try {
      await result.device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
      );
      _device = result.device;
      _connectionSubscription = _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && mounted) {
          setState(() {
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
      if (characteristic.uuid == _liveObservations) _observations = characteristic;
      if (characteristic.uuid == _controlPoint) _control = characteristic;
    }
    if (_observations == null || _control == null) {
      setState(() => _status = 'GHSS is missing required characteristics.');
      return;
    }
    _observationsSubscription = _observations!.lastValueStream.listen(_decodeObservation);
    _controlSubscription = _control!.lastValueStream.listen(_handleControlResponse);
    await _observations!.setNotifyValue(true);
    await _control!.setNotifyValue(true);
    if (mounted) {
      setState(() => _status = 'Connected and ready to start telemetry.');
      _addEvent('GHSS notifications and control indications enabled.');
    }
  }

  Future<void> _writeControl(int command) async {
    final control = _control;
    if (control == null) return;
    try {
      await control.write([command], withoutResponse: false);
      if (mounted) {
        setState(() => _status = command == 0x01
            ? 'Start command sent; waiting for acknowledgement…'
            : 'Stop command sent; waiting for acknowledgement…');
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Control command failed: $error');
    }
  }

  void _handleControlResponse(List<int> value) {
    if (value.isEmpty || !mounted) return;
    if (value.first == 0x80) {
      setState(() {
        _streaming = !_streaming;
        _status = _streaming ? 'Telemetry streaming' : 'Telemetry stopped';
      });
      _addEvent(_streaming ? 'ESP32 accepted start command.' : 'ESP32 accepted stop command.');
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
      data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24);

  int _int24(List<int> data, int offset) {
    final value = data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16);
    return value & 0x800000 == 0 ? value : value - 0x1000000;
  }

  String _hex(List<int> value) => value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');

  void _addEvent(String event) {
    if (!mounted) return;
    setState(() {
      _events.insert(0, event);
      if (_events.length > 5) _events.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    final connected = _device != null && _observations != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Ambulance'),
        actions: [
          IconButton(onPressed: _scanning || _connecting ? null : _scan, icon: const Icon(Icons.bluetooth_searching)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusCard(status: _status, connected: connected, streaming: _streaming),
          const SizedBox(height: 16),
          if (!connected) ...[
            FilledButton.icon(
              onPressed: _scanning || _connecting ? null : _scan,
              icon: Icon(_scanning ? Icons.hourglass_top : Icons.search),
              label: Text(_scanning ? 'Scanning…' : 'Scan for Smart_Ambulance'),
            ),
            const SizedBox(height: 12),
            ..._devices.map((result) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.monitor_heart_outlined),
                    title: Text(result.device.platformName.isEmpty ? 'Unnamed health sensor' : result.device.platformName),
                    subtitle: Text('${result.device.remoteId.str}  •  ${result.rssi} dBm'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _connecting ? null : () => _connect(result),
                  ),
                )),
          ] else ...[
            _VitalsGrid(heartRate: _heartRate, spo2: _spo2, temperature: _temperature),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: _streaming ? null : () => _writeControl(0x01), icon: const Icon(Icons.play_arrow), label: const Text('Start telemetry'))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(onPressed: _streaming ? () => _writeControl(0x02) : null, icon: const Icon(Icons.stop), label: const Text('Stop'))),
            ]),
          ],
          const SizedBox(height: 24),
          Text('Gateway events', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_events.isEmpty) const Text('No BLE events yet.') else ..._events.map((event) => ListTile(dense: true, leading: const Icon(Icons.check_circle_outline, size: 18), title: Text(event))),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.connected, required this.streaming});
  final String status;
  final bool connected;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final color = streaming ? Colors.green : connected ? Colors.orange : Colors.blueGrey;
    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(streaming ? Icons.sensors : Icons.bluetooth, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(status)),
        ]),
      ),
    );
  }
}

class _VitalsGrid extends StatelessWidget {
  const _VitalsGrid({required this.heartRate, required this.spo2, required this.temperature});
  final int? heartRate;
  final int? spo2;
  final double? temperature;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: .82,
        children: [
          _VitalTile(label: 'Heart rate', value: heartRate?.toString() ?? '—', unit: 'bpm', icon: Icons.favorite),
          _VitalTile(label: 'SpO₂', value: spo2?.toString() ?? '—', unit: '%', icon: Icons.bloodtype),
          _VitalTile(label: 'Temperature', value: temperature?.toStringAsFixed(2) ?? '—', unit: '°C', icon: Icons.thermostat),
        ],
      );
}

class _VitalTile extends StatelessWidget {
  const _VitalTile({required this.label, required this.value, required this.unit, required this.icon});
  final String label;
  final String value;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(unit, style: Theme.of(context).textTheme.labelSmall),
          ]),
        ),
      );
}
