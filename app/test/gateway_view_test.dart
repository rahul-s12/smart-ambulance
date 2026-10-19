import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ambulance_app/gateway_view.dart';

GatewayView gatewayForTest({
  bool connected = true,
  bool streaming = false,
  bool scanning = false,
  bool connecting = false,
  bool pending = false,
  bool readings = true,
  bool scanCompleted = false,
  List<GatewayDevice> devices = const [],
  VoidCallback? onStart,
  VoidCallback? onStop,
  VoidCallback? onDisconnect,
}) => GatewayView(
  status: streaming
      ? 'Telemetry streaming'
      : connected
      ? 'Connected and ready to start telemetry.'
      : 'Ready to scan for Smart_Ambulance',
  connected: connected,
  scanning: scanning,
  connecting: connecting,
  disconnecting: false,
  streaming: streaming,
  controlPending: pending,
  scanCompleted: scanCompleted,
  devices: devices,
  deviceName: 'Smart_Ambulance',
  deviceId: 'AA:BB:CC:DD:EE:FF',
  selectedId: connecting ? 'AA:BB:CC:DD:EE:FF' : null,
  heartRate: readings ? 78 : null,
  spo2: readings ? 98 : null,
  temperature: readings ? 36.75 : null,
  events: !connected
      ? const []
      : const [
          'ESP32 accepted start command.',
          'GHSS notifications and control indications enabled.',
          'Telemetry stop could not be acknowledged before disconnecting.',
        ],
  onScan: () {},
  onStart: onStart ?? () {},
  onStop: onStop ?? () {},
  onDisconnect: onDisconnect ?? () {},
);

void main() {
  for (final size in [
    const Size(320, 740),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('monitor fits $size at $scale text scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: gatewayTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: gatewayForTest(streaming: true),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('78'), findsOneWidget);
        expect(find.text('98'), findsOneWidget);
        expect(find.text('36.75'), findsOneWidget);
        expect(find.text('Simulated data'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Disconnect'), 180);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('waiting values and semantics do not invent readings', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(theme: gatewayTheme, home: gatewayForTest(readings: false)),
    );
    expect(find.text('Waiting for readings…'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(3));
    expect(
      find.bySemanticsLabel('Heart rate: No reading yet. Simulated data.'),
      findsOneWidget,
    );
    expect(find.text('Streaming'), findsNothing);
    semantics.dispose();
  });

  testWidgets('controls follow confirmed streaming and pending state', (
    tester,
  ) async {
    var starts = 0;
    var stops = 0;
    Future<void> show({bool streaming = false, bool pending = false}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: gatewayTheme,
          home: gatewayForTest(
            streaming: streaming,
            pending: pending,
            onStart: () => starts++,
            onStop: () => stops++,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show();
    await tester.ensureVisible(find.text('Start'));
    await tester.tap(find.text('Start'));
    expect(starts, 1);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    await show(streaming: true);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Stop'));
    await tester.tap(find.text('Stop'));
    expect(stops, 1);
    // Reduced motion keeps pending feedback visible without a repeating ticker.
    await tester.pumpWidget(
      MaterialApp(
        theme: gatewayTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: gatewayForTest(streaming: true, pending: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(find.text('Please wait…'), findsOneWidget);
  });

  testWidgets('scan motion ends and empty results have a clear state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: gatewayTheme,
        home: gatewayForTest(connected: false, scanning: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Connected'), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        theme: gatewayTheme,
        home: gatewayForTest(connected: false, scanCompleted: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No matching devices found'), findsOneWidget);
  });

  testWidgets(
    'whole device row selects the device and disables while connecting',
    (tester) async {
      var connections = 0;
      final devices = [
        GatewayDevice(
          name: 'Smart_Ambulance',
          id: 'AA:BB:CC:DD:EE:FF',
          rssi: -61,
          onConnect: () => connections++,
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: gatewayTheme,
          home: gatewayForTest(connected: false, devices: devices),
        ),
      );
      await tester.ensureVisible(find.text('Smart_Ambulance'));
      await tester.tap(find.text('Smart_Ambulance'));
      expect(connections, 1);
      await tester.pumpWidget(
        MaterialApp(
          theme: gatewayTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: gatewayForTest(
            connected: false,
            connecting: true,
            devices: devices,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Smart_Ambulance'));
      await tester.tap(find.text('Smart_Ambulance'));
      expect(connections, 1);
      expect(find.text('Connected'), findsNothing);
    },
  );
}
