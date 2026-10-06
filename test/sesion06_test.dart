import 'dart:async';

import 'package:exploraec/config/api_config.dart';
import 'package:exploraec/controllers/gastos_controller.dart';
import 'package:exploraec/controllers/places_controller.dart';
import 'package:exploraec/main.dart';
import 'package:exploraec/models/place.dart';
import 'package:exploraec/screens/gastos_screen.dart';
import 'package:exploraec/services/gastos_api_service.dart';
import 'package:exploraec/theme/app_theme.dart';
import 'package:exploraec/widgets/empty_view.dart';
import 'package:exploraec/widgets/error_view.dart';
import 'package:exploraec/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _lista = '[{"id":1,"descripcion":"Almuerzo en el Mercado Central",'
    '"monto":6.5,"categoria":"comida","fecha":"2026-10-05"},'
    '{"id":2,"descripcion":"Taxi al terminal","monto":3.25,'
    '"categoria":"transporte","fecha":"2026-10-05"},'
    '{"id":3,"descripcion":"Entrada al Museo Casa del Alabado","monto":4,'
    '"categoria":"entretenimiento","fecha":"2026-10-05"}]';

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

  Future<void> mostrar(WidgetTester tester) => tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.theme, home: const GastosScreen()));

  Future<void> entrar(WidgetTester tester) async {
    await tester.enterText(
        find.byKey(const ValueKey('gastos-correo')), 'alumno@example.test');
    await tester.enterText(
        find.byKey(const ValueKey('gastos-password')), 'clave-prueba');
    await tester.tap(find.text('Entrar'));
    await tester.pump();
  }

  http.Response autenticar(http.Request peticion) =>
      peticion.url.path == '/usuarios/token'
          ? http.Response('{"access_token":"jwt-sintetico"}', 200)
          : http.Response('{}', 201);

  testWidgets('Cuarta pestaña conserva Places y registra Gastos una sola vez',
      (tester) async {
    var llamadas = 0;
    final gastos = Get.put(
        GastosController(api: GastosApiService(cliente: MockClient((_) async {
      llamadas++;
      return http.Response('{}', 201);
    }))));
    await tester.pumpWidget(const ExploraEcApp());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    final places = Get.find<PlacesController>();
    expect(find.text('ExploraEC (6)'), findsOneWidget);
    final barra =
        tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(barra.items.map((item) => item.label),
        ['Inicio', 'Mapa', 'Favoritos', 'Gastos']);
    await tester.tap(find.text('Gastos'));
    await tester.pumpAndSettle();
    expect(find.byType(GastosScreen), findsOneWidget);
    expect(find.text('Servidor: http://10.0.2.2:8000'), findsOneWidget);
    expect(Get.find<GastosController>(), same(gastos));
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(Get.find<PlacesController>(), same(places));
    expect(places.total, 6);
    expect(llamadas, 0, reason: 'La red empieza solo al entrar');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gastos muestra carga, vacío, lista, error de red y reintento',
      (tester) async {
    final primeraLista = Completer<http.Response>();
    var carga = 0;
    var sinConexion = false;
    final controller = Get.put(GastosController(
        api: GastosApiService(cliente: MockClient((peticion) async {
      if (peticion.url.path != '/gastos/') return autenticar(peticion);
      carga++;
      if (carga == 1) return primeraLista.future;
      if (sinConexion) throw http.ClientException('conexión de prueba');
      return http.Response(_lista, 200, headers: {'x-total-count': '3'});
    }))));
    await mostrar(tester);
    await entrar(tester);
    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.text('Cargando gastos...'), findsOneWidget);
    primeraLista
        .complete(http.Response('[]', 200, headers: {'x-total-count': '0'}));
    await tester.pumpAndSettle();
    expect(find.byType(EmptyView), findsOneWidget);
    expect(find.text('Gastos (0)'), findsOneWidget);
    await tester.tap(find.byTooltip('Recargar'));
    await tester.pumpAndSettle();
    expect(find.text('Gastos (3)'), findsOneWidget);
    expect(find.text('6.50'), findsOneWidget);
    expect(find.text('3.25'), findsOneWidget);
    expect(find.text('4.00'), findsOneWidget);
    expect(find.text('comida · 2026-10-05'), findsOneWidget);
    sinConexion = true;
    await tester.tap(find.byTooltip('Recargar'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorView), findsOneWidget);
    expect(controller.gastos, hasLength(3));
    expect(controller.totalEnServidor.value, 3);
    expect(controller.sesionActiva.value, isTrue);
    sinConexion = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Gastos (3)'), findsOneWidget);
    expect(find.byType(ErrorView), findsNothing);
  });

  testWidgets('Menú invalida token real; 401 devuelve formulario vacío',
      (tester) async {
    final api = GastosApiService(cliente: MockClient((peticion) async {
      if (peticion.url.path != '/gastos/') return autenticar(peticion);
      if (peticion.headers['Authorization'] == 'Bearer token-invalido') {
        return http.Response('{"detail":"Credenciales rechazadas"}', 401);
      }
      return http.Response(_lista, 200, headers: {'x-total-count': '3'});
    }));
    final controller = Get.put(GastosController(api: api));
    await mostrar(tester);
    await entrar(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Opciones de gastos'));
    await tester.pumpAndSettle();
    if (!ApiConfig.labPruebas) {
      expect(find.text('Probar timeout de 1 ms'), findsNothing);
    }
    await tester.tap(find.text('Invalidar token (solo práctica)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Recargar'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.textContaining('Tu sesión caducó'), findsOneWidget);
    expect(controller.sesionActiva.value, isFalse);
    expect(api.tieneToken, isFalse);
    for (final campo in ['gastos-correo', 'gastos-password']) {
      expect(
          tester
              .widget<TextField>(find.byKey(ValueKey(campo)))
              .controller!
              .text,
          isEmpty);
    }
    await entrar(tester);
    await tester.pumpAndSettle();
    expect(find.text('Gastos (3)'), findsOneWidget);
    await tester.tap(find.byTooltip('Opciones de gastos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
    expect(api.tieneToken, isFalse);
    expect(controller.gastos, isEmpty);
  });

  testWidgets('Cargar más usa paginación y el título muestra el total remoto',
      (tester) async {
    var solicitudes = 0;
    Get.put(GastosController(
        api: GastosApiService(cliente: MockClient((peticion) async {
      if (peticion.url.path != '/gastos/') return autenticar(peticion);
      solicitudes++;
      expect(
          peticion.url.queryParameters['skip'], solicitudes == 1 ? '0' : '3');
      return http.Response(
          solicitudes == 1
              ? _lista
              : '[{"id":4,"descripcion":"Agua para el viaje","monto":1.25,'
                  '"categoria":"otros","fecha":"2026-10-05"}]',
          200,
          headers: {'x-total-count': '4'});
    }))));
    await mostrar(tester);
    await entrar(tester);
    await tester.pumpAndSettle();
    expect(find.text('Gastos (4)'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(3));
    await tester.tap(find.text('Cargar más'));
    await tester.pumpAndSettle();
    expect(find.text('Agua para el viaje'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(4));
    expect(find.text('Cargar más'), findsNothing);
    expect(solicitudes, 2);
  });

  testWidgets('422 muestra campo traducido y permite corregir el formulario',
      (tester) async {
    Get.put(GastosController(
        api: GastosApiService(cliente: MockClient((peticion) async {
      if (peticion.url.path == '/usuarios/') {
        return http.Response(
          '{"detail":[{"loc":["body","password"],'
          '"msg":"String should have at least 8 characters",'
          '"type":"string_too_short","ctx":{"min_length":8}}]}',
          422,
        );
      }
      throw StateError('Un registro inválido no debe llamar login/lista');
    }))));
    await mostrar(tester);
    await tester.enterText(
        find.byKey(const ValueKey('gastos-correo')), 'nuevo@example.test');
    await tester.enterText(
        find.byKey(const ValueKey('gastos-password')), 'abc');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Datos inválidos — contraseña: Debe tener al menos 8 caracteres'),
        findsOneWidget);
    expect(find.textContaining('String should'), findsNothing);
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('gastos-password')))
            .obscureText,
        isTrue);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });

  testWidgets('Gastos mantiene formulario y lista usables a 320×568',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.put(GastosController(
        api: GastosApiService(cliente: MockClient((peticion) async {
      if (peticion.url.path != '/gastos/') return autenticar(peticion);
      return http.Response(_lista, 200, headers: {'x-total-count': '3'});
    }))));
    await mostrar(tester);
    await entrar(tester);
    await tester.pumpAndSettle();
    expect(find.text('Gastos (3)'), findsOneWidget);
    expect(find.text('Almuerzo en el Mercado Central'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  if (ApiConfig.labPruebas) {
    testWidgets('Laboratorio cambia 1 ms→15 s sin perder token ni lista',
        (tester) async {
      var demorar = false;
      final api = GastosApiService(cliente: MockClient((peticion) async {
        if (peticion.url.path != '/gastos/') return autenticar(peticion);
        expect(peticion.headers['Authorization'], 'Bearer jwt-sintetico');
        if (demorar) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        return http.Response(_lista, 200, headers: {'x-total-count': '3'});
      }));
      final controller = Get.put(GastosController(api: api));
      await mostrar(tester);
      await entrar(tester);
      await tester.pumpAndSettle();
      demorar = true;
      await tester.tap(find.byTooltip('Opciones de gastos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Probar timeout de 1 ms'));
      await tester.pump(const Duration(milliseconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorView), findsOneWidget);
      expect(
          find.textContaining('El servidor tardó demasiado'), findsOneWidget);
      expect(controller.gastos, hasLength(3));
      expect(api.tieneToken, isTrue);
      expect(controller.sesionActiva.value, isTrue);
      await tester.tap(find.byTooltip('Opciones de gastos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restaurar timeout de 15 s'));
      await tester.pump(const Duration(milliseconds: 25));
      await tester.pumpAndSettle();
      expect(find.text('Gastos (3)'), findsOneWidget);
      expect(api.plazo, const Duration(seconds: 15));
      expect(controller.gastos, hasLength(3));
      expect(api.tieneToken, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
