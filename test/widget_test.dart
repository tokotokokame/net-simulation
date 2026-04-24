// test/widget_test.dart
// Smoke test for Net.Simulation v4 Phase 1.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:net_simulation/app/app.dart';

void main() {
  testWidgets('App launches and shows topology editor stub',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: NetSimulationApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('New Topology'), findsOneWidget);
  });
}
