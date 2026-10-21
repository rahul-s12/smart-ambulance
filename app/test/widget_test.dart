import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ambulance_app/main.dart';

void main() {
  testWidgets('shows the Smart Ambulance gateway screen', (tester) async {
    await tester.pumpWidget(const SmartAmbulanceApp());

    expect(find.text('Smart Ambulance'), findsOneWidget);
    expect(find.text('Scan for Smart_Ambulance'), findsOneWidget);
  });
}
