import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pressure_monitor/main.dart';

void main() {
  testWidgets('Dashboard marks disconnected pressure as unavailable', (tester) async {
    await tester.pumpWidget(const PressureApp());
    expect(find.text('Lectura activa'), findsOneWidget);
    expect(find.text('—'), findsNothing);

    await tester.scrollUntilVisible(find.byType(DropdownButtonFormField<DemoState>), 250);
    await tester.tap(find.byType(DropdownButtonFormField<DemoState>));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Pérdida de conexión').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Desconectado'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
