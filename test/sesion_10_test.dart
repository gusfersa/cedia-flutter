// Casos locales nuevos, basados en los objetivos académicos S10; asistencia IA.
import 'dart:async';
import 'dart:ui';

import 'package:exploraec/config/api_config.dart';
import 'package:exploraec/screens/gastos_screen.dart';
import 'package:exploraec/services/api_exception.dart';
import 'package:exploraec/utils/reporte_errores.dart';
import 'package:exploraec/widgets/error_pantalla_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/sesion10_fake.dart';

// Solo canarios sintéticos. No representan secretos, cuentas o rutas reales.
const _canario = 'Bearer eyJfixture.eyJfixture.firmaFixture '
    'api_key=claveCanario password=contrasenaCanario '
    'Authorization: cabeceraCanario /private/fixture/persona/archivo '
    r'C:\Fixture\Privado\archivo';

class _ErrorSinTexto implements Exception {
  @override
  String toString() => throw StateError('No se debe serializar el error crudo');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(ReporteErrores.restaurar);

  test('Instala una sola vez y restaura exactamente los tres callbacks', () {
    final flutter = FlutterError.onError;
    final dispatcher = PlatformDispatcher.instance.onError;
    final widget = ErrorWidget.builder;
    final log = <String>[];
    ReporteErrores.instalar(imprimir: log.add);
    final instalado = FlutterError.onError;
    final motor = PlatformDispatcher.instance.onError;
    final vista = ErrorWidget.builder;
    ReporteErrores.instalar(imprimir: (_) => fail('Instalación duplicada'));
    expect(identical(FlutterError.onError, instalado), isTrue);
    expect(identical(PlatformDispatcher.instance.onError, motor), isTrue);
    expect(identical(ErrorWidget.builder, vista), isTrue);
    FlutterError.reportError(
        FlutterErrorDetails(exception: StateError(_canario)));
    expect(log, hasLength(1));
    expect(ReporteErrores.recientes, log);
    ReporteErrores.restaurar();
    expect(identical(FlutterError.onError, flutter), isTrue);
    expect(identical(PlatformDispatcher.instance.onError, dispatcher), isTrue);
    expect(identical(ErrorWidget.builder, widget), isTrue);
    expect(ReporteErrores.recientes, isEmpty);
    ReporteErrores.restaurar();
    expect(identical(FlutterError.onError, flutter), isTrue);
  });

  test('Restaura callbacks originalmente null sin reenviar el error sin sanear',
      () {
    final flutter = FlutterError.onError;
    final dispatcher = PlatformDispatcher.instance.onError;
    try {
      FlutterError.onError = null;
      PlatformDispatcher.instance.onError = null;
      ReporteErrores.instalar(imprimir: (_) {});
      FlutterError.reportError(
          FlutterErrorDetails(exception: _ErrorSinTexto()));
      expect(ReporteErrores.recientes.single, contains('Fallo inesperado.'));
      ReporteErrores.restaurar();
      expect(FlutterError.onError, isNull);
      expect(PlatformDispatcher.instance.onError, isNull);
    } finally {
      ReporteErrores.restaurar();
      FlutterError.onError = flutter;
      PlatformDispatcher.instance.onError = dispatcher;
    }
  });

  test('El registro guarda los 20 más recientes, saneados antes de imprimir',
      () {
    final log = <String>[];
    ReporteErrores.instalar(imprimir: log.add);
    for (var i = 0; i < 5; i++) {
      FlutterError.reportError(
          FlutterErrorDetails(exception: RangeError(_canario)));
    }
    for (var i = 0; i < 20; i++) {
      FlutterError.reportError(
          const FlutterErrorDetails(exception: FormatException(_canario)));
    }
    expect(log, hasLength(25));
    expect(ReporteErrores.recientes, hasLength(20));
    expect(
        ReporteErrores.recientes.every((s) => s.contains('formato')), isTrue);
    for (final canario in [
      'Bearer',
      'eyJfixture',
      'claveCanario',
      'contrasenaCanario',
      'cabeceraCanario',
      '/private/fixture',
      r'C:\Fixture',
    ]) {
      expect(log.join(), isNot(contains(canario)));
      expect(ReporteErrores.recientes.join(), isNot(contains(canario)));
    }
    expect(() => ReporteErrores.recientes.add('otro'), throwsUnsupportedError);
    expect(ReporteErrores.limpiar(_ErrorSinTexto()), 'Fallo inesperado.');
    expect(ReporteErrores.limpiar(ArgumentError(_canario)),
        'Argumento no válido.');
    expect(ReporteErrores.limpiar(StateError(_canario)), 'Estado inesperado.');
  });

  test('Un fallo del logger o del aviso no rompe la captura asíncrona', () {
    ReporteErrores.instalar(
      imprimir: (_) => throw StateError(_canario),
      alErrorAsincrono: () => throw StateError(_canario),
    );
    final atendido = PlatformDispatcher.instance.onError!(
        StateError(_canario), StackTrace.fromString(_canario));
    expect(atendido, isTrue);
    expect(ReporteErrores.recientes, hasLength(1));
    expect(ReporteErrores.recientes.single,
        '[ExploraEC] error no controlado -> asincrono: Estado inesperado.');
  });

  testWidgets('Un widget que falla muestra la vista segura y permite volver',
      (tester) async {
    final log = <String>[];
    final navigator = GlobalKey<NavigatorState>();
    try {
      ReporteErrores.instalar(
          imprimir: log.add, salidaSegura: () => navigator.currentState!.pop());
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
          body: Builder(builder: (context) {
            return TextButton(
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => Scaffold(body: Builder(builder: (_) {
                  throw StateError(_canario);
                })),
              )),
              child: const Text('Abrir fixture'),
            );
          }),
        ),
      ));
      await tester.tap(find.text('Abrir fixture'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorPantallaView), findsOneWidget);
      expect(find.text('Esta pantalla tuvo un problema'), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(log, hasLength(1));
      expect(ReporteErrores.recientes, log);
      final textos = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join();
      expect(textos, isNot(contains('StateError')));
      expect(textos, isNot(contains('StackTrace')));
      expect(textos, isNot(contains('eyJfixture')));
      expect(textos, isNot(contains('claveCanario')));
      expect(textos, isNot(contains('/private/fixture')));
      await tester.tap(find.text('Volver a un lugar seguro'));
      await tester.pumpAndSettle();
      expect(find.text('Abrir fixture'), findsOneWidget);
      expect(find.byType(ErrorPantallaView), findsNothing);
    } finally {
      // Antes de que el binding compruebe invariantes, además del tearDown.
      ReporteErrores.restaurar();
    }
  });

  testWidgets('Un Future sin catch se captura y muestra un aviso sin traza',
      (tester) async {
    final log = <String>[];
    final messenger = GlobalKey<ScaffoldMessengerState>();
    final capturado = Completer<bool>();
    try {
      await tester.pumpWidget(MaterialApp(
          scaffoldMessengerKey: messenger,
          home: const Scaffold(body: Text('Pantalla disponible'))));
      ReporteErrores.instalar(
        imprimir: log.add,
        alErrorAsincrono: () => messenger.currentState!
            .showSnackBar(const SnackBar(content: Text('Algo salió mal'))),
      );
      // El runner posee su zona de errores. Se genera un Future realmente sin
      // catch y la zona puente lo entrega al callback del motor instalado.
      runZonedGuarded(() {
        Future<void>.microtask(() => throw StateError(_canario));
      }, (error, stack) {
        capturado.complete(PlatformDispatcher.instance.onError!(error, stack));
      });
      await tester.pump();
      expect(await capturado.future, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Algo salió mal'), findsOneWidget);
      expect(find.text('Pantalla disponible'), findsOneWidget);
      expect(log.single,
          '[ExploraEC] error no controlado -> asincrono: Estado inesperado.');
      expect(log.join(), isNot(contains('eyJfixture')));
      expect(log.join(), isNot(contains('contrasenaCanario')));
      expect(find.textContaining('eyJfixture'), findsNothing);
      expect(ReporteErrores.recientes, log);
      messenger.currentState!.removeCurrentSnackBar();
      await tester.pumpAndSettle();
    } finally {
      ReporteErrores.restaurar();
    }
  });

  testWidgets(
      'Controles de práctica respetan la bandera y recuperan pantalla y Future',
      (tester) async {
    late EntornoSesion10 e;
    await tester.runAsync(() async {
      e = await EntornoSesion10.crear();
      await e.entrar();
    });
    addTearDown(() => tester.runAsync(e.cerrar));
    final log = <String>[];
    final messenger = GlobalKey<ScaffoldMessengerState>();
    var avisoRecibido = false;
    try {
      ReporteErrores.instalar(
        imprimir: log.add,
        salidaSegura: () => Get.back<void>(),
        alErrorAsincrono: () {
          messenger.currentState!
              .showSnackBar(const SnackBar(content: Text('Algo salió mal')));
          avisoRecibido = true;
        },
      );
      await tester.pumpWidget(GetMaterialApp(
          scaffoldMessengerKey: messenger, home: const GastosScreen()));
      await tester.pumpAndSettle();
      await tester
          .runAsync(() => tester.tap(find.byTooltip('Opciones de gastos')));
      await tester.pumpAndSettle();
      if (!ApiConfig.labPruebas) {
        expect(find.text('Error de pantalla (solo práctica)'), findsNothing);
        expect(find.text('Error asíncrono (solo práctica)'), findsNothing);
        expect(find.text('Cerrar sesión'), findsOneWidget);
        Get.back<void>();
        await tester.pumpAndSettle();
        expect(log, isEmpty);
      } else {
        await tester.runAsync(() async {
          await tester.tap(find.text('Error de pantalla (solo práctica)'));
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pumpAndSettle();
        expect(find.byType(ErrorPantallaView), findsOneWidget);
        expect(log, hasLength(1));
        await tester.tap(find.text('Volver a un lugar seguro'));
        await tester.pumpAndSettle();
        expect(find.byType(ErrorPantallaView), findsNothing);
        expect(find.byKey(const ValueKey('gasto-1')), findsOneWidget);

        await tester.runAsync(() async {
          // El runner intercepta los Futures no controlados. Esta zona puente
          // entrega el fallo real del menú al dispatcher instalado.
          await runZonedGuarded<Future<void>>(
            () => tester.tap(find.byTooltip('Opciones de gastos')),
            (error, stack) =>
                PlatformDispatcher.instance.onError!(error, stack),
          );
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.text('Error asíncrono (solo práctica)'));
          // Medir el efecto real sin esperar aquí un Completer de FakeAsync:
          // sus microtareas requieren pump fuera de runAsync.
          for (var i = 0; i < 100 && !avisoRecibido; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        expect(avisoRecibido, isTrue);
        await tester.pump(const Duration(milliseconds: 300));
        expect(log, hasLength(2));
        expect(log.last, contains('asincrono: Estado inesperado.'));
        expect(find.text('Algo salió mal'), findsOneWidget);
        messenger.currentState!.removeCurrentSnackBar();
        await tester.pumpAndSettle();
      }
      expect(e.auth.estaAutenticado, isTrue);
      expect(e.gastos.gastos.map((g) => g.id), [1, 2]);
    } finally {
      ReporteErrores.restaurar();
    }
  });

  testWidgets(
      '400, red y 401 conservan su manejo; menú y login siguen accesibles',
      (tester) async {
    late EntornoSesion10 e;
    await tester.runAsync(() async {
      e = await EntornoSesion10.crear();
      await e.entrar();
    });
    addTearDown(() => tester.runAsync(e.cerrar));
    try {
      ReporteErrores.instalar(imprimir: (_) {});
      await tester.pumpWidget(const GetMaterialApp(home: GastosScreen()));
      await tester.pumpAndSettle();
      await tester
          .runAsync(() => tester.tap(find.byTooltip('Opciones de gastos')));
      await tester.pumpAndSettle();
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.text('Error de pantalla (solo práctica)'),
          ApiConfig.labPruebas ? findsOneWidget : findsNothing);
      expect(find.text('Error asíncrono (solo práctica)'),
          ApiConfig.labPruebas ? findsOneWidget : findsNothing);
      Get.back<void>();
      await tester.pumpAndSettle();
      e.servidor.codigoGuardar = 400;
      await tester.runAsync(() async {
        await expectLater(
            e.gastos.crear('Fixture rechazado', 999, 'comida'),
            throwsA(isA<ApiException>()
                .having((e) => e.statusCode, 'código', 400)));
      });
      expect(e.gastos.gastos.length, 2);
      expect(e.auth.estaAutenticado, isTrue);
      e.servidor.sinRed = true;
      await tester.runAsync(e.gastos.cargarGastos);
      await tester.pumpAndSettle();
      expect(e.gastos.desdeCache.value, isTrue);
      expect(find.textContaining('Sin conexión'), findsOneWidget);
      e.gastos.seleccionarCategoria('comida');
      e.servidor.sinRed = false;
      e.servidor.codigoLista = 401;
      await tester.runAsync(() async {
        await e.gastos.cargarGastos();
        await e.gastos.cierrePendiente;
      });
      await tester.pumpAndSettle();
      expect(e.auth.estaAutenticado, isFalse);
      expect(e.gastos.filtroCategoria.value, isNull);
      expect(e.gastos.gastos, isEmpty);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(ReporteErrores.recientes, isEmpty);
    } finally {
      ReporteErrores.restaurar();
    }
  });
}
