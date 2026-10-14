import 'dart:io';

import 'package:exploraec/controllers/gastos_controller.dart';
import 'package:exploraec/controllers/places_controller.dart';
import 'package:exploraec/main.dart';
import 'package:exploraec/models/place.dart';
import 'package:exploraec/screens/add_place_screen.dart';
import 'package:exploraec/screens/detail_screen.dart';
import 'package:exploraec/screens/map_screen.dart';
import 'package:exploraec/widgets/place_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'helpers/geo_fake.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  final ejemplosIniciales = List<Place>.of(lugaresEjemplo);
  final plataformaOriginal = GeolocatorPlatform.instance;

  // Montaje real de persistencia, separado por prueba; no se borran carpetas.
  setUp(() async {
    await Hive.close();
    Hive.init(Directory.systemTemp.createTempSync('cedia_s07_favoritos_').path);
    await Hive.openBox<Map>('favoritos');
  });
  tearDown(() async => Hive.close());
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

  Future<void> abrirFormulario(WidgetTester tester) async {
    await tester.pumpWidget(const ExploraEcApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Agregar lugar'));
    await tester.pumpAndSettle();
  }

  testWidgets('Inicio lista los seis lugares y permite desplazarse', (
    tester,
  ) async {
    await tester.pumpWidget(const ExploraEcApp());
    await tester.pumpAndSettle();
    expect(lugaresEjemplo, hasLength(6));
    for (final lugar in ejemplosIniciales) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey(lugar.id)),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      final tarjeta = find.byKey(ValueKey(lugar.id));
      expect(tarjeta, findsOneWidget);
      expect(
        find.descendant(of: tarjeta, matching: find.text(lugar.nombre)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tarjeta, matching: find.text(lugar.categoria)),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cada tarjeta abre su detalle y vuelve a Inicio', (tester) async {
    await tester.pumpWidget(const ExploraEcApp());
    await tester.pumpAndSettle();
    for (final lugar in ejemplosIniciales) {
      final tarjeta = find.byKey(ValueKey(lugar.id));
      await tester.scrollUntilVisible(
        tarjeta,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(tarjeta);
      await tester.pumpAndSettle();
      expect(find.byType(DetailScreen), findsOneWidget);
      final detalle = tester.widget<DetailScreen>(find.byType(DetailScreen));
      expect(detalle.place.id, lugar.id);
      expect(find.text(lugar.nombre), findsNWidgets(2));
      expect(find.text(lugar.categoria), findsOneWidget);
      expect(find.text(lugar.descripcion), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(DetailScreen), findsNothing);
      expect(find.byType(PlaceCard), findsWidgets);
    }
    expect(lugaresEjemplo, hasLength(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Formulario vacío muestra tres errores y no agrega datos', (
    tester,
  ) async {
    await abrirFormulario(tester);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('El nombre es obligatorio'), findsOneWidget);
    expect(find.text('La categoría es obligatoria'), findsOneWidget);
    expect(find.text('Escribe al menos 10 caracteres'), findsOneWidget);
    expect(find.byType(AddPlaceScreen), findsOneWidget);
    expect(lugaresEjemplo, hasLength(6));
  });

  testWidgets('Los espacios y una descripción corta no pasan validación', (
    tester,
  ) async {
    await abrirFormulario(tester);
    await tester.enterText(find.byKey(const ValueKey('nombre')), '   ');
    await tester.enterText(find.byKey(const ValueKey('categoria')), '   ');
    await tester.enterText(
        find.byKey(const ValueKey('descripcion')), ' 123456789 ');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('El nombre es obligatorio'), findsOneWidget);
    expect(find.text('La categoría es obligatoria'), findsOneWidget);
    expect(find.text('Escribe al menos 10 caracteres'), findsOneWidget);
    expect(lugaresEjemplo, hasLength(6));
  });

  testWidgets('Guardar agrega el lugar limpio y visible inmediatamente', (
    tester,
  ) async {
    await abrirFormulario(tester);
    await tester.enterText(
        find.byKey(const ValueKey('nombre')), ' Parque de prueba ');
    await tester.enterText(
        find.byKey(const ValueKey('categoria')), ' Parques ');
    await tester.enterText(
        find.byKey(const ValueKey('descripcion')), ' 1234567890 ');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.byType(AddPlaceScreen), findsNothing);
    expect(lugaresEjemplo, hasLength(7));
    expect(lugaresEjemplo.last.nombre, 'Parque de prueba');
    expect(lugaresEjemplo.last.categoria, 'Parques');
    expect(lugaresEjemplo.last.descripcion, '1234567890');
    expect(find.text('Parque de prueba'), findsOneWidget);
    expect(find.text('Parque de prueba').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Parque de prueba'));
    await tester.pumpAndSettle();
    expect(find.text('1234567890'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('Cancelar el formulario conserva los seis lugares',
      (tester) async {
    await abrirFormulario(tester);
    await tester.enterText(find.byKey(const ValueKey('nombre')), 'Sin guardar');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(lugaresEjemplo, hasLength(6));
    expect(find.text('Sin guardar'), findsNothing);
  });

  testWidgets('Inicio, Mapa y Favoritos cambian el contenido', (tester) async {
    await tester.pumpWidget(const ExploraEcApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.byType(PlaceCard), findsNothing);
    await tester.tap(find.text('Favoritos').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Todavía no marcaste ningún lugar'),
        findsOneWidget);
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('ExploraEC (6)'), findsOneWidget);
    expect(find.byType(PlaceCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tarjeta larga y formulario caben en una pantalla móvil pequeña',
      (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await abrirFormulario(tester);
    await tester.enterText(
      find.byKey(const ValueKey('nombre')),
      'Un lugar con nombre muy largo para verificar los límites de la tarjeta',
    );
    await tester.enterText(find.byKey(const ValueKey('categoria')), 'Museos');
    await tester.enterText(
      find.byKey(const ValueKey('descripcion')),
      'Descripción completa de un lugar de demostración.',
    );
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(lugaresEjemplo, hasLength(7));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'S7 favoritos en disco sobreviven reinicio; alta manual solo queda en Favoritos y logout los conserva',
      (tester) async {
    await abrirFormulario(tester);
    await tester.enterText(
        find.byKey(const ValueKey('nombre')), 'Mi lugar de prueba S7');
    await tester.enterText(find.byKey(const ValueKey('categoria')), 'Parques');
    await tester.enterText(find.byKey(const ValueKey('descripcion')),
        'Lugar manual para comprobar la persistencia en disco.');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    final anterior = Get.find<PlacesController>();
    final manual = anterior.lugares.last;
    expect(manual.nombre, 'Mi lugar de prueba S7');
    expect(anterior.total, 7);

    await tester.runAsync(() async {
      await anterior.alternarFavorito(ejemplosIniciales.first);
      await anterior.alternarFavorito(manual);
      await Hive.box<Map>('favoritos').flush();
    });
    await tester.tap(find.text('Favoritos').last);
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsNWidgets(2));
    expect(find.text(manual.nombre), findsOneWidget);
    expect(anterior.totalFavoritos, 2);
    expect(Hive.box<Map>('favoritos').get(manual.id), manual.toMap());

    await tester.runAsync(() => Get.find<GastosController>().salir());
    expect(anterior.totalFavoritos, 2);
    expect(Hive.box<Map>('favoritos').get(manual.id), manual.toMap());

    // Simular un proceso nuevo: desmontar widgets/controllers, cerrar TODAS
    // las cajas y reabrir desde la misma ruta. Solo se reinicia el catálogo de
    // demostración en memoria; los favoritos no se inyectan ni se restauran.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    Get.reset();
    lugaresEjemplo
      ..clear()
      ..addAll(ejemplosIniciales);
    await tester.runAsync(() async {
      await Hive.close();
      expect(Hive.isBoxOpen('favoritos'), isFalse);
      expect(await Hive.boxExists('favoritos'), isTrue);
      final reabierta = await Hive.openBox<Map>('favoritos');
      expect(reabierta.get(manual.id), manual.toMap());
      expect(reabierta.length, 2);
    });
    await tester.pumpWidget(const ExploraEcApp());
    await tester.pumpAndSettle();
    final nuevo = Get.find<PlacesController>();
    expect(nuevo, isNot(same(anterior)));
    expect(nuevo.total, 6);
    expect(nuevo.lugares.any((lugar) => lugar.id == manual.id), isFalse);
    expect(
        nuevo.favoritos.singleWhere((lugar) => lugar.id == manual.id).toMap(),
        manual.toMap());
    expect(nuevo.totalFavoritos, 2);
    expect(Get.find<GastosController>().sesionActiva.value, isFalse);
    await tester.tap(find.text('Favoritos').last);
    await tester.pumpAndSettle();
    expect(find.text(manual.nombre), findsOneWidget);
    expect(find.byType(PlaceCard), findsNWidgets(2));

    // Comprobar también que desmarcar modifica el disco, no solo el RxList.
    await tester.runAsync(() async {
      await nuevo.alternarFavorito(manual);
      await Hive.box<Map>('favoritos').close();
      final reabierta = await Hive.openBox<Map>('favoritos');
      expect(reabierta.containsKey(manual.id), isFalse);
      expect(reabierta.containsKey(ejemplosIniciales.first.id), isTrue);
      expect(reabierta.length, 1);
    });
    await tester.pumpAndSettle();
    expect(find.text(manual.nombre), findsNothing);
    expect(nuevo.totalFavoritos, 1);
    expect(tester.takeException(), isNull);
  });
}
