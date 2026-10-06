import 'package:exploraec/bindings/places_binding.dart';
import 'package:exploraec/controllers/places_controller.dart';
import 'package:exploraec/main.dart';
import 'package:exploraec/models/place.dart';
import 'package:exploraec/screens/add_place_screen.dart';
import 'package:exploraec/screens/detail_screen.dart';
import 'package:exploraec/widgets/error_view.dart';
import 'package:exploraec/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import 'helpers/geo_fake.dart';

void main() {
  final ejemplosIniciales = List<Place>.of(lugaresEjemplo);
  final plataformaOriginal = GeolocatorPlatform.instance;
  setUp(() {
    Get.reset();
    Get.testMode = true;
    GeolocatorPlatform.instance = GeoFake()..servicioActivo = false;
    lugaresEjemplo
      ..clear()
      ..addAll(ejemplosIniciales);
  });
  tearDown(() {
    Get.reset();
    GeolocatorPlatform.instance = plataformaOriginal;
  });

  Future<PlacesController> abrirApp(WidgetTester tester) async {
    await tester.pumpWidget(const ExploraEcApp());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    return Get.find<PlacesController>();
  }

  Future<void> completarFormulario(WidgetTester tester) async {
    await tester.enterText(
        find.byKey(const ValueKey('nombre')), ' Lugar GetX ');
    await tester.enterText(find.byKey(const ValueKey('categoria')), ' Museos ');
    await tester.enterText(
      find.byKey(const ValueKey('descripcion')),
      ' Descripción de prueba con estado compartido. ',
    );
  }

  testWidgets('El binding registra una única instancia compartida al navegar', (
    tester,
  ) async {
    final instancia = await abrirApp(tester);
    PlacesBinding().dependencies();
    expect(Get.find<PlacesController>(), same(instancia));
    expect(instancia.total, 6);
    await tester.tap(find.byTooltip('Agregar lugar'));
    await tester.pumpAndSettle();
    expect(Get.find<PlacesController>(), same(instancia));
    Get.back<void>();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();
    expect(Get.find<PlacesController>(), same(instancia));
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.byType(LoadingView), findsNothing);
    expect(Get.find<PlacesController>(), same(instancia));
    expect(find.text('ExploraEC (6)'), findsOneWidget);
  });

  testWidgets('Alta reactiva actualiza 6 a 7 sin carga ni duplicación', (
    tester,
  ) async {
    final controller = await abrirApp(tester);
    final cambios = <EstadoCarga>[];
    final suscripcion = controller.estado.listen(cambios.add);
    await tester.tap(find.byTooltip('Agregar lugar'));
    await tester.pumpAndSettle();
    await completarFormulario(tester);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.byType(AddPlaceScreen), findsNothing);
    expect(find.byType(LoadingView), findsNothing);
    expect(controller.estado.value, EstadoCarga.exito);
    expect(cambios, isNot(contains(EstadoCarga.cargando)));
    expect(controller.total, 7);
    expect(find.text('ExploraEC (7)'), findsOneWidget);
    expect(find.text('Lugar agregado'), findsOneWidget);
    expect(find.text('Ya aparece en Inicio'), findsOneWidget);
    expect(controller.lugares.last.nombre, 'Lugar GetX');
    expect(controller.lugares.last.categoria, 'Museos');
    expect(lugaresEjemplo.where((lugar) => lugar.nombre == 'Lugar GetX'),
        hasLength(1));
    expect(controller.lugares.where((lugar) => lugar.nombre == 'Lugar GetX'),
        hasLength(1));
    await suscripcion.cancel();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lugar GetX'));
    await tester.pumpAndSettle();
    expect(find.byType(DetailScreen), findsOneWidget);
    expect(tester.widget<DetailScreen>(find.byType(DetailScreen)).place,
        same(controller.lugares.last));
    Get.back<void>();
    await tester.pumpAndSettle();
    final carga = controller.cargarLugares();
    await tester.pump(const Duration(seconds: 1));
    await carga;
    await tester.pumpAndSettle();
    expect(controller.total, 7);
    expect(controller.lugares.where((lugar) => lugar.nombre == 'Lugar GetX'),
        hasLength(1));
  });

  testWidgets('Guardar con un aviso previo activo vuelve a Inicio una sola vez',
      (
    tester,
  ) async {
    final controller = await abrirApp(tester);
    await tester.tap(find.byTooltip('Agregar lugar'));
    await tester.pumpAndSettle();
    await completarFormulario(tester);
    Get.snackbar('Aviso previo', 'Este aviso sigue abierto');
    Get.snackbar('Segundo aviso', 'Este aviso está en espera');
    Get.snackbar('Tercer aviso', 'Otro aviso está en espera');
    await tester.pump(const Duration(milliseconds: 350));
    expect(Get.isSnackbarOpen, isTrue);
    await tester.tap(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.byType(AddPlaceScreen), findsNothing);
    expect(find.text('ExploraEC (7)'), findsOneWidget);
    expect(controller.total, 7);
    expect(lugaresEjemplo.where((lugar) => lugar.nombre == 'Lugar GetX'),
        hasLength(1));
    expect(find.text('Lugar agregado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Worker de error muestra un aviso real en GetMaterialApp', (
    tester,
  ) async {
    final controller = await abrirApp(tester);
    controller.simular('error');
    await tester.pump();
    expect(controller.estado.value, EstadoCarga.cargando);
    expect(find.byType(LoadingView), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(controller.estado.value, EstadoCarga.error);
    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Error'), findsOneWidget);
    expect(Get.isSnackbarOpen, isTrue);
    expect(controller.mensajeError.value,
        'Exception: No se pudo conectar con el servidor (simulado)');
    // Reasignar el mismo estado no crea un segundo aviso.
    controller.estado.value = EstadoCarga.error;
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Error'), findsNothing);
    expect(Get.isSnackbarOpen, isFalse);
    controller.simular('vacio');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(controller.estado.value, EstadoCarga.exito);
    expect(controller.total, 0);
    expect(controller.mensajeError.value, isEmpty);
  });

  testWidgets('Una respuesta anterior no pisa la simulación más reciente', (
    tester,
  ) async {
    final controller = await abrirApp(tester);
    controller.simular('error');
    await tester.pump(const Duration(milliseconds: 200));
    controller.simular('normal');
    await tester.pump(const Duration(milliseconds: 800));
    expect(controller.estado.value, EstadoCarga.cargando);
    expect(find.text('Error'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(controller.estado.value, EstadoCarga.exito);
    expect(controller.total, 6);
    expect(controller.mensajeError.value, isEmpty);
    expect(find.text('Error'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final modo in ['vacio', 'error']) {
    testWidgets('Alta durante carga $modo conserva el lugar y el estado', (
      tester,
    ) async {
      final controller = await abrirApp(tester);
      controller.simular(modo);
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.estado.value, EstadoCarga.cargando);
      controller.agregarLugar(const Place(
        id: 'alta-pendiente',
        nombre: 'Alta durante carga',
        categoria: 'Museos',
        descripcion: 'Lugar guardado antes de la respuesta pendiente.',
        lat: -0.1807,
        lng: -78.4859,
      ));
      expect(controller.total, 7);
      expect(controller.estado.value, EstadoCarga.exito);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      final estadoFinal = controller.estado.value;
      final totalFinal = controller.total;
      final mensajeFinal = controller.mensajeError.value;
      final avisoAbierto = Get.isSnackbarOpen;
      // Consumir cualquier aviso antes de comprobar el resultado de la carrera.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(estadoFinal, EstadoCarga.exito);
      expect(totalFinal, 7);
      expect(mensajeFinal, isEmpty);
      expect(avisoAbierto, isFalse);
      expect(controller.lugares.last.nombre, 'Alta durante carga');
      expect(find.text('ExploraEC (7)'), findsOneWidget);
      expect(find.byType(LoadingView), findsNothing);
      expect(find.byType(ErrorView), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('onClose libera worker e ignora un error tardío sin avisos', (
    tester,
  ) async {
    final controller = await abrirApp(tester);
    controller.simular('error');
    await tester.tap(find.text('Mapa'));
    await tester.pump();
    await Get.delete<PlacesController>(force: true);
    expect(controller.isClosed, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(controller.estado.value, EstadoCarga.cargando);
    expect(controller.mensajeError.value, isEmpty);
    // Cambiar el Rx después del cierre tampoco debe invocar el worker liberado.
    controller.mensajeError.value = 'Error posterior al cierre';
    controller.estado.value = EstadoCarga.error;
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(Get.isSnackbarOpen, isFalse);
    expect(find.text('Error'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
