import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _ink = Color(0xff080f1a);
const _surface = Color(0xff121e2e);
const _line = Color(0xff29394d);
const _muted = Color(0xff9caec5);
const _blue = Color(0xff8abaff);
const _green = Color(0xff8cd9b7);
const _amber = Color(0xffffce8a);
const _red = Color(0xffffa6ac);

ThemeData get gatewayTheme => ThemeData(
  useMaterial3: true,
  fontFamily: 'Roboto',
  brightness: Brightness.dark,
  scaffoldBackgroundColor: _ink,
  colorScheme: const ColorScheme.dark(
    primary: _blue,
    onPrimary: Color(0xff082244),
    surface: _surface,
    onSurface: Color(0xffedf3fc),
    secondary: _green,
    error: _red,
    outline: _line,
  ),
  dividerTheme: const DividerThemeData(color: _line, thickness: 1),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 54),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      textStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 54),
      padding: const EdgeInsets.all(17),
      foregroundColor: _blue,
      side: const BorderSide(color: _line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
);

Duration _motion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : const Duration(milliseconds: 220);

/// Presentation-only device data. The callback retains the real BLE operation.
class GatewayDevice {
  const GatewayDevice({
    required this.name,
    required this.id,
    required this.rssi,
    required this.onConnect,
  });
  final String name, id;
  final int rssi;
  final VoidCallback onConnect;
}

/// A single-screen view of existing gateway state; owns no BLE state or timers.
class GatewayView extends StatelessWidget {
  const GatewayView({
    super.key,
    required this.status,
    required this.connected,
    required this.scanning,
    required this.connecting,
    required this.disconnecting,
    required this.streaming,
    required this.controlPending,
    required this.scanCompleted,
    required this.devices,
    required this.events,
    required this.onScan,
    required this.onStart,
    required this.onStop,
    required this.onDisconnect,
    this.deviceName,
    this.deviceId,
    this.selectedId,
    this.heartRate,
    this.spo2,
    this.temperature,
  });
  final String status;
  final bool connected,
      scanning,
      connecting,
      disconnecting,
      streaming,
      controlPending,
      scanCompleted;
  final String? deviceName, deviceId, selectedId;
  final int? heartRate, spo2;
  final double? temperature;
  final List<GatewayDevice> devices;
  final List<String> events;
  final VoidCallback onScan, onStart, onStop, onDisconnect;

  bool get busy => scanning || connecting || disconnecting;
  String get stateLabel => disconnecting
      ? 'Disconnecting'
      : connecting
      ? 'Connecting'
      : scanning
      ? 'Scanning'
      : connected && streaming
      ? 'Streaming'
      : connected
      ? 'Connected'
      : 'Disconnected';
  bool get needsAttention =>
      status.contains('failed') ||
      status.contains('permission') ||
      status.contains('missing') ||
      status.contains('not found') ||
      status.contains('Turn on Bluetooth') ||
      status.contains('No control acknowledgement');

  // Keep actionable feedback; routine progress is already shown by the state
  // indicator, action button, or empty state.
  bool get showStatus =>
      !connecting &&
      !disconnecting &&
      !controlPending &&
      ![
        'Ready to scan',
        'Scanning for',
        'Scan complete.',
        'No matching devices found.',
        'Connected and ready',
        'Telemetry streaming',
        'Telemetry stopped',
        'Disconnected.',
        'Start command sent',
        'Stop command sent',
      ].any(status.startsWith);

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: _ink,
      systemNavigationBarColor: _ink,
    ),
    child: Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(onScan: busy ? null : onScan),
                  const SizedBox(height: 22),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _StateChip(
                      label: stateLabel,
                      active: connected && streaming,
                      busy: busy,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (MediaQuery.disableAnimationsOf(context))
                    connected ? _monitor(context) : _connection(context)
                  else
                    AnimatedSize(
                      duration: _motion(context),
                      alignment: Alignment.topCenter,
                      child: connected
                          ? _monitor(context)
                          : _connection(context),
                    ),
                  if (events.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _Activity(events: events),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _connection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xff344c6d)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: _ConnectionSymbol(active: scanning || connecting)),
            const SizedBox(height: 22),
            Text(
              connecting
                  ? 'Connecting…'
                  : scanning
                  ? 'Finding devices…'
                  : devices.isNotEmpty
                  ? 'Select a device'
                  : 'Ready to connect',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 27,
                height: 1.15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: busy ? null : onScan,
              icon: scanning
                  ? const _BusyIndicator()
                  : const Icon(Icons.bluetooth_searching, size: 20),
              label: Text(
                scanning ? 'Scanning…' : 'Find device',
                textAlign: TextAlign.center,
              ),
            ),
            if (showStatus) ...[
              const SizedBox(height: 16),
              _StatusMessage(status: status, attention: needsAttention),
            ],
          ],
        ),
      ),
      if (devices.isNotEmpty) ...[
        const SizedBox(height: 24),
        const _SectionLabel(title: 'Nearby devices'),
        const SizedBox(height: 12),
        for (final device in devices)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DeviceTile(
              device: device,
              selected: device.id == selectedId,
              pending: device.id == selectedId && connecting,
              enabled: !connecting && !disconnecting,
            ),
          ),
      ] else if (scanCompleted && !scanning && !connecting) ...[
        const SizedBox(height: 16),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.search_off_rounded, color: _muted, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No matching devices found',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Keep Smart_Ambulance powered on and nearby.',
                    style: TextStyle(color: _muted, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ],
  );

  Widget _monitor(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Patient vitals',
        style: TextStyle(
          fontSize: 29,
          letterSpacing: -0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        deviceName?.isNotEmpty == true ? deviceName! : 'Health sensor',
        style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
      ),
      const SizedBox(height: 16),
      const Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.science_outlined, size: 16, color: _amber),
          Text(
            'Simulated data',
            style: TextStyle(
              color: _amber,
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _VitalsGrid(heartRate: heartRate, spo2: spo2, temperature: temperature),
      if (heartRate == null && spo2 == null && temperature == null) ...[
        const SizedBox(height: 12),
        const Text(
          'Waiting for readings…',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
      ] else if (!streaming) ...[
        const SizedBox(height: 12),
        const Text(
          'Stopped · Showing last readings',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
      ],
      if (showStatus) ...[
        const SizedBox(height: 16),
        _StatusMessage(status: status, attention: needsAttention),
      ],
      const SizedBox(height: 20),
      LayoutBuilder(
        builder: (context, constraints) {
          final start = FilledButton.icon(
            onPressed: streaming || controlPending || busy ? null : onStart,
            icon: controlPending
                ? const _BusyIndicator()
                : const Icon(Icons.play_arrow_rounded),
            label: Text(
              controlPending ? 'Please wait…' : 'Start',
              textAlign: TextAlign.center,
            ),
          );
          final stop = OutlinedButton.icon(
            onPressed: streaming && !controlPending && !busy ? onStop : null,
            style: streaming && !controlPending
                ? OutlinedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: _ink,
                  )
                : null,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop'),
          );
          final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
          if (constraints.maxWidth < 370 * scale) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [start, const SizedBox(height: 10), stop],
            );
          }
          return Row(
            children: [
              Expanded(flex: 2, child: start),
              const SizedBox(width: 12),
              Expanded(child: stop),
            ],
          );
        },
      ),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: disconnecting || connecting ? null : onDisconnect,
          style: TextButton.styleFrom(foregroundColor: _muted),
          icon: disconnecting
              ? const _BusyIndicator()
              : const Icon(Icons.link_off, size: 18),
          label: Text(disconnecting ? 'Disconnecting…' : 'Disconnect'),
        ),
      ),
    ],
  );
}

class _Header extends StatelessWidget {
  const _Header({this.onScan});
  final VoidCallback? onScan;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 42,
        height: 48,
        decoration: BoxDecoration(
          color: _blue,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.add_rounded, color: _ink, size: 32),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart Ambulance',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 19,
                letterSpacing: -0.5,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      IconButton.outlined(
        onPressed: onScan,
        tooltip: 'Find device',
        style: IconButton.styleFrom(
          side: const BorderSide(color: _line),
          minimumSize: const Size(48, 48),
        ),
        icon: const Icon(Icons.bluetooth_searching, color: _blue, size: 22),
      ),
    ],
  );
}

class _StateChip extends StatelessWidget {
  const _StateChip({
    required this.label,
    required this.active,
    required this.busy,
  });
  final String label;
  final bool active, busy;
  @override
  Widget build(BuildContext context) {
    final color = active
        ? _green
        : busy
        ? _blue
        : _muted;
    return Semantics(
      liveRegion: true,
      child: AnimatedContainer(
        duration: _motion(context),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active
                  ? Icons.sensors
                  : busy
                  ? Icons.more_horiz
                  : Icons.circle,
              size: active || busy ? 14 : 6,
              color: color,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionSymbol extends StatelessWidget {
  const _ConnectionSymbol({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 152,
    height: 152,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 152,
          height: 152,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _line),
          ),
        ),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _line),
          ),
        ),
        if (active)
          Positioned.fill(
            child: CircularProgressIndicator(
              value: MediaQuery.disableAnimationsOf(context) ? 0.7 : null,
              strokeWidth: 2,
              color: _blue,
            ),
          ),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: const Color(0xff1d3350),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xff42628b)),
          ),
          child: const Icon(Icons.bluetooth_rounded, size: 46, color: _blue),
        ),
        Positioned(
          bottom: 6,
          right: 15,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              active ? Icons.wifi_tethering : Icons.link,
              size: 18,
              color: _blue,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.status, required this.attention});
  final String status;
  final bool attention;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          attention ? Icons.error_outline : Icons.info_outline,
          size: 16,
          color: attention ? _red : _muted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            switch (status) {
              _ when status.startsWith('Scan failed:') =>
                'Could not find devices. Try again.',
              _ when status.startsWith('Connection failed:') =>
                'Could not connect. Try again.',
              _ when status.startsWith('Control command failed:') =>
                'Command failed. Try again.',
              _ when status.startsWith('Disconnect failed:') =>
                'Could not disconnect. Try again.',
              _ when status.startsWith('GHSS') =>
                'This device does not support patient vitals.',
              _ => status,
            },
            style: TextStyle(
              fontSize: 12,
              color: attention ? _red : _muted,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.selected,
    required this.pending,
    required this.enabled,
  });
  final GatewayDevice device;
  final bool selected, pending, enabled;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: _motion(context),
    decoration: BoxDecoration(
      color: selected ? const Color(0xff1b304b) : _surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: selected ? _blue : _line),
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? device.onConnect : null,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.memory_rounded, color: _blue, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name.isEmpty
                          ? 'Unnamed health sensor'
                          : device.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      device.id,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    if (pending) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Connecting…',
                        style: TextStyle(color: _blue, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (pending)
                const _BusyIndicator()
              else
                const Icon(Icons.chevron_right, color: _muted, size: 20),
            ],
          ),
        ),
      ),
    ),
  );
}

class _VitalsGrid extends StatelessWidget {
  const _VitalsGrid({
    required this.heartRate,
    required this.spo2,
    required this.temperature,
  });
  final int? heartRate, spo2;
  final double? temperature;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final primary = _VitalTile(
        label: 'Heart rate',
        value: heartRate?.toString() ?? '—',
        unit: 'BPM',
        icon: Icons.favorite_outline_rounded,
        primary: true,
      );
      final oxygen = _VitalTile(
        label: 'SpO2',
        value: spo2?.toString() ?? '—',
        unit: '%',
        icon: Icons.water_drop_outlined,
      );
      final temperatureTile = _VitalTile(
        label: 'Temperature',
        value: temperature?.toStringAsFixed(2) ?? '—',
        unit: '°C',
        icon: Icons.thermostat_rounded,
      );
      if (constraints.maxWidth >= 650 * scale) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: primary),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: Column(
                children: [oxygen, const SizedBox(height: 12), temperatureTile],
              ),
            ),
          ],
        );
      }
      return Column(
        children: [
          primary,
          const SizedBox(height: 12),
          if (constraints.maxWidth >= 330 * scale)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: oxygen),
                const SizedBox(width: 12),
                Expanded(child: temperatureTile),
              ],
            )
          else ...[
            oxygen,
            const SizedBox(height: 12),
            temperatureTile,
          ],
        ],
      );
    },
  );
}

class _VitalTile extends StatelessWidget {
  const _VitalTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.primary = false,
  });
  final String label, value, unit;
  final IconData icon;
  final bool primary;
  @override
  Widget build(BuildContext context) {
    final foreground = primary
        ? const Color(0xff122f52)
        : const Color(0xffedf3fc);
    final secondary = primary ? const Color(0xff405b79) : _muted;
    return Semantics(
      label:
          '$label: ${value == '—' ? 'No reading yet' : '$value $unit'}. Simulated data.',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(primary ? 24 : 18),
        decoration: BoxDecoration(
          color: primary ? const Color(0xffd6e6ff) : _surface,
          borderRadius: BorderRadius.circular(primary ? 24 : 20),
          border: primary ? null : Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                      fontSize: primary ? 16 : 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  icon,
                  color: primary ? const Color(0xff315f96) : _blue,
                  size: primary ? 25 : 20,
                ),
              ],
            ),
            SizedBox(height: primary ? 24 : 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
                final fontSize = primary
                    ? (constraints.maxWidth / (3.5 * scale)).clamp(36.0, 78.0)
                    : (constraints.maxWidth / (3.4 * scale)).clamp(24.0, 36.0);
                return AnimatedSwitcher(
                  duration: _motion(context),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, ?current],
                  ),
                  child: Text(
                    value,
                    key: ValueKey(value),
                    style: TextStyle(
                      fontSize: fontSize,
                      height: 1,
                      letterSpacing: primary ? -3 : -1,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              unit,
              style: TextStyle(
                color: secondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );
}

class _Activity extends StatelessWidget {
  const _Activity({required this.events});
  final List<String> events;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _SectionLabel(title: 'Recent activity'),
      const SizedBox(height: 14),
      const Divider(height: 1),
      for (final event in events) _EventRow(event: event),
    ],
  );
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
  final String event;
  @override
  Widget build(BuildContext context) {
    final failure = event.contains('failed') || event.contains('could not');
    final success = event.contains('accepted') || event.contains('enabled');
    final color = failure
        ? _red
        : success
        ? _green
        : _muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              failure
                  ? Icons.priority_high_rounded
                  : success
                  ? Icons.check_rounded
                  : Icons.more_horiz,
              size: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              switch (event) {
                'ESP32 accepted start command.' => 'Monitoring started',
                'ESP32 accepted stop command.' => 'Monitoring stopped',
                'GHSS notifications and control indications enabled.' =>
                  'Device ready',
                'Telemetry stop could not be acknowledged before disconnecting.' =>
                  'Stop was not confirmed before disconnecting',
                _ when event.startsWith('Control response:') =>
                  'Device response received',
                _ => event,
              },
              style: const TextStyle(
                fontSize: 12,
                height: 1.6,
                color: Color(0xffc3cfe0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusyIndicator extends StatelessWidget {
  const _BusyIndicator();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(
      value: MediaQuery.disableAnimationsOf(context) ? 0.7 : null,
      strokeWidth: 2,
      color: _blue,
    ),
  );
}
