import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:exploraec/controllers/places_controller.dart';
import 'package:exploraec/models/place.dart';
import 'package:exploraec/screens/detail_screen.dart';
import 'package:exploraec/screens/home_screen.dart';
import 'package:exploraec/screens/map_screen.dart';
import 'package:exploraec/services/location_service.dart';
import 'package:exploraec/theme/app_theme.dart';
import 'package:exploraec/widgets/error_view.dart';
import 'package:exploraec/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import 'helpers/geo_fake.dart';

// Teselas transparentes en tests; la demostración web usa OSM real.
class TilesDePrueba extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

void main() {
  final ejemplosIniciales = List<Place>.of(lugaresEjemplo);
  setUp(() {
    Get.reset();
    Get.testMode = true;
    lugaresEjemplo
      ..clear()
      ..addAll(ejemplosIniciales);
  });
  tearDown(() => Get.reset());

  Future<void> mostrarMapa(WidgetTester tester) async {
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.theme,
      home: MapScreen(tileProvider: TilesDePrueba()),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('Mapa muestra carga, error y reintento con el mismo controller',
      (tester) async {
    final respuesta = Completer<Position>();
    var llamadas = 0;
    final controller = Get.put(PlacesController(obtenerPosicion: () {
      llamadas++;
      if (llamadas == 1) return respuesta.future;
      return Future.value(posicionCafeGalletti());
    }));
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.theme,
      home: MapScreen(tileProvider: TilesDePrueba()),
    ));
    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.text('Obteniendo tu ubicación...'), findsOneWidget);
    respuesta.completeError(LocationException('Permiso de prueba denegado'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Permiso de prueba denegado'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(Get.find<PlacesController>(), same(controller));
    expect(controller.estadoPosicion.value, EstadoCarga.exito);
    expect(controller.mensajeErrorPosicion.value, isEmpty);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        hasLength(7));
    final teselas = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(
        teselas.urlTemplate, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
    expect(teselas.tileProvider.headers['User-Agent'],
        contains('com.bto.exploraec'));
    expect(find.text('Colaboradores de OpenStreetMap'), findsOneWidget);
    await controller.cargarPosicion();
    expect(llamadas, 2, reason: 'La posición válida se reutiliza');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Dos marcadores abren su detalle con distancias públicas distintas',
      (tester) async {
    final semantica = tester.ensureSemantics();
    try {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = Get.put(PlacesController(
        obtenerPosicion: () async => posicionCafeGalletti(),
      ));
      await mostrarMapa(tester);
      final mapa = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(mapa.options.initialCenter.latitude, -0.1938);
      expect(mapa.options.initialCenter.longitude, -78.4869);
      final marcadores =
          tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers;
      expect(marcadores.first.point.latitude, -0.1938);
      for (var indice = 0; indice < controller.total; indice++) {
        expect(marcadores[indice + 1].point.latitude,
            controller.lugares[indice].lat);
        expect(marcadores[indice + 1].point.longitude,
            controller.lugares[indice].lng);
      }
      await tester.tap(find.byKey(const ValueKey('marcador-2')));
      await tester.pumpAndSettle();
      expect(find.text('A 0 m de ti'), findsOneWidget);
      expect(
          tester.widget<DetailScreen>(find.byType(DetailScreen)).place.id, '2');
      Get.back<void>();
      await tester.pumpAndSettle();
      final nodoCafe = tester.getSemantics(
        find.byKey(const ValueKey('marcador-2')),
      );
      expect(
          nodoCafe.getSemanticsData().tooltip, 'Ver Café Galletti en el mapa');
      expect(
          nodoCafe.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      nodoCafe.owner!.performAction(nodoCafe.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(
          tester.widget<DetailScreen>(find.byType(DetailScreen)).place.id, '2');
      expect(find.text('A 0 m de ti'), findsOneWidget);
      Get.back<void>();
      await tester.pumpAndSettle();
      final iconoCafe = find.descendant(
        of: find.byKey(const ValueKey('marcador-2')),
        matching: find.byType(Icon),
      );
      final focoCafe = Focus.of(tester.element(iconoCafe));
      focoCafe.requestFocus();
      await tester.pump();
      expect(focoCafe.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
          tester.widget<DetailScreen>(find.byType(DetailScreen)).place.id, '2');
      expect(find.text('A 0 m de ti'), findsOneWidget);
      Get.back<void>();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('marcador-1')));
      await tester.pumpAndSettle();
      final detalle = tester.widget<DetailScreen>(find.byType(DetailScreen));
      expect(detalle.place.id, '1');
      expect(detalle.distanciaMetros, inInclusiveRange(1400, 1700));
      expect(find.text('A 1.5 km de ti'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantica.dispose();
    }
  });

  testWidgets(
      'Alta desde Inicio actualiza Mapa y el marcador nuevo abre detalle',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var lecturas = 0;
    final controller = Get.put(PlacesController(obtenerPosicion: () async {
      lecturas++;
      return posicionCafeGalletti();
    }));
    await mostrarMapa(tester);
    Get.to<void>(() => const HomeScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Agregar lugar'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('nombre')), 'Lugar en mapa');
    await tester.enterText(find.byKey(const ValueKey('categoria')), 'Parques');
    await tester.enterText(
      find.byKey(const ValueKey('descripcion')),
      'Lugar de prueba compartido entre las pantallas.',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('ExploraEC (7)'), findsOneWidget);
    expect(find.text('Lugar en mapa'), findsOneWidget);
    expect(controller.total, 7);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    Get.back<void>();
    await tester.pumpAndSettle();
    expect(Get.find<PlacesController>(), same(controller));
    final marcadores =
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers;
    expect(marcadores, hasLength(8));
    final nuevo = controller.lugares.last;
    expect(marcadores.last.point.latitude, nuevo.lat);
    expect(marcadores.last.point.longitude, nuevo.lng);
    expect(lecturas, 1);
    await tester.tap(find.byKey(ValueKey('marcador-${nuevo.id}')));
    await tester.pumpAndSettle();
    final detalle = tester.widget<DetailScreen>(find.byType(DetailScreen));
    expect(detalle.place, same(nuevo));
    expect(detalle.distanciaMetros, greaterThan(1000));
    expect(find.text('A ${formatearDistancia(detalle.distanciaMetros!)} de ti'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ubicación tardía no modifica un controller cerrado',
      (tester) async {
    final respuesta = Completer<Position>();
    final controller = Get.put(PlacesController(
      obtenerPosicion: () => respuesta.future,
    ));
    final carga = controller.cargarPosicion();
    await tester.pump(const Duration(seconds: 1));
    await Get.delete<PlacesController>(force: true);
    respuesta.complete(posicionCafeGalletti());
    await carga;
    expect(controller.posicion.value, isNull);
    expect(controller.estadoPosicion.value, EstadoCarga.cargando);
    expect(controller.mensajeErrorPosicion.value, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fallo del sensor muestra error y conserva los lugares',
      (tester) async {
    final controller = Get.put(PlacesController(
      obtenerPosicion: () async => throw Exception('Sensor no disponible'),
    ));
    await mostrarMapa(tester);
    expect(controller.estado.value, EstadoCarga.exito);
    expect(controller.total, 6);
    expect(controller.posicion.value, isNull);
    expect(controller.estadoPosicion.value, EstadoCarga.error);
    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Exception: Sensor no disponible'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
