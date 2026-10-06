import 'package:exploraec/playground/contador_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Contador incrementa, conserva estado y libera el ciclo de vida',
      (
    tester,
  ) async {
    final mensajes = <String>[];
    final salidaOriginal = debugPrint;
    debugPrint = (mensaje, {wrapWidth}) {
      if (mensaje != null) mensajes.add(mensaje);
    };
    addTearDown(() => debugPrint = salidaOriginal);

    await tester.pumpWidget(const MaterialApp(home: ContadorDemo()));
    expect(find.text('0'), findsOneWidget);
    expect(
      mensajes.where((mensaje) => mensaje.startsWith('initState:')),
      hasLength(1),
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    // Reensamblar el árbol reproduce la conservación del State en hot reload.
    final reensamblado = tester.binding.reassembleApplication();
    await tester.pump();
    await reensamblado;
    expect(find.text('2'), findsOneWidget);
    expect(
      mensajes.where((mensaje) => mensaje.startsWith('initState:')),
      hasLength(1),
    );

    await tester.pumpWidget(const SizedBox());
    expect(mensajes, contains('dispose: el contador se cierra en 2'));
    await tester.pumpWidget(const MaterialApp(home: ContadorDemo()));
    expect(find.text('0'), findsOneWidget);
    expect(
      mensajes.where((mensaje) => mensaje.startsWith('initState:')),
      hasLength(2),
    );
    await tester.pumpWidget(const SizedBox());
    expect(mensajes, contains('dispose: el contador se cierra en 0'));
    debugPrint = salidaOriginal;
  });
}
