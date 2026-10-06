import 'dart:ui' show SemanticsAction;

import 'package:exploraec/main.dart';
import 'package:exploraec/models/place.dart';
import 'package:exploraec/screens/map_screen.dart';
import 'package:exploraec/theme/app_theme.dart';
import 'package:exploraec/widgets/empty_view.dart';
import 'package:exploraec/widgets/error_view.dart';
import 'package:exploraec/widgets/loading_view.dart';
import 'package:exploraec/widgets/place_card.dart';
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

  Future<void> seleccionarModo(WidgetTester tester, String modo) async {
    while (Get.isSnackbarOpen) {
      final cierre = Get.closeCurrentSnackbar();
      await tester.pumpAndSettle();
      await cierre;
      await tester.pump();
    }
    await tester.tap(find.byTooltip('Simular estado (solo práctica)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simular: $modo'));
    await tester.pump();
  }

  Future<void> terminarCarga(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('Carga inicial dura un segundo y luego muestra los lugares', (
    tester,
  ) async {
    await tester.pumpWidget(const ExploraEcApp());
    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Buscando lugares cercanos...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 999));
    expect(find.byType(LoadingView), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byType(LoadingView), findsNothing);
    expect(find.byType(PlaceCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Modo vacío tiene mensaje e icono y vuelve a la lista', (
    tester,
  ) async {
    await tester.pumpWidget(const ExploraEcApp());
    await terminarCarga(tester);
    await seleccionarModo(tester, 'vacío');
    expect(find.byType(LoadingView), findsOneWidget);
    await terminarCarga(tester);
    expect(find.byType(EmptyView), findsOneWidget);
    expect(find.text('Todavía no hay lugares guardados'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.byType(PlaceCard), findsNothing);
    expect(lugaresEjemplo, hasLength(6));
    await seleccionarModo(tester, 'normal');
    await terminarCarga(tester);
    expect(find.byType(EmptyView), findsNothing);
    expect(find.byType(PlaceCard), findsWidgets);
  });

  testWidgets('Reintentar carga de nuevo, mantiene error y normal lo resuelve',
      (
    tester,
  ) async {
    await tester.pumpWidget(const ExploraEcApp());
    await terminarCarga(tester);
    await seleccionarModo(tester, 'error');
    expect(find.byType(LoadingView), findsOneWidget);
    await terminarCarga(tester);
    expect(find.byType(ErrorView), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ErrorView),
        matching: find
            .text('Exception: No se pudo conectar con el servidor (simulado)'),
      ),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.byType(ErrorView), findsNothing);
    await terminarCarga(tester);
    expect(find.byType(ErrorView), findsOneWidget);
    await seleccionarModo(tester, 'normal');
    await terminarCarga(tester);
    expect(find.byType(ErrorView), findsNothing);
    expect(find.byType(PlaceCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Responde a rotación y límites 600 y 900 sin desbordes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpWidget(const ExploraEcApp());
    await terminarCarga(tester);

    for (final ancho in [
      320.0,
      599.0,
      600.0,
      601.0,
      899.0,
      900.0,
      901.0,
      1280.0
    ]) {
      tester.view.physicalSize = Size(ancho, 568);
      await tester.pumpAndSettle();
      if (ancho < 600) {
        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(GridView), findsNothing);
      } else {
        expect(find.byType(ListView), findsNothing);
        final grilla = tester.widget<GridView>(find.byType(GridView));
        final reglas =
            grilla.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(reglas.crossAxisCount, ancho < 900 ? 2 : 3);
        expect(reglas.childAspectRatio, 2.2);
        final primero = tester.getTopLeft(find.byKey(const ValueKey('1')));
        final segundo = tester.getTopLeft(find.byKey(const ValueKey('2')));
        expect(primero.dy, segundo.dy);
        expect(segundo.dx, greaterThan(primero.dx));
      }
      expect(tester.takeException(), isNull, reason: 'Ancho lógico $ancho');
    }
  });

  testWidgets('Tema de marca aplica navy, blanco y teal a los componentes', (
    tester,
  ) async {
    await tester.pumpWidget(const ExploraEcApp());
    await terminarCarga(tester);
    final tema = Theme.of(tester.element(find.byType(AppBar).first));
    expect(tema.appBarTheme.backgroundColor, const Color(0xFF0E2841));
    expect(tema.appBarTheme.foregroundColor, Colors.white);
    expect(tema.colorScheme.primary, const Color(0xFF156082));
    await tester.tap(find.byTooltip('Agregar lugar'));
    await tester.pumpAndSettle();
    final estilo = Theme.of(tester.element(find.byType(ElevatedButton)))
        .elevatedButtonTheme
        .style;
    expect(estilo?.backgroundColor?.resolve({}), const Color(0xFF156082));
    expect(estilo?.foregroundColor?.resolve({}), Colors.white);
  });

  testWidgets('Tarjeta expone un solo anuncio semántico con acción de detalle',
      (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    try {
      final lugar = ejemplosIniciales.first;
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(body: PlaceCard(place: lugar)),
        ),
      );
      final etiqueta = '${lugar.nombre}, categoría ${lugar.categoria}';
      final nodo = tester.getSemantics(find.bySemanticsLabel(etiqueta));
      final datos = nodo.getSemanticsData();
      expect(datos.label, etiqueta);
      expect(datos.hint, 'Toca dos veces para ver el detalle');
      expect(datos.hasAction(SemanticsAction.tap), isTrue);
      expect(datos.flagsCollection.isButton, isTrue);
      expect(find.bySemanticsLabel(lugar.nombre), findsNothing);
      expect(find.bySemanticsLabel(lugar.categoria), findsNothing);
      expect(find.bySemanticsLabel(lugar.descripcion), findsNothing);
      final widget = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == etiqueta,
        ),
      );
      expect(widget.excludeSemantics, isTrue);
      expect(widget.properties.button, isTrue);
      await tester.tap(find.byType(PlaceCard));
      await tester.pumpAndSettle();
      expect(find.text(lugar.nombre), findsNWidgets(2));
    } finally {
      semantica.dispose();
    }
  });

  testWidgets('Las seis tarjetas usan espaciado centralizado y tipografía', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(599, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                for (final lugar in ejemplosIniciales) PlaceCard(place: lugar),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(PlaceCard), findsNWidgets(6));
    for (final elemento in find.byType(PlaceCard).evaluate()) {
      final tarjeta = find.byWidget(elemento.widget);
      final espacios = tester.widgetList<Padding>(
        find.descendant(of: tarjeta, matching: find.byType(Padding)),
      );
      expect(
        espacios.where((padding) =>
            padding.padding == const EdgeInsets.all(AppSpacing.md)),
        hasLength(1),
      );
      final place = (elemento.widget as PlaceCard).place;
      final nombre = tester.widget<Text>(
        find.descendant(of: tarjeta, matching: find.text(place.nombre)),
      );
      expect(nombre.style, Theme.of(elemento).textTheme.titleMedium);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Salir de Inicio durante la espera evita setState tras dispose', (
    tester,
  ) async {
    await tester.pumpWidget(const ExploraEcApp());
    expect(find.byType(LoadingView), findsOneWidget);
    await tester.tap(find.text('Mapa'));
    await terminarCarga(tester);
    expect(find.byType(MapScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
