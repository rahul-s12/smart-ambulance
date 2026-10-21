import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ambulance_app/main.dart';

void main() {
  testWidgets('shows the disconnected gateway without claiming live data', (
    tester,
  ) async {
    await tester.pumpWidget(const SmartAmbulanceApp());
    expect(find.text('Smart Ambulance'), findsOneWidget);
    expect(find.text('Find device'), findsOneWidget);
    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('Streaming'), findsNothing);
    expect(find.byTooltip('Find device'), findsOneWidget);
  });

  for (final width in [320.0, 390.0, 800.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('gateway fits width $width at text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const GatewayPage(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'scan is guarded while permission is pending and recovers on denial',
    (tester) async {
      const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
      final pending = Completer<Map<int, int>>();
      var requests = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) {
        if (call.method == 'requestPermissions') {
          requests++;
          return pending.future;
        }
        return Future.value(null);
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(const SmartAmbulanceApp());
      await tester.tap(find.text('Find device'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(requests, 1);
      pending.complete({28: 0, 30: 0, 3: 0});
      await tester.pumpAndSettle();
      expect(
        find.text('Bluetooth permission is required to scan.'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(find.text('Streaming'), findsNothing);
    },
  );
}
