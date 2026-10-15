import 'package:exploraec/screens/gastos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'helpers/sesion10_fake.dart';

void main() {
  late EntornoSesion10 e;

  Future<void> montar(WidgetTester tester, {ServidorSesion10? servidor}) async {
    await tester.runAsync(() async {
      e = await EntornoSesion10.crear(servidor: servidor);
      await e.entrar();
    });
    addTearDown(() => tester.runAsync(e.cerrar));
    await tester.pumpWidget(const GetMaterialApp(home: GastosScreen()));
    await tester.pumpAndSettle();
    expect(e.auth.usuario.value?.id, 1);
    expect(e.gastos.sesionActiva.value, isTrue);
  }

  Finder chip(String categoria) => find.byKey(ValueKey('filtro-$categoria'));
  Finder tarjeta(int id) => find.byKey(ValueKey('gasto-$id'));

  testWidgets('Todas/comida cambia tarjetas sin alterar crudos, total ni Hive',
      (tester) async {
    await montar(tester);
    final ids = e.gastos.gastos.map((g) => g.id).toList();
    final suma = e.gastos.gastos.fold<double>(0, (s, g) => s + g.monto);
    final lecturas = e.servidor.consultas.length;
    final cache = e.idsCache;
    expect(tarjeta(1), findsOneWidget);
    expect(tarjeta(2), findsOneWidget);
    expect(chip('entretenimiento'), findsNothing);
    expect(chip('otros'), findsNothing);

    await tester.tap(chip('comida'));
    await tester.pumpAndSettle();
    expect(tarjeta(1), findsOneWidget);
    expect(tarjeta(2), findsNothing);
    expect(e.gastos.gastosFiltrados.map((g) => g.id), [1]);
    expect(e.gastos.gastos.map((g) => g.id), ids);
    expect(e.gastos.gastos.fold<double>(0, (s, g) => s + g.monto), suma);
    expect(e.gastos.totalEnServidor.value, 2);
    expect(e.idsCache, cache);
    expect(e.servidor.consultas.length, lecturas);

    await tester.tap(chip('todas'));
    await tester.pumpAndSettle();
    expect(tarjeta(1), findsOneWidget);
    expect(tarjeta(2), findsOneWidget);
    expect(e.gastos.gastosFiltrados.map((g) => g.id), ids);
    expect(e.idsCache, cache);
    expect(e.servidor.consultas.length, lecturas);
  });

  testWidgets('CRUD incorpora categorías y resuelve la última que desaparece',
      (tester) async {
    await montar(tester);
    await tester.runAsync(
        () => e.gastos.crear('Entrada fixture', 7, 'entretenimiento'));
    await tester.pumpAndSettle();
    expect(chip('entretenimiento'), findsOneWidget);
    await tester.tap(chip('entretenimiento'));
    await tester.pumpAndSettle();
    expect(tarjeta(1000), findsOneWidget);
    expect(tarjeta(1), findsNothing);
    await tester.runAsync(() => e.gastos.eliminar(1000));
    await tester.pumpAndSettle();
    expect(chip('entretenimiento'), findsNothing);
    expect(e.gastos.filtroCategoria.value, isNull);
    expect(tarjeta(1), findsOneWidget);
    expect(tarjeta(2), findsOneWidget);

    await tester.tap(chip('comida'));
    await tester.pumpAndSettle();
    await tester
        .runAsync(() => e.gastos.actualizar(1, {'categoria': 'transporte'}));
    await tester.pumpAndSettle();
    expect(chip('comida'), findsNothing);
    expect(e.gastos.filtroCategoria.value, isNull);
    expect(tester.widget<ChoiceChip>(chip('todas')).selected, isTrue);
    expect(e.gastos.categoriasDisponibles, ['transporte']);
    expect(e.gastos.categorias,
        ['comida', 'transporte', 'entretenimiento', 'otros']);
    expect(e.idsCache, [1, 2]);
    expect(e.gastos.totalEnServidor.value, 2);
  });

  testWidgets(
      'Cerrar sesión y entrar con otra cuenta no conserva filtro ni datos',
      (tester) async {
    await montar(tester);
    await tester.tap(chip('comida'));
    await tester.pumpAndSettle();
    // PopupMenu registra su continuación al abrirse: crearla fuera de FakeAsync.
    await tester
        .runAsync(() => tester.tap(find.byTooltip('Opciones de gastos')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Cerrar sesión'));
      await e.gastos.cierrePendiente;
    });
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(e.gastos.filtroCategoria.value, isNull);
    expect(e.gastos.gastos, isEmpty);
    expect(tarjeta(1), findsNothing);
    expect(Hive.isBoxOpen('gastos_1'), isFalse);
    expect(await tester.runAsync(() => Hive.boxExists('gastos_1')), isFalse);

    await tester.runAsync(() => e.entrar('dos@example.test'));
    await tester.pumpAndSettle();
    expect(e.auth.usuario.value?.id, 2);
    expect(e.gastos.filtroCategoria.value, isNull);
    expect(tester.widget<ChoiceChip>(chip('todas')).selected, isTrue);
    expect(chip('comida'), findsNothing);
    expect(chip('otros'), findsOneWidget);
    expect(tarjeta(90), findsOneWidget);
    expect(tarjeta(1), findsNothing);
    expect(tarjeta(2), findsNothing);
    expect(e.idsCache, [90]);
    expect(e.gastos.gastos.map((g) => g.id), [90]);
  });

  testWidgets('Cambiar de usuario directamente también restablece la selección',
      (tester) async {
    await montar(tester);
    await tester.tap(chip('comida'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => e.entrar('dos@example.test'));
    await tester.pumpAndSettle();
    expect(e.auth.usuario.value?.id, 2);
    expect(e.gastos.filtroCategoria.value, isNull);
    expect(e.gastos.gastos.map((g) => g.id), [90]);
    expect(tarjeta(90), findsOneWidget);
    expect(tarjeta(1), findsNothing);
    expect(e.idsCache, [90]);
  });

  testWidgets('Sin red conserva filtro, tarjetas y caché completa',
      (tester) async {
    await montar(tester);
    await tester.tap(chip('comida'));
    await tester.pumpAndSettle();
    final cache = e.idsCache;
    e.servidor.sinRed = true;
    await tester.runAsync(e.gastos.cargarGastos);
    await tester.pumpAndSettle();
    expect(e.gastos.desdeCache.value, isTrue);
    expect(find.textContaining('Sin conexión'), findsOneWidget);
    expect(tarjeta(1), findsOneWidget);
    expect(tarjeta(2), findsNothing);
    expect(e.idsCache, cache);
    await tester.tap(chip('todas'));
    await tester.pumpAndSettle();
    expect(tarjeta(2), findsOneWidget);
    expect(e.gastos.gastos.length, 2);
    expect(e.gastos.totalEnServidor.value, 2);
    e.servidor.sinRed = false;
    await tester.runAsync(e.gastos.cargarGastos);
    await tester.pumpAndSettle();
    expect(e.gastos.desdeCache.value, isFalse);
    expect(find.textContaining('Sin conexión'), findsNothing);
  });

  testWidgets(
      'Cero coincidencias permite paginar y Todas devuelve cada tarjeta',
      (tester) async {
    final servidor = ServidorSesion10()..limitePagina = 2;
    servidor.porUsuario[1] = [
      gastoS10(1, 'comida'),
      gastoS10(2, 'comida'),
      gastoS10(3, 'transporte'),
    ];
    await montar(tester, servidor: servidor);
    expect(chip('transporte'), findsNothing);
    expect(e.gastos.categoriasDisponibles, ['comida']);
    // Estado defensivo de selección sin coincidencias; no lo produce build.
    e.gastos.filtroCategoria.value = 'transporte';
    await tester.pumpAndSettle();
    expect(
        find.textContaining('No hay gastos de esta categoría'), findsOneWidget);
    expect(tarjeta(1), findsNothing);
    expect(find.text('Cargar más'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Cargar más'));
      for (var i = 0; i < 100 && e.gastos.cargandoMas.value; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(e.gastos.gastos.length, 3);
    expect(e.gastos.cargandoMas.value, isFalse);
    expect(e.gastos.hayMas, isFalse);
    expect(e.servidor.consultas.map((c) => c.skip), [0, 2]);
    expect(e.servidor.consultas.every((c) => c.limit == 20), isTrue);
    expect(chip('transporte'), findsOneWidget);
    expect(tarjeta(3), findsOneWidget);
    expect(tarjeta(1), findsNothing);
    expect(e.idsCache, [1, 2, 3]);
    await tester.tap(chip('todas'));
    await tester.pumpAndSettle();
    for (final id in [1, 2, 3]) {
      expect(tarjeta(id), findsOneWidget);
    }
    expect(find.text('Cargar más'), findsNothing);
  });
}
