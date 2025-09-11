import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auxilia_app/main.dart';

void main() {
  testWidgets('La app carga sin errores', (WidgetTester tester) async {
    // Construye la app y simula un frame
    await tester.pumpWidget(const AuxiliaApp());

    // Verifica que el título del AppBar esté presente
    expect(find.text('Diagnóstico IA'), findsOneWidget);
  });
}
