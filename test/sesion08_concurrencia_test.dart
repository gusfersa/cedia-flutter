// Regresiones locales de S8; transportes sintéticos y cajas Hive reales.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exploraec/controllers/auth_controller.dart';
import 'package:exploraec/controllers/gastos_controller.dart';
import 'package:exploraec/models/usuario.dart';
import 'package:exploraec/services/api_client.dart';
import 'package:exploraec/services/gastos_api_service.dart';
import 'package:exploraec/services/secure_token_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

ResponseBody _json(Object? cuerpo, [int codigo = 200, int? total]) =>
    ResponseBody.fromString(cuerpo == null ? '' : jsonEncode(cuerpo), codigo,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
          if (total != null) 'x-total-count': ['$total']
        });

typedef _Respuesta = Future<ResponseBody> Function(RequestOptions);

class _Servidor implements HttpClientAdapter {
  final peticiones = <RequestOptions>[];
  final datos = <String, List<Map<String, dynamic>>>{'a': [], 'b': []};
  final categorias = ['comida', 'nueva-del-servidor'];
  _Respuesta? interceptar;
  bool offline = false;
  bool falloRecarga = false;
  int siguienteId = 1;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? cuerpo,
      Future<void>? cancelar) async {
    peticiones.add(o);
    if (offline) {
      throw DioException(
          requestOptions: o, type: DioExceptionType.connectionError);
    }
    if (interceptar != null) return interceptar!(o);
    return responder(o);
  }

  ResponseBody responder(RequestOptions o) {
    if (o.path == '/usuarios/token') {
      final email = (o.data as Map)['username'] as String;
      return _json({'access_token': 't-${email.startsWith('b') ? 'b' : 'a'}'});
    }
    if (o.path == '/usuarios/' && o.method == 'POST') {
      return _json({'id': 1, 'email': (o.data as Map)['email']}, 201);
    }
    final token = o.headers['Authorization'];
    if (token != 'Bearer t-a' && token != 'Bearer t-b') {
      return _json({'detail': 'Token rechazado'}, 401);
    }
    final quien = token == 'Bearer t-a' ? 'a' : 'b';
    if (o.path == '/usuarios/me') {
      return _json(
          {'id': quien == 'a' ? 1 : 2, 'email': '$quien@example.test'});
    }
    if (o.path == '/gastos/categorias') {
      return _json({'categorias': categorias, 'limite_por_categoria': 500});
    }
    final gastos = datos[quien]!;
    if (o.path == '/gastos/' && o.method == 'GET') {
      if (falloRecarga) {
        return _json({'detail': 'Fallo de sincronización'}, 503);
      }
      final skip = (o.queryParameters['skip'] as num?)?.toInt() ?? 0;
      final limit = (o.queryParameters['limit'] as num?)?.toInt() ?? 20;
      return _json(gastos.skip(skip).take(limit).toList(), 200, gastos.length);
    }
    if (o.path == '/gastos/' && o.method == 'POST') {
      final nuevo = {
        'id': siguienteId++,
        'fecha': '2026-10-13',
        ...o.data as Map<String, dynamic>
      };
      gastos.add(nuevo);
      return _json(nuevo, 201);
    }
    final id = int.tryParse(o.path.split('/').last);
    final indice = gastos.indexWhere((g) => g['id'] == id);
    if (indice < 0) return _json({'detail': 'El gasto $id no existe'}, 404);
    if (o.method == 'PATCH') {
      gastos[indice] = {...gastos[indice], ...o.data as Map<String, dynamic>};
      return _json(gastos[indice]);
    }
    if (o.method == 'DELETE') {
      gastos.removeAt(indice);
      return _json(null, 204);
    }
    return _json({'detail': 'Ruta no prevista'}, 404);
  }

  @override
  void close({bool force = false}) {}
}

/// Fallos de la API nativa, sin simular el resultado de AuthController.
class _AlmacenNativo extends FlutterSecureStorage {
  String? valor;
  bool fallarLectura = false;
  bool fallarEscritura = false;
  bool fallarBorrado = false;
  Completer<void>? escrituraIniciada;
  Completer<void>? permisoEscritura;
  final eventos = <String>[];

  @override
  Future<String?> read(
      {required String key,
      AppleOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      AppleOptions? mOptions,
      WindowsOptions? wOptions}) async {
    if (fallarLectura) throw PlatformException(code: 'keychain_inaccesible');
    return valor;
  }

  @override
  Future<void> write(
      {required String key,
      required String? value,
      AppleOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      AppleOptions? mOptions,
      WindowsOptions? wOptions}) async {
    eventos.add('write:$value');
    if (escrituraIniciada != null && !escrituraIniciada!.isCompleted) {
      escrituraIniciada!.complete();
      await permisoEscritura!.future;
    }
    if (fallarEscritura) throw PlatformException(code: 'keychain_inaccesible');
    valor = value;
  }

  @override
  Future<void> delete(
      {required String key,
      AppleOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      AppleOptions? mOptions,
      WindowsOptions? wOptions}) async {
    eventos.add('delete');
    if (fallarBorrado) throw PlatformException(code: 'keychain_inaccesible');
    valor = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Servidor servidor;
  late ApiClient api;
  late AuthController auth;
  late GastosController gastos;

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    FlutterSecureStorage.setMockInitialValues({});
    await Hive.close();
    Hive.init(Directory.systemTemp.createTempSync('cedia_s08_carreras_').path);
    await Hive.openBox<Map>('favoritos');
    servidor = _Servidor();
    api = ApiClient(
        dio: Dio(BaseOptions(baseUrl: 'http://sintetico'))
          ..httpClientAdapter = servidor);
    auth = AuthController(api: api);
    gastos = GastosController(api: GastosApiService(api: api), auth: auth);
  });

  tearDown(() async {
    gastos.onClose();
    auth.onClose();
    await gastos.cierrePendiente;
    await auth.cierrePendiente;
    api.dispose();
    await Hive.close();
    Get.reset();
  });

  Future<void> entrar([String quien = 'a']) async {
    await auth.iniciarSesion('$quien@example.test', 'clave-sintetica');
    await gastos.inicioPendiente;
    expect(auth.usuario.value?.email, '$quien@example.test');
  }

  test(
      'S8 dispose conserva token y caché; un proceso nuevo valida /me y lee disco',
      () async {
    await entrar();
    await gastos.crear('Taxi', 3.5, 'comida');
    final almacen = SecureTokenStorage();
    gastos.onClose();
    auth.onClose();
    await gastos.cierrePendiente;
    await auth.cierrePendiente;
    expect(await almacen.leer(), 't-a');
    expect(await Hive.boxExists('gastos_1'), isTrue);
    await Hive.close();
    final caja = await Hive.openBox<dynamic>('gastos_1');
    expect((caja.get('gastos') as List).single['descripcion'], 'Taxi');
    await caja.close();
    final nuevoApi = ApiClient(
        dio: Dio(BaseOptions(baseUrl: 'http://sintetico'))
          ..httpClientAdapter = servidor);
    final nuevoAuth = AuthController(api: nuevoApi);
    addTearDown(nuevoApi.dispose);
    addTearDown(nuevoAuth.onClose);
    final antes =
        servidor.peticiones.where((o) => o.path == '/usuarios/me').length;
    await nuevoAuth.restaurarSesion();
    expect(nuevoAuth.usuario.value?.id, 1);
    expect(servidor.peticiones.where((o) => o.path == '/usuarios/me').length,
        antes + 1);
    await nuevoAuth.cerrarSesion();
    expect(await almacen.leer(), isNull);
  });

  test('S8 logout durante /me cancela usuario, token seguro y apertura Hive',
      () async {
    final inicio = Completer<void>();
    final permiso = Completer<ResponseBody>();
    servidor.interceptar = (o) async {
      if (o.path == '/usuarios/me') {
        inicio.complete();
        return permiso.future;
      }
      return servidor.responder(o);
    };
    final login = auth.iniciarSesion('a@example.test', 'clave-sintetica');
    await inicio.future;
    final cierre = auth.cerrarSesion();
    expect(api.token, isNull);
    expect(auth.usuario.value, isNull);
    permiso.complete(_json({'id': 1, 'email': 'a@example.test'}));
    await Future.wait([login, cierre]);
    expect(await SecureTokenStorage().leer(), isNull);
    expect(await Hive.boxExists('gastos_1'), isFalse);
    expect(gastos.gastos, isEmpty);
  });

  test(
      'S8 logout durante openBox borra solo la apertura capturada y deja B intacta',
      () async {
    gastos.onClose();
    await gastos.cierrePendiente;
    final abierto = Completer<void>();
    final permiso = Completer<void>();
    final servicio = GastosApiService(api: api);
    final repo = GastosRepository(servicio, abrirCaja: (nombre) async {
      final caja = await Hive.openBox<dynamic>(nombre);
      if (nombre == 'gastos_1') {
        abierto.complete();
        await permiso.future;
      }
      return caja;
    });
    gastos = GastosController(api: servicio, auth: auth, repository: repo);
    await auth.iniciarSesion('a@example.test', 'clave-sintetica');
    await abierto.future;
    final inicioA = gastos.inicioPendiente;
    final cierre = auth.cerrarSesion();
    expect(gastos.gastos, isEmpty);
    expect(gastos.sesionActiva.value, isFalse);
    final loginB = auth.iniciarSesion('b@example.test', 'clave-sintetica');
    permiso.complete();
    await Future.wait([cierre, inicioA, loginB]);
    await gastos.inicioPendiente;
    await gastos.crear('Gasto de B', 7, 'comida');
    expect(auth.usuario.value?.id, 2);
    expect(await Hive.boxExists('gastos_1'), isFalse);
    expect(
        (Hive.box<dynamic>('gastos_2').get('gastos') as List)
            .single['descripcion'],
        'Gasto de B');
  });

  for (final reutilizarToken in [false, true]) {
    test(
        'S8 un 401 viejo no cierra una sesión nueva (token igual=$reutilizarToken)',
        () async {
      await entrar();
      final inicio = Completer<void>();
      final respuesta = Completer<ResponseBody>();
      servidor.interceptar = (o) async {
        if (o.path == '/lenta') {
          inicio.complete();
          return respuesta.future;
        }
        return servidor.responder(o);
      };
      final vieja = api.get('/lenta');
      final fallo = expectLater(
          vieja,
          throwsA(
              isA<ApiException>().having((e) => e.statusCode, 'codigo', 401)));
      await inicio.future;
      await auth.cerrarSesion();
      await entrar(reutilizarToken ? 'a' : 'b');
      respuesta.complete(_json({'detail': 'Sesión A vencida'}, 401));
      await fallo;
      expect(auth.estaAutenticado, isTrue);
      expect(api.token, reutilizarToken ? 't-a' : 't-b');
      expect(
          await SecureTokenStorage().leer(), reutilizarToken ? 't-a' : 't-b');
    });
  }

  test('S8 /me 401 en login borra token y no publica autenticación fantasma',
      () async {
    servidor.interceptar = (o) async => o.path == '/usuarios/me'
        ? _json({'detail': 'Caducó'}, 401)
        : servidor.responder(o);
    await auth.iniciarSesion('a@example.test', 'clave-sintetica');
    await auth.cierrePendiente;
    expect(auth.estaAutenticado, isFalse);
    expect(api.token, isNull);
    expect(await SecureTokenStorage().leer(), isNull);
    expect(auth.avisoSesion.value, contains('caducó'));
  });

  test(
      'S8 restore offline conserva token potencialmente válido y reintenta /me',
      () async {
    await SecureTokenStorage().guardar('t-a');
    servidor.offline = true;
    await auth.restaurarSesion();
    expect(auth.estaAutenticado, isFalse);
    expect(api.token, isNull);
    expect(await SecureTokenStorage().leer(), 't-a');
    expect(auth.avisoSesion.value, contains('conexión'));
    servidor.offline = false;
    await auth.restaurarSesion();
    await gastos.inicioPendiente;
    expect(auth.usuario.value?.id, 1);
  });

  for (final fase in ['leer', 'guardar', 'borrar']) {
    test('S8 fallo nativo al $fase es legible y no autentica en memoria',
        () async {
      gastos.onClose();
      await gastos.cierrePendiente;
      auth.onClose();
      final nativo = _AlmacenNativo()
        ..valor = 't-a'
        ..fallarLectura = fase == 'leer'
        ..fallarEscritura = fase == 'guardar'
        ..fallarBorrado = fase == 'borrar';
      auth = AuthController(api: api, almacen: SecureTokenStorage(nativo));
      gastos = GastosController(api: GastosApiService(api: api), auth: auth);
      if (fase == 'leer') {
        await auth.restaurarSesion();
        expect(auth.avisoSesion.value, contains('almacenamiento seguro'));
      } else {
        await auth.iniciarSesion('a@example.test', 'clave-sintetica');
        expect(auth.mensajeError.value, contains('almacenamiento seguro'));
      }
      expect(auth.usuario.value, isNull);
      expect(api.token, isNull);
      expect(gastos.gastos, isEmpty);
    });
  }

  test('S8 escritura segura en curso -> logout -> login B termina con token B',
      () async {
    gastos.onClose();
    await gastos.cierrePendiente;
    auth.onClose();
    final nativo = _AlmacenNativo()
      ..escrituraIniciada = Completer<void>()
      ..permisoEscritura = Completer<void>();
    auth = AuthController(api: api, almacen: SecureTokenStorage(nativo));
    gastos = GastosController(api: GastosApiService(api: api), auth: auth);
    final loginA = auth.iniciarSesion('a@example.test', 'clave-sintetica');
    await nativo.escrituraIniciada!.future;
    final cierre = auth.cerrarSesion();
    expect(api.token, isNull);
    expect(auth.usuario.value, isNull);
    final loginB = auth.iniciarSesion('b@example.test', 'clave-sintetica');
    nativo.permisoEscritura!.complete();
    await Future.wait([loginA, cierre, loginB]);
    await gastos.inicioPendiente;
    expect(nativo.valor, 't-b');
    expect(nativo.eventos,
        ['delete', 'write:t-a', 'delete', 'delete', 'write:t-b']);
    expect(auth.usuario.value?.id, 2);
  });

  for (final operacion in ['POST', 'PATCH', 'DELETE']) {
    test(
        'S8 $operacion confirmado y recarga 503 conserva resultado sin invitar a duplicar',
        () async {
      await entrar();
      await gastos.crear('Antes', 3, 'comida');
      final id = gastos.gastos.single.id;
      servidor.falloRecarga = true;
      if (operacion == 'POST') await gastos.crear('Confirmado', 4, 'comida');
      if (operacion == 'PATCH') await gastos.actualizar(id, {'monto': 9.0});
      if (operacion == 'DELETE') await gastos.eliminar(id);
      expect(gastos.avisoSincronizacion.value,
          contains('se guardó en el servidor'));
      final guardados = Hive.box<dynamic>('gastos_1').get('gastos') as List;
      if (operacion == 'POST') {
        expect(
            gastos.gastos.map((g) => g.descripcion), ['Antes', 'Confirmado']);
        expect(guardados.map((g) => g['descripcion']), ['Antes', 'Confirmado']);
        expect(
            servidor.peticiones
                .where((o) => o.method == 'POST' && o.path == '/gastos/'),
            hasLength(2));
      } else if (operacion == 'PATCH') {
        expect(gastos.gastos.single.monto, 9);
        expect(guardados.single['monto'], 9);
      } else {
        expect(gastos.gastos, isEmpty);
        expect(guardados, isEmpty);
        expect(gastos.totalEnServidor.value, 0);
      }
      expect(gastos.mensajeError.value, isEmpty);
      servidor.falloRecarga = false;
      await gastos.cargarGastos();
      expect(gastos.avisoSincronizacion.value, isEmpty);
    });
  }

  for (final operacion in ['POST', 'PATCH', 'DELETE']) {
    test(
        'S8 logout durante $operacion no aplica su respuesta en memoria/caja B',
        () async {
      await entrar();
      await gastos.crear('Gasto A', 3, 'comida');
      final id = gastos.gastos.single.id;
      final inicio = Completer<void>();
      final permiso = Completer<void>();
      servidor.interceptar = (o) async {
        if (o.method == operacion &&
            o.path.startsWith('/gastos') &&
            o.headers['Authorization'] == 'Bearer t-a') {
          inicio.complete();
          await permiso.future;
        }
        return servidor.responder(o);
      };
      final vieja = switch (operacion) {
        'POST' => gastos.crear('Tardío A', 9, 'comida'),
        'PATCH' => gastos.actualizar(id, {'descripcion': 'Tardío A'}),
        _ => gastos.eliminar(id),
      };
      await inicio.future;
      await auth.cerrarSesion();
      expect(gastos.gastos, isEmpty);
      await entrar('b');
      await gastos.crear('Gasto B', 7, 'comida');
      permiso.complete();
      await vieja;
      expect(auth.usuario.value?.id, 2);
      expect(gastos.gastos.single.descripcion, 'Gasto B');
      expect(
          (Hive.box<dynamic>('gastos_2').get('gastos') as List)
              .single['descripcion'],
          'Gasto B');
      expect(await Hive.boxExists('gastos_1'), isFalse);
    });
  }

  test('S8 categorías se leen del servidor y paginación sigue siendo 20 real',
      () async {
    for (var i = 1; i <= 23; i++) {
      servidor.datos['a']!.add({
        'id': i,
        'descripcion': 'Gasto $i',
        'monto': i.toDouble(),
        'categoria': 'comida',
        'fecha': '2026-10-13'
      });
    }
    await entrar();
    expect(gastos.categorias, servidor.categorias);
    expect(gastos.gastos, hasLength(20));
    expect(gastos.totalEnServidor.value, 23);
    await gastos.cargarMas();
    expect(gastos.gastos, hasLength(23));
    expect(gastos.hayMas, isFalse);
    final peticiones =
        servidor.peticiones.where((o) => o.path == '/gastos/').toList();
    expect(peticiones.map((o) => o.queryParameters), [
      {'skip': 0, 'limit': 20},
      {'skip': 20, 'limit': 20}
    ]);
    final caja = Hive.box<dynamic>('gastos_1');
    expect((caja.get('gastos') as List), hasLength(23));
    expect(caja.keys, unorderedEquals(['gastos', 'total', 'sincronizado']));
    expect(auth.usuario.value, isA<Usuario>());
  });
}
