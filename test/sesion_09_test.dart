// Adaptado de Patricio-CEDIA/exploraec-app, sesión 09; conserva sus 7 casos.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exploraec/controllers/auth_controller.dart';
import 'package:exploraec/controllers/gastos_controller.dart';
import 'package:exploraec/models/resumen_gastos.dart';
import 'package:exploraec/models/usuario.dart';
import 'package:exploraec/screens/assistant_screen.dart';
import 'package:exploraec/services/ai_assistant_service.dart';
import 'package:exploraec/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

/// Backend de gastos falso (el contrato real, en memoria).
class _Backend implements HttpClientAdapter {
  /// Cada prueba recibe un usuario distinto: así cada una abre su propia caja de
  /// Hive (`gastos_<id>`) y no hay que cerrar ni borrar nada entre pruebas.
  static var _usuarios = 0;
  final idUsuario = ++_usuarios;
  final gastos = <Map<String, dynamic>>[];
  var _id = 1;
  int posts = 0;
  int lecturasGastos = 0;
  Completer<void>? pausaResumen;
  int codigoResumen = 200;
  Completer<void>? pausaPost;
  final tokensPost = <Object?>[];

  ResponseBody _json(Object? cuerpo, int codigo,
          [Map<String, List<String>> h = const {}]) =>
      ResponseBody.fromString(cuerpo == null ? '' : jsonEncode(cuerpo), codigo,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
            ...h
          });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? cuerpo,
      Future<void>? cancelar) async {
    final texto = cuerpo == null
        ? ''
        : utf8.decode((await cuerpo.toList()).expand((x) => x).toList());
    final ruta = o.path;
    if (ruta == '/usuarios/token') {
      return _json(
          {'access_token': 'tok-a@b.com', 'token_type': 'bearer'}, 200);
    }
    if (ruta == '/usuarios/me') {
      return _json({'id': idUsuario, 'email': 'a@b.com'}, 200);
    }
    if (ruta == '/gastos/categorias') {
      return _json({
        'categorias': ['comida', 'transporte', 'entretenimiento', 'otros'],
        'limite_por_categoria': 500.0
      }, 200);
    }
    if (ruta == '/gastos/resumen') {
      if (pausaResumen != null) await pausaResumen!.future;
      if (codigoResumen != 200) {
        return _json({'detail': 'Sesión fixture caducada'}, codigoResumen);
      }
      final filas =
          ['comida', 'transporte', 'entretenimiento', 'otros'].map((c) {
        final propios = gastos.where((g) => g['categoria'] == c);
        final total =
            propios.fold<double>(0, (s, g) => s + (g['monto'] as num));
        return {
          'categoria': c,
          'total': total,
          'cantidad': propios.length,
          'disponible': 500 - total
        };
      }).toList();
      return _json({
        'categorias': filas,
        'total_general':
            filas.fold<double>(0, (s, f) => s + (f['total'] as num))
      }, 200);
    }
    if (ruta == '/gastos/' && o.method == 'GET') {
      lecturasGastos++;
      return _json(gastos, 200, {
        'x-total-count': ['${gastos.length}']
      });
    }
    if (ruta == '/gastos/' && o.method == 'POST') {
      posts++;
      tokensPost.add(o.headers['Authorization']);
      if (pausaPost != null) await pausaPost!.future;
      final datos = jsonDecode(texto) as Map<String, dynamic>;
      if ((datos['monto'] as num) > 500) {
        return _json({
          'detail':
              "Este gasto supera el límite de 500.0 para la categoría 'comida'"
        }, 400);
      }
      final nuevo = {'id': _id++, 'fecha': '2026-10-08', ...datos};
      gastos.add(nuevo);
      return _json(nuevo, 201);
    }
    return _json({'detail': 'ruta no prevista en la prueba: $ruta'}, 404);
  }

  @override
  void close({bool force = false}) {}
}

/// Proxy del asistente falso: guarda lo que recibió para comprobar qué viaja.
class _Proxy implements HttpClientAdapter {
  RequestOptions? ultima;
  Map<String, dynamic>? cuerpo;
  Map<String, dynamic> respuesta = {'respuesta': 'Gastas más en comida.'};
  int codigo = 200;
  bool sinRed = false;
  int peticiones = 0;
  Completer<void>? pausa;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? datos,
      Future<void>? cancelar) async {
    if (sinRed) {
      throw DioException.connectionError(
          requestOptions: o, reason: 'proxy apagado');
    }
    ultima = o;
    final texto = datos == null
        ? ''
        : utf8.decode((await datos.toList()).expand((x) => x).toList());
    cuerpo = jsonDecode(texto) as Map<String, dynamic>;
    peticiones++;
    if (pausa != null) await pausa!.future;
    return ResponseBody.fromString(jsonEncode(respuesta), codigo, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

const _resumen = ResumenGastos(
  categorias: [
    ResumenCategoria(
        categoria: 'comida', total: 20, cantidad: 2, disponible: 480)
  ],
  totalGeneral: 20,
);

void main() {
  setUpAll(
      () => Hive.init(Directory.systemTemp.createTempSync('hive_s09').path));

  late _Backend backend;
  late _Proxy proxy;

  /// Monta la app con servidores falsos y la sesión ya iniciada.
  Future<void> montar() async {
    Get.reset();
    Get.testMode = true;
    FlutterSecureStorage.setMockInitialValues({});
    backend = _Backend();
    proxy = _Proxy();
    final api = Get.put(ApiClient(
        dio: Dio(BaseOptions(baseUrl: 'http://backend'))
          ..httpClientAdapter = backend));
    Get.put(AiAssistantService(
        api: api,
        dio: Dio(BaseOptions(baseUrl: 'http://proxy'))
          ..httpClientAdapter = proxy));
    final auth = Get.put(AuthController());
    await auth.iniciarSesion('a@b.com', 'clave-1234');
    final gastos = Get.put(GastosController());
    for (var i = 0; i < 200 && gastos.categorias.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  tearDown(() async => Get.reset());
  // Cada backend abre una caja nueva, como en la referencia docente. Las
  // cajas temporales quedan conservadas; el proceso de flutter test libera
  // sus handles. Cerrar Hive global aquí puede esperar trabajos de una zona
  // de widgets que ya terminó y bloquear el cierre de toda la suite.

  // ---- Servicio y modelo: ya vienen resueltos, deben pasar desde el principio ----

  test(
      'El resumen viaja con los nombres del contrato y solo con totales por categoría',
      () {
    final json = _resumen.toJson();
    expect(json.keys, containsAll(['categorias', 'total_general']));
    expect((json['categorias'] as List).single.keys,
        containsAll(['categoria', 'total', 'cantidad', 'disponible']));
  });

  test(
      'El servicio envía consulta y resumen (nada más) y el token solo en la cabecera',
      () async {
    await montar();
    Get.find<ApiClient>().token = 'tok-secreto';
    final servicio = Get.find<AiAssistantService>();
    final r =
        await servicio.preguntar('¿en qué categoría gasto más?', _resumen);
    expect(r.respuesta, 'Gastas más en comida.');
    expect(proxy.cuerpo!.keys.toSet(), {'consulta', 'resumen'});
    expect(jsonEncode(proxy.cuerpo), isNot(contains('tok-secreto')));
    expect(proxy.ultima!.headers['Authorization'], 'Bearer tok-secreto');
  });

  test('Una acción válida se lee; una incompleta se rechaza sin ejecutar',
      () async {
    await montar();
    final servicio = Get.find<AiAssistantService>();
    proxy.respuesta = {
      'respuesta': 'ok',
      'accion': {
        'tipo': 'registrar_gasto',
        'descripcion': 'Almuerzo',
        'monto': 6.5,
        'categoria': 'comida'
      },
    };
    expect((await servicio.preguntar('x', _resumen)).accion!.monto, 6.5);
    proxy.respuesta = {
      'respuesta': 'ok',
      'accion': {
        'tipo': 'borrar_todo',
        'descripcion': 'x',
        'monto': 1,
        'categoria': 'comida'
      }
    };
    await expectLater(
        servicio.preguntar('x', _resumen), throwsA(isA<AsistenteException>()));
  });

  test('Proxy apagado: mensaje claro, no una traza técnica', () async {
    await montar();
    proxy.sinRed = true;
    await expectLater(
      Get.find<AiAssistantService>().preguntar('x', _resumen),
      throwsA(predicate((e) =>
          e.toString().contains('No se pudo conectar con el asistente'))),
    );
  });

  // ---- Pantalla: cada prueba la hace pasar un paso de la práctica ----

  Future<void> esperarRed(WidgetTester tester) async {
    // Alterna tiempo real (para que terminen las «peticiones» falsas y el disco)
    // con avance del reloj de la prueba (para los temporizadores de dio).
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  Future<void> abrirAsistente(WidgetTester tester) async {
    await tester.runAsync(montar);
    await tester.pumpWidget(const GetMaterialApp(home: AssistantScreen()));
    await tester.pump();
  }

  testWidgets('Paso 4 — preguntar muestra la respuesta del proxy',
      (tester) async {
    await abrirAsistente(tester);
    await tester.enterText(
        find.byType(TextField), '¿en qué categoría gasto más?');
    await tester.tap(find.text('Preguntar'));
    await esperarRed(tester);
    expect(find.text('Gastas más en comida.'), findsOneWidget);
    expect(proxy.cuerpo!['consulta'], '¿en qué categoría gasto más?');
  });

  testWidgets(
      'Paso 5 — una acción propuesta pide confirmación y, al aceptar, crea el gasto',
      (tester) async {
    await abrirAsistente(tester);
    proxy.respuesta = {
      'respuesta': 'Puedo registrarlo.',
      'accion': {
        'tipo': 'registrar_gasto',
        'descripcion': 'Almuerzo',
        'monto': 6.5,
        'categoria': 'comida'
      },
    };
    await tester.enterText(
        find.byType(TextField), 'registra un almuerzo de 6.50 en comida');
    await tester.tap(find.text('Preguntar'));
    await esperarRed(tester);
    expect(find.text('Confirmar acción'), findsOneWidget);
    expect(backend.gastos, isEmpty);
    final lecturasAntes = backend.lecturasGastos;
    await tester.tap(find.text('Registrar'));
    await esperarRed(tester);
    expect(backend.gastos.single['descripcion'], 'Almuerzo');
    expect(backend.posts, 1);
    expect(backend.lecturasGastos, greaterThan(lecturasAntes));
    expect(Get.find<GastosController>().gastos.single.descripcion, 'Almuerzo');
    expect(find.textContaining('Listo: registré'), findsOneWidget);
  });

  testWidgets('Paso 5 — cancelar la acción no crea ningún gasto',
      (tester) async {
    await abrirAsistente(tester);
    proxy.respuesta = {
      'respuesta': 'Puedo registrarlo.',
      'accion': {
        'tipo': 'registrar_gasto',
        'descripcion': 'Almuerzo',
        'monto': 6.5,
        'categoria': 'comida'
      },
    };
    await tester.enterText(
        find.byType(TextField), 'registra un almuerzo de 6.50 en comida');
    await tester.tap(find.text('Preguntar'));
    await esperarRed(tester);
    await tester.tap(find.text('Cancelar'));
    await esperarRed(tester);
    expect(backend.gastos, isEmpty);
    expect(backend.posts, 0);
  });

  test('Resumen malformado se rechaza; extras privados no se serializan', () {
    for (final categoria in ['inventada', null]) {
      final fila = {
        ...(_resumen.toJson()['categorias'] as List).single
            as Map<String, dynamic>,
        'categoria': categoria
      };
      expect(
          () => ResumenGastos.fromJson({
                'categorias': [fila],
                'total_general': 20
              }),
          throwsFormatException);
    }
    for (final total in [double.infinity, double.nan, -1, '20']) {
      expect(
          () => ResumenGastos.fromJson(
              {'categorias': [], 'total_general': total}),
          throwsFormatException);
    }
    final json = _resumen.toJson();
    json['email'] = 'fixture@example.invalid';
    expect(ResumenGastos.fromJson(json).toJson().containsKey('email'), isFalse);
    expect(() => ResumenGastos.fromJson({'categorias': [], 'total_general': 5}),
        throwsFormatException);
  });

  test('Propuestas: finite, categoría, tipo y cota técnica; 600 permitido', () {
    const valido = {
      'tipo': 'registrar_gasto',
      'descripcion': 'Gasto',
      'monto': 600,
      'categoria': 'comida'
    };
    expect(AccionPropuesta.desdeJson(valido)!.monto, 600);
    for (final monto in [0, -1, double.infinity, double.nan, 1000001, '6']) {
      expect(AccionPropuesta.desdeJson({...valido, 'monto': monto}), isNull);
    }
    expect(AccionPropuesta.desdeJson({...valido, 'categoria': 'inventada'}),
        isNull);
    expect(AccionPropuesta.desdeJson({...valido, 'tipo': 'eliminar'}), isNull);
  });

  test('Respuesta inválida no se convierte en respuesta ni acción', () {
    for (final texto in [null, 4, '', 'x' * 2001]) {
      expect(() => RespuestaIA.fromJson({'respuesta': texto}),
          throwsA(isA<AsistenteException>()));
    }
  });

  test('Falta token: 401 local sin enviar petición al proxy', () async {
    await montar();
    Get.find<ApiClient>().token = null;
    await expectLater(
        Get.find<AiAssistantService>().preguntar('x', _resumen),
        throwsA(isA<AsistenteException>()
            .having((e) => e.statusCode, 'código', 401)));
    expect(proxy.peticiones, 0);
  });

  test(
      '401 proxy caduca sesión; detail remoto no filtra token y 503 es distinto',
      () async {
    await montar();
    final api = Get.find<ApiClient>();
    var caducadas = 0;
    api.alSesionCaducada = () {
      caducadas++;
    };
    proxy.codigo = 401;
    proxy.respuesta = {'detail': 'token-secreto-no-imprimir'};
    await expectLater(
        Get.find<AiAssistantService>().preguntar('x', _resumen),
        throwsA(isA<AsistenteException>()
            .having((e) => e.statusCode, 'código', 401)
            .having((e) => e.mensaje, 'mensaje',
                isNot(contains('token-secreto')))));
    expect(caducadas, 1);
    proxy.codigo = 503;
    await expectLater(
        Get.find<AiAssistantService>().preguntar('x', _resumen),
        throwsA(isA<AsistenteException>()
            .having((e) => e.statusCode, 'código', 503)
            .having((e) => e.mensaje, 'mensaje', contains('MCP'))));
    expect(caducadas, 1);
  });

  test('Zona S9 rechaza POST diferido tras cambio de token antes del envío',
      () async {
    await montar();
    final api = Get.find<ApiClient>();
    final puerta = Completer<void>();
    final iniciado = Completer<void>();
    api.dio.interceptors.insert(1, InterceptorsWrapper(onRequest: (o, h) async {
      if (o.path == '/gastos/' && o.method == 'POST') {
        iniciado.complete();
        await puerta.future;
      }
      h.next(o);
    }));
    final pendiente = Get.find<AiAssistantService>().protegerSesion(
        api.token!,
        () => true,
        () => Get.find<GastosController>().crear('Gasto', 6, 'comida'));
    final rechazo = expectLater(pendiente, throwsA(isA<ApiException>()));
    await iniciado.future;
    api.token = 'token-nuevo';
    puerta.complete();
    await rechazo;
    expect(backend.posts, 0);
    expect(backend.gastos, isEmpty);
  });

  test('401 viejo de backend no caduca la sesión nueva', () async {
    await montar();
    final api = Get.find<ApiClient>();
    var caducadas = 0;
    api.alSesionCaducada = () {
      caducadas++;
    };
    backend.pausaResumen = Completer<void>();
    backend.codigoResumen = 401;
    final pendiente = Get.find<AiAssistantService>().protegerSesion(api.token!,
        () => true, () => Get.find<GastosController>().obtenerResumen());
    final rechazo = expectLater(pendiente, throwsA(isA<ApiException>()));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    api.token = 'token-nuevo';
    backend.pausaResumen!.complete();
    await rechazo;
    expect(caducadas, 0);
    expect(api.token, 'token-nuevo');
  });

  test(
      'Crear en vuelo conserva token original; no recarga ni publica en nueva sesión',
      () async {
    await montar();
    final api = Get.find<ApiClient>();
    final original = api.token!;
    backend.pausaPost = Completer<void>();
    final lecturasAntes = backend.lecturasGastos;
    final pendiente = Get.find<AiAssistantService>().protegerSesion(
        original,
        () => true,
        () =>
            Get.find<GastosController>().crear('Gasto anterior', 6, 'comida'));
    final rechazo = expectLater(pendiente, throwsA(isA<ApiException>()));
    for (var i = 0; i < 100 && backend.posts == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(backend.posts, 1);
    api.token = 'token-nuevo';
    backend.pausaPost!.complete();
    await rechazo;
    expect(backend.tokensPost, ['Bearer $original']);
    expect(backend.lecturasGastos, lecturasAntes);
    expect(Get.find<GastosController>().gastos, isEmpty);
  });

  testWidgets('Sin sesión lleva a LoginScreen y declara REGLAS al entrar',
      (tester) async {
    await abrirAsistente(tester);
    expect(find.textContaining('Modo REGLAS:'), findsOneWidget);
    Get.find<AuthController>().usuario.value = null;
    Get.find<ApiClient>().token = null;
    await tester.pump();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Correo'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('600 llega al backend que rechaza 500 y no registra',
      (tester) async {
    await abrirAsistente(tester);
    proxy.respuesta = {
      'respuesta': 'Propuesta',
      'accion': {
        'tipo': 'registrar_gasto',
        'descripcion': 'Gasto',
        'monto': 600,
        'categoria': 'comida'
      }
    };
    await tester.enterText(
        find.byType(TextField), 'Registra un gasto de 600 en comida');
    await tester.tap(find.text('Preguntar'));
    await esperarRed(tester);
    expect(find.text('Confirmar acción'), findsOneWidget);
    await tester.tap(find.text('Registrar'));
    await esperarRed(tester);
    expect(backend.posts, 1);
    expect(backend.gastos, isEmpty);
    expect(find.textContaining('Este gasto supera el límite de 500.0'),
        findsOneWidget);
  });

  testWidgets('Busy impide consultas y confirmaciones duplicadas',
      (tester) async {
    await abrirAsistente(tester);
    proxy.pausa = Completer<void>();
    await tester.enterText(
        find.byType(TextField), '¿En qué categoría gasto más?');
    await tester.tap(find.text('Preguntar'));
    await esperarRed(tester);
    final boton = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Preguntar'));
    expect(boton.onPressed, isNull);
    await tester.tap(find.text('Preguntar'));
    expect(proxy.peticiones, 1);
    proxy.pausa!.complete();
    await esperarRed(tester);
    expect(proxy.peticiones, 1);
  });

  void cambiarSesion() {
    final auth = Get.find<AuthController>();
    final api = Get.find<ApiClient>();
    auth.usuario.value = null;
    api.token = 'token-nuevo';
    auth.usuario.value =
        const Usuario(id: 999, email: 'otra-fixture@example.invalid');
  }

  testWidgets(
      'Logout/relogin durante consulta no muestra datos ni propone escritura vieja',
      (tester) async {
    await abrirAsistente(tester);
    proxy.pausa = Completer<void>();
    proxy.respuesta = {
      'respuesta': 'Respuesta anterior privada',
      'accion': {
        'tipo': 'registrar_gasto',
        'descripcion': 'Anterior',
        'monto': 6,
        'categoria': 'comida'
      }
    };
    await tester.enterText(
        find.byType(TextField), 'Registra un anterior de 6 en comida');
    await tester.tap(find.text('Preguntar'));
    await esperarRed(tester);
    expect(proxy.peticiones, 1);
    cambiarSesion();
    await tester.pump();
    proxy.pausa!.complete();
    await esperarRed(tester);
    expect(find.text('Respuesta anterior privada'), findsNothing);
    expect(find.text('Confirmar acción'), findsNothing);
    expect(backend.posts, 0);
  });

  testWidgets('Logout/relogin durante resumen no envía consulta al proxy',
      (tester) async {
    await abrirAsistente(tester);
    backend.pausaResumen = Completer<void>();
    await tester.enterText(find.byType(TextField), 'Pregunta');
    await tester.tap(find.text('Preguntar'));
    await esperarRed(tester);
    cambiarSesion();
    backend.pausaResumen!.complete();
    await esperarRed(tester);
    expect(proxy.peticiones, 0);
    expect(backend.posts, 0);
  });

  testWidgets(
      'Logout/relogin durante diálogo deshabilita Registrar; cancelar no escribe',
      (tester) async {
    await abrirAsistente(tester);
    proxy.respuesta = {
      'respuesta': 'Propuesta anterior',
      'accion': {
        'tipo': 'registrar_gasto',
        'descripcion': 'Anterior',
        'monto': 6,
        'categoria': 'comida'
      }
    };
    await tester.enterText(
        find.byType(TextField), 'Registra un anterior de 6 en comida');
    await tester.tap(find.text('Preguntar'));
    await esperarRed(tester);
    cambiarSesion();
    await tester.pump();
    final registrar = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Registrar'));
    expect(registrar.onPressed, isNull);
    await tester.tap(find.text('Cancelar'));
    await esperarRed(tester);
    expect(backend.posts, 0);
    expect(find.textContaining('Listo: registré'), findsNothing);
  });
}
