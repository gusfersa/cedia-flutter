import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:exploraec/controllers/gastos_controller.dart';
import 'package:exploraec/controllers/places_controller.dart' show EstadoCarga;
import 'package:exploraec/models/gasto.dart';
import 'package:exploraec/services/api_exception.dart';
import 'package:exploraec/services/gastos_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _unGasto = '[{"id":1,"descripcion":"Almuerzo en Quito","monto":6.5,'
    '"categoria":"comida","fecha":"2026-10-05"}]';

/// Perfil de prueba para `GET /usuarios/me` (la Sesión 7 lo usa para nombrar
/// la caja `gastos_<id>`).
http.Response _perfil() =>
    http.Response('{"id":1,"email":"alumno@example.test"}', 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Get.reset();
    Get.testMode = true;
    FlutterSecureStorage.setMockInitialValues({});
  });
  setUp(() async {
    await Hive.close();
    Hive.init(Directory.systemTemp.createTempSync('cedia_s07_gastos_').path);
    await Hive.openBox<Map>('favoritos');
  });
  tearDown(() async => Hive.close());

  _pruebasCarrerasS7();
  _pruebasDocentesS7();

  test('Await encadena registro, login, perfil, lista y rechaza doble entrada',
      () async {
    final registro = Completer<http.Response>();
    final login = Completer<http.Response>();
    final lista = Completer<http.Response>();
    final registroIniciado = Completer<void>();
    final loginIniciado = Completer<void>();
    final listaIniciada = Completer<void>();
    final pasos = <String>[];
    final api = GastosApiService(cliente: _clienteS8((peticion) {
      pasos.add(peticion.url.path);
      switch (peticion.url.path) {
        case '/usuarios/':
          registroIniciado.complete();
        case '/usuarios/token':
          loginIniciado.complete();
        case '/gastos/':
          listaIniciada.complete();
      }
      return switch (peticion.url.path) {
        '/usuarios/' => registro.future,
        '/usuarios/token' => login.future,
        '/usuarios/me' => Future.value(_perfil()),
        _ => lista.future,
      };
    }));
    final controller = GastosController(api: api);
    addTearDown(() async {
      await controller.salir();
      controller.onClose();
      await controller.cierrePendiente;
    });
    final entrada = controller.entrar('alumno@example.test', 'clave-prueba');
    await controller.entrar('otra@example.test', 'clave-prueba');
    await registroIniciado.future;
    expect(controller.autenticando.value, isTrue);
    expect(pasos, ['/usuarios/']);
    registro.complete(http.Response('{}', 201));
    await loginIniciado.future;
    expect(pasos, ['/usuarios/', '/usuarios/token']);
    expect(controller.sesionActiva.value, isFalse);
    login.complete(http.Response('{"access_token":"jwt-sintetico"}', 200));
    await listaIniciada.future;
    expect(controller.sesionActiva.value, isTrue);
    expect(
        pasos, ['/usuarios/', '/usuarios/token', '/usuarios/me', '/gastos/']);
    expect(controller.estado.value, EstadoCarga.cargando);
    lista.complete(http.Response('[]', 200, headers: {'x-total-count': '0'}));
    await entrada;
    expect(controller.estado.value, EstadoCarga.exito);
    expect(controller.gastos, isEmpty);
    expect(controller.totalEnServidor.value, 0);
    expect(controller.autenticando.value, isFalse);
  });

  test(
      'Sin conexión con caché muestra lo guardado y al volver el servidor se va',
      () async {
    var desconectado = false;
    final api = GastosApiService(cliente: _clienteS8((peticion) async {
      if (peticion.url.path == '/usuarios/') {
        return http.Response('{"detail":"Correo ya registrado"}', 400);
      }
      if (peticion.url.path == '/usuarios/token') {
        return http.Response('{"access_token":"jwt-sintetico"}', 200);
      }
      if (peticion.url.path == '/usuarios/me') return _perfil();
      if (desconectado) throw http.ClientException('conexión de prueba');
      return http.Response(_unGasto, 200, headers: {'x-total-count': '1'});
    }));
    final controller = GastosController(api: api);
    addTearDown(() async {
      controller.onClose();
      await controller.cierrePendiente;
    });
    await controller.entrar('alumno@example.test', 'clave-prueba');
    expect(controller.sesionActiva.value, isTrue);
    expect(controller.desdeCache.value, isFalse);
    desconectado = true;
    await controller.cargarGastos();
    expect(controller.estado.value, EstadoCarga.exito);
    expect(controller.desdeCache.value, isTrue);
    expect(controller.gastos.single.descripcion, 'Almuerzo en Quito');
    expect(controller.totalEnServidor.value, 1);
    expect(controller.mensajeError.value, isEmpty);
    desconectado = false;
    await controller.cargarGastos();
    expect(controller.estado.value, EstadoCarga.exito);
    expect(controller.desdeCache.value, isFalse);
    expect(controller.mensajeError.value, isEmpty);
  });

  test('401 vuelve al formulario y elimina el token; 422 no inicia sesión',
      () async {
    var registro422 = false;
    final api = GastosApiService(cliente: _clienteS8((peticion) async {
      if (peticion.url.path == '/usuarios/') {
        return registro422
            ? http.Response(
                '{"detail":[{"loc":["body","password"],'
                '"msg":"Contraseña demasiado corta"}]}',
                422,
                headers: {'content-type': 'application/json'})
            : http.Response('{}', 201);
      }
      if (peticion.url.path == '/usuarios/token') {
        return http.Response('{"access_token":"jwt-sintetico"}', 200);
      }
      if (peticion.url.path == '/usuarios/me') return _perfil();
      return http.Response('{"detail":"Credenciales rechazadas"}', 401);
    }));
    final controller = GastosController(api: api);
    addTearDown(() async {
      controller.onClose();
      await controller.cierrePendiente;
    });
    await controller.entrar('alumno@example.test', 'clave-prueba');
    expect(controller.sesionActiva.value, isFalse);
    expect(controller.mensajeAuth.value, contains('Tu sesión caducó'));
    expect(api.tieneToken, isFalse);
    await controller.salir();
    registro422 = true;
    await controller.entrar('nuevo@example.test', 'abc');
    expect(controller.sesionActiva.value, isFalse);
    expect(controller.mensajeAuth.value, contains('contraseña:'));
    expect(controller.autenticando.value, isFalse);
  });

  test('Paginación usa skip acumulado, total remoto y evita doble carga',
      () async {
    final segundaPagina = Completer<http.Response>();
    final paginaIniciada = Completer<void>();
    final saltos = <String>[];
    final api = GastosApiService(cliente: _clienteS8((peticion) async {
      if (peticion.url.path == '/usuarios/') return http.Response('{}', 201);
      if (peticion.url.path == '/usuarios/token') {
        return http.Response('{"access_token":"jwt-sintetico"}', 200);
      }
      if (peticion.url.path == '/usuarios/me') return _perfil();
      saltos.add(peticion.url.queryParameters['skip']!);
      if (saltos.length > 1) {
        paginaIniciada.complete();
        return segundaPagina.future;
      }
      return http.Response(_unGasto, 200, headers: {'x-total-count': '2'});
    }));
    final controller = GastosController(api: api);
    addTearDown(() async {
      controller.onClose();
      await controller.cierrePendiente;
    });
    await controller.entrar('alumno@example.test', 'clave-prueba');
    expect(controller.hayMas, isTrue);
    final carga = controller.cargarMas();
    await controller.cargarMas();
    await paginaIniciada.future;
    expect(saltos, ['0', '1']);
    segundaPagina.complete(http.Response(
        '[{"id":2,"descripcion":"Taxi al terminal","monto":3.25}]', 200,
        headers: {'x-total-count': '2'}));
    await carga;
    expect(controller.gastos.map((gasto) => gasto.id), [1, 2]);
    expect(controller.totalEnServidor.value, 2);
    expect(controller.hayMas, isFalse);
    expect(controller.cargandoMas.value, isFalse);
    await controller.cargarMas();
    expect(saltos, hasLength(2));
  });

  for (final cierre in ['salir', 'onClose']) {
    test('Respuesta tardía tras $cierre no restaura datos ni sesión', () async {
      final lista = Completer<http.Response>();
      final api = GastosApiService(cliente: _clienteS8((peticion) async {
        if (peticion.url.path == '/usuarios/') {
          return http.Response('{}', 201);
        }
        if (peticion.url.path == '/usuarios/token') {
          return http.Response('{"access_token":"jwt-sintetico"}', 200);
        }
        if (peticion.url.path == '/usuarios/me') return _perfil();
        return lista.future;
      }));
      final controller = GastosController(api: api);
      final entrada = controller.entrar('alumno@example.test', 'clave-prueba');
      // Deja que la carga llegue a /gastos/ (pendiente en `lista`).
      await pumpEventQueue();
      final salida = cierre == 'salir' ? controller.salir() : null;
      if (cierre == 'onClose') {
        controller.onClose();
      } else {
        addTearDown(() async {
          controller.onClose();
          await controller.cierrePendiente;
        });
      }
      lista.complete(http.Response(_unGasto, 200));
      await entrada;
      if (salida != null) await salida;
      expect(controller.gastos, isEmpty);
      expect(api.tieneToken, isFalse);
      if (cierre == 'salir') expect(controller.sesionActiva.value, isFalse);
    });
  }
}

typedef _ListaS7 = ({List<Gasto> gastos, int total});

_ListaS7 _listaS7(List<int> ids, {int? total, String descripcion = 'Gasto'}) =>
    (
      gastos: [
        for (final id in ids)
          Gasto(
            id: id,
            descripcion: '$descripcion $id',
            monto: id.toDouble(),
            categoria: 'comida',
            fecha: '2026-10-13',
          ),
      ],
      total: total ?? ids.length,
    );

/// Autenticación real del servicio sobre HTTP falso; /me y la lista se pueden
/// detener en puntos exactos mediante Completer, sin esperas temporizadas.
class _ApiControladaS7 extends GastosApiService {
  factory _ApiControladaS7() {
    late _ApiControladaS7 api;
    api = _ApiControladaS7._(_clienteS8((request) async {
      if (request.url.path == '/usuarios/token') {
        return http.Response('{"access_token":"token-sintetico"}', 200);
      }
      if (request.url.path == '/usuarios/me') {
        final id = await api.perfil();
        return http.Response(
            jsonEncode({'id': id, 'email': 'usuario-$id@example.test'}), 200);
      }
      return http.Response('{}', 201);
    }));
    return api;
  }
  _ApiControladaS7._(http.Client cliente) : super(cliente: cliente);

  Future<int> Function() perfil = () async => 11;
  Future<_ListaS7> Function(int skip, int limit) lista =
      (skip, limit) async => _listaS7([1]);
  final saltos = <int>[];

  @override
  Future<int> obtenerIdUsuario() => perfil();

  @override
  Future<_ListaS7> listarGastos({int skip = 0, int limit = 20}) async {
    if (!tieneToken) {
      throw ApiException('Tu sesión caducó.', statusCode: 401);
    }
    saltos.add(skip);
    return lista(skip, limit);
  }
}

List<int> _idsHiveS7(int usuario) =>
    (Hive.box<dynamic>('gastos_$usuario').get('gastos') as List)
        .map((mapa) => (mapa as Map)['id'] as int)
        .toList();

/// Envuelve una caja REAL en disco y permite detener su escritura, no sustituir
/// el almacenamiento por una lista. Solo se utiliza en la prueba de la cola.
class _CajaControladaS7 implements Box<dynamic> {
  _CajaControladaS7(this.real, this.inicio, this.permiso);
  final Box<dynamic> real;
  final Completer<void> inicio;
  final Completer<void> permiso;
  bool _detener = true;

  @override
  String get name => real.name;

  @override
  bool get isOpen => real.isOpen;

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      real.get(key, defaultValue: defaultValue);

  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) async {
    if (_detener) {
      _detener = false;
      inicio.complete();
      await permiso.future;
    }
    await real.putAll(entries);
  }

  @override
  Future<void> deleteFromDisk() => real.deleteFromDisk();

  @override
  Future<int> clear() => real.clear();

  @override
  Future<void> flush() => real.flush();

  @override
  Future<void> close() => real.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mide la limpieza sobre Hive real: el archivo debe existir al cerrar y solo
/// desaparecer después. Borrar directamente la caja hace fallar la prueba.
class _CajaLimpiezaS7 extends _CajaControladaS7 {
  _CajaLimpiezaS7(Box<dynamic> real)
      : super(real, Completer<void>(), Completer<void>()..complete());

  final pasos = <String>[];

  @override
  Future<int> clear() async {
    pasos.add('clear');
    final eliminados = await super.clear();
    expect(real.isEmpty, isTrue);
    return eliminados;
  }

  @override
  Future<void> flush() async {
    pasos.add('flush');
    await super.flush();
  }

  @override
  Future<void> close() async {
    expect(real.isOpen, isTrue);
    expect(await Hive.boxExists(name), isTrue,
        reason: 'El gestor todavía no debe haber borrado la caja');
    pasos.add('close');
    await super.close();
    expect(real.isOpen, isFalse);
    expect(Hive.isBoxOpen(name), isFalse);
    expect(await Hive.boxExists(name), isTrue,
        reason: 'Cerrar libera la conexión sin borrar el archivo');
  }

  @override
  Future<void> deleteFromDisk() async =>
      throw StateError('La caja debe cerrarse antes del borrado por Hive.');
}

void _pruebasCarrerasS7() {
  GastosController montar(_ApiControladaS7 api) {
    final controller = GastosController(api: api);
    addTearDown(() async {
      await controller.salir();
      controller.onClose();
      await controller.cierrePendiente;
    });
    return controller;
  }

  test('S7 limpieza cierra la caja antes del borrado por Hive', () async {
    final favorito = {'id': 'publico', 'nombre': 'Lugar público'};
    await Hive.box<Map>('favoritos').put('publico', favorito);
    final api = _ApiControladaS7();
    late _CajaLimpiezaS7 caja;
    final repo = GastosRepository(api, abrirCaja: (nombre) async {
      caja = _CajaLimpiezaS7(await Hive.openBox<dynamic>(nombre));
      return caja;
    });
    addTearDown(repo.vaciar);
    addTearDown(api.dispose);
    await api.login('a@example.test', 'clave-prueba');
    await repo.abrirParaUsuario();
    await repo.recargar(limit: 20);
    expect(_idsHiveS7(11), [1]);
    expect(await Hive.boxExists(caja.name), isTrue);

    await repo.vaciar();

    expect(caja.pasos, ['clear', 'flush', 'close']);
    expect(caja.isOpen, isFalse);
    expect(Hive.isBoxOpen(caja.name), isFalse);
    expect(await Hive.boxExists(caja.name), isFalse);
    expect(Hive.box<Map>('favoritos').get('publico'), favorito);
    final reabierta = await Hive.openBox<dynamic>(caja.name);
    expect(reabierta.isEmpty, isTrue);
    await reabierta.close();
  });

  test('S7 A: logout durante /me no crea gastos_11 después de salir', () async {
    final perfil = Completer<int>();
    final perfilIniciado = Completer<void>();
    final api = _ApiControladaS7()
      ..perfil = () {
        perfilIniciado.complete();
        return perfil.future;
      };
    final controller = montar(api);
    final entrada = controller.entrar('a@example.test', 'clave-prueba');
    await perfilIniciado.future;
    expect(api.tieneToken, isTrue);
    await controller.salir();
    perfil.complete(11);
    await entrada;
    expect(controller.sesionActiva.value, isFalse);
    expect(controller.gastos, isEmpty);
    expect(controller.desdeCache.value, isFalse);
    expect(api.tieneToken, isFalse);
    expect(await Hive.boxExists('gastos_11'), isFalse);
    expect(api.saltos, isEmpty);
  });

  test('S7 B: R1 lenta no pisa Hive de R2 ni reaparece al quedar offline',
      () async {
    final api = _ApiControladaS7();
    final controller = montar(api);
    await controller.entrar('a@example.test', 'clave-prueba');
    expect(controller.gastos.map((gasto) => gasto.id), [1]);
    final respuestaVieja = Completer<_ListaS7>();
    final r1Iniciada = Completer<void>();
    api.lista = (skip, limit) {
      r1Iniciada.complete();
      return respuestaVieja.future;
    };
    final r1 = controller.cargarGastos();
    await r1Iniciada.future;
    api.lista = (skip, limit) async => _listaS7([2]);
    await controller.cargarGastos();
    respuestaVieja.complete(_listaS7([3]));
    await r1;
    expect(controller.gastos.map((gasto) => gasto.id), [2]);
    expect(_idsHiveS7(11), [2], reason: 'Leer Hive antes del fallback');
    expect(Hive.box('gastos_11').get('total'), 1);
    expect(Hive.box('gastos_11').keys,
        unorderedEquals(['gastos', 'total', 'sincronizado']),
        reason: 'La caché no guarda token ni credenciales');
    api.lista = (skip, limit) async => throw ApiException('Sin conexión');
    await controller.cargarGastos();
    expect(controller.desdeCache.value, isTrue);
    expect(controller.gastos.map((gasto) => gasto.id), [2]);
    expect(controller.hayMas, isFalse);
  });

  for (final paginar in [false, true]) {
    test(
        'S7 C: 401 al ${paginar ? 'paginar' : 'recargar'} vacía memoria/disco y conserva favoritos',
        () async {
      final favorito = {'id': 'publico', 'nombre': 'Lugar público'};
      await Hive.box<Map>('favoritos').put('publico', favorito);
      final api = _ApiControladaS7()
        ..lista = (skip, limit) async => _listaS7([1], total: 2);
      final controller = montar(api);
      await controller.entrar('a@example.test', 'clave-prueba');
      expect(await Hive.boxExists('gastos_11'), isTrue);
      if (!paginar) {
        api.lista = (skip, limit) async => throw ApiException('Sin conexión');
        await controller.cargarGastos();
        expect(controller.desdeCache.value, isTrue);
      }
      final estadoAlInvalidar =
          Completer<({bool sinGastos, bool desdeCache, bool token})>();
      final escucha = controller.sesionActiva.listen((activa) {
        if (!activa && !estadoAlInvalidar.isCompleted) {
          estadoAlInvalidar.complete((
            sinGastos: controller.gastos.isEmpty,
            desdeCache: controller.desdeCache.value,
            token: api.tieneToken,
          ));
        }
      });
      addTearDown(escucha.cancel);
      api.lista = (skip, limit) async =>
          throw ApiException('Tu sesión caducó.', statusCode: 401);
      final operacion =
          paginar ? controller.cargarMas() : controller.cargarGastos();
      final inmediato = await estadoAlInvalidar.future;
      expect(inmediato, (sinGastos: true, desdeCache: false, token: false));
      await operacion;
      expect(controller.sesionActiva.value, isFalse);
      expect(api.tieneToken, isFalse);
      expect(controller.gastos, isEmpty);
      expect(controller.totalEnServidor.value, 0);
      expect(controller.desdeCache.value, isFalse);
      expect(controller.ultimaSincronizacion, 'desconocida');
      expect(controller.mensajeAuth.value, startsWith('Tu sesión caducó'));
      expect(await Hive.boxExists('gastos_11'), isFalse);
      expect(Hive.box<Map>('favoritos').get('publico'), favorito);
      expect(await Hive.boxExists('favoritos'), isTrue);
    });
  }

  for (final codigo in [400, 403, 404, 422]) {
    test('S7 HTTP $codigo con caché válida informa error sin fallback',
        () async {
      final api = _ApiControladaS7();
      final controller = montar(api);
      await controller.entrar('a@example.test', 'clave-prueba');
      api.lista = (skip, limit) async => throw ApiException('Sin conexión');
      await controller.cargarGastos();
      expect(controller.desdeCache.value, isTrue);
      api.lista = (skip, limit) async =>
          throw ApiException('Solicitud rechazada $codigo', statusCode: codigo);
      await controller.cargarGastos();
      expect(controller.estado.value, EstadoCarga.error);
      expect(controller.mensajeError.value, 'Solicitud rechazada $codigo');
      expect(controller.desdeCache.value, isFalse);
      expect(controller.sesionActiva.value, isTrue);
      expect(api.tieneToken, isTrue);
      expect(_idsHiveS7(11), [1]);
    });
  }

  test('S7 D: cargarMas pendiente no mezcla páginas tras una nueva recarga',
      () async {
    final api = _ApiControladaS7()
      ..lista = (skip, limit) async => _listaS7([1], total: 2);
    final controller = montar(api);
    await controller.entrar('a@example.test', 'clave-prueba');
    final paginaVieja = Completer<_ListaS7>();
    final paginaIniciada = Completer<void>();
    api.lista = (skip, limit) {
      expect(skip, 1);
      paginaIniciada.complete();
      return paginaVieja.future;
    };
    final mas = controller.cargarMas();
    await paginaIniciada.future;
    api.lista = (skip, limit) async => _listaS7([2]);
    await controller.cargarGastos();
    paginaVieja.complete(_listaS7([3], total: 2));
    await mas;
    expect(controller.gastos.map((gasto) => gasto.id), [2]);
    expect(controller.cargandoMas.value, isFalse);
    expect(controller.totalEnServidor.value, 1);
    expect(_idsHiveS7(11), [2]);
    api.lista = (skip, limit) async => throw ApiException('Sin conexión');
    await controller.cargarGastos();
    expect(controller.desdeCache.value, isTrue);
    expect(controller.gastos.map((gasto) => gasto.id), [2]);
  });

  test('S7 D: /me tardío de A no toca la sesión ni la caja de B', () async {
    final perfilA = Completer<int>();
    final perfilIniciado = Completer<void>();
    final api = _ApiControladaS7()
      ..perfil = () {
        perfilIniciado.complete();
        return perfilA.future;
      };
    final controller = montar(api);
    final entradaA = controller.entrar('a@example.test', 'clave-prueba');
    await perfilIniciado.future;
    await controller.salir();
    api.perfil = () async => 22;
    api.lista = (skip, limit) async => _listaS7([2]);
    await controller.entrar('b@example.test', 'clave-prueba');
    perfilA.complete(11);
    await entradaA;
    expect(controller.sesionActiva.value, isTrue);
    expect(api.tieneToken, isTrue);
    expect(controller.gastos.map((gasto) => gasto.id), [2]);
    expect(await Hive.boxExists('gastos_11'), isFalse);
    expect(await Hive.boxExists('gastos_22'), isTrue);
    expect(_idsHiveS7(22), [2]);
  });

  for (final idB in [11, 22]) {
    test('S7 apertura tardía de A preserva la caja de la nueva sesión $idB',
        () async {
      final abierta = Completer<void>();
      final permiso = Completer<void>();
      final api = _ApiControladaS7();
      var aperturas = 0;
      final repo = GastosRepository(api, abrirCaja: (nombre) async {
        final caja = await Hive.openBox<dynamic>(nombre);
        if (++aperturas == 1) {
          abierta.complete();
          await permiso.future;
        }
        return caja;
      });
      addTearDown(repo.vaciar);
      addTearDown(api.dispose);
      await api.login('a@example.test', 'clave-prueba');
      final abrirA = repo.abrirParaUsuario();
      await abierta.future;
      final salirA = repo.vaciar();
      api.perfil = () async => idB;
      final abrirB = repo.abrirParaUsuario();
      permiso.complete();
      await Future.wait([abrirA, salirA, abrirB]);
      await repo.recargar(limit: 20);
      expect(await Hive.boxExists('gastos_$idB'), isTrue);
      expect(_idsHiveS7(idB), [1]);
      if (idB != 11) expect(await Hive.boxExists('gastos_11'), isFalse);
    });
  }

  test('S7 escrituras en curso se ordenan; cerrar/reabrir Hive conserva R2',
      () async {
    final inicio = Completer<void>();
    final permiso = Completer<void>();
    final api = _ApiControladaS7();
    final repo = GastosRepository(api,
        abrirCaja: (nombre) async => _CajaControladaS7(
            await Hive.openBox<dynamic>(nombre), inicio, permiso));
    addTearDown(repo.vaciar);
    addTearDown(api.dispose);
    await api.login('a@example.test', 'clave-prueba');
    await repo.abrirParaUsuario();
    final r1 = repo.recargar(limit: 20);
    await inicio.future;
    final r2Iniciada = Completer<void>();
    api.lista = (skip, limit) async {
      r2Iniciada.complete();
      return _listaS7([2]);
    };
    final r2 = repo.recargar(limit: 20);
    await r2Iniciada.future;
    permiso.complete();
    await Future.wait([r1, r2]);
    expect(_idsHiveS7(11), [2]);
    await Hive.box('gastos_11').close();
    await Hive.openBox<dynamic>('gastos_11');
    expect(_idsHiveS7(11), [2],
        reason: 'Datos leídos nuevamente desde el disco');
  });

  test('S7 páginas acumuladas actualizan IDs repetidos sin duplicarlos',
      () async {
    final api = _ApiControladaS7()
      ..lista = (skip, limit) async => _listaS7([1, 1], total: 3);
    final controller = montar(api);
    await controller.entrar('a@example.test', 'clave-prueba');
    expect(controller.gastos.map((gasto) => gasto.id), [1]);
    expect(_idsHiveS7(11), [1]);
    api.lista = (skip, limit) async =>
        _listaS7([1, 2], total: 3, descripcion: 'Actualizado');
    await controller.cargarMas();
    expect(controller.gastos.map((gasto) => gasto.id), [1, 2]);
    expect(controller.gastos.first.descripcion, 'Actualizado 1');
    expect(_idsHiveS7(11), [1, 2]);
    api.lista = (skip, limit) async => _listaS7([3], total: 3);
    await controller.cargarMas();
    expect(api.saltos, [0, 1, 2]);
    expect(controller.gastos.map((gasto) => gasto.id), [1, 2, 3]);
    expect(_idsHiveS7(11), [1, 2, 3]);
    expect(controller.hayMas, isFalse);
    api.lista = (skip, limit) async => throw ApiException('Sin conexión');
    await controller.cargarGastos();
    expect(controller.desdeCache.value, isTrue);
    expect(controller.gastos.map((gasto) => gasto.id), [1, 2, 3]);
    expect(controller.totalEnServidor.value, 3);
  });

  test('S7 login tardío tras logout no repone token ni reemplaza token B',
      () async {
    final tokenA = Completer<http.Response>();
    final loginAIniciado = Completer<void>();
    final autorizaciones = <String?>[];
    var logins = 0;
    final api = GastosApiService(cliente: _clienteS8((request) async {
      if (request.url.path == '/usuarios/') return http.Response('{}', 201);
      if (request.url.path == '/usuarios/token') {
        logins++;
        if (request.bodyFields['username'] == 'a@example.test') {
          loginAIniciado.complete();
          return tokenA.future;
        }
        return http.Response('{"access_token":"token-b-sintetico"}', 200);
      }
      autorizaciones.add(request.headers['Authorization']);
      if (request.url.path == '/usuarios/me') {
        return http.Response('{"id":22,"email":"b@example.test"}', 200);
      }
      return http.Response('[{"id":2}]', 200);
    }));
    final controller = GastosController(api: api);
    addTearDown(() async {
      await controller.salir();
      controller.onClose();
      await controller.cierrePendiente;
    });
    final entradaA = controller.entrar('a@example.test', 'clave-prueba');
    await loginAIniciado.future;
    await controller.entrar('b@example.test', 'clave-prueba');
    expect(logins, 1, reason: 'No permite doble entrar mientras autentica');
    await controller.salir();
    expect(api.tieneToken, isFalse);
    await controller.entrar('b@example.test', 'clave-prueba');
    tokenA.complete(http.Response('{"access_token":"token-a-sintetico"}', 200));
    await entradaA;
    await controller.cargarGastos();
    expect(autorizaciones, everyElement('Bearer token-b-sintetico'));
    expect(logins, 2);
    expect(controller.sesionActiva.value, isTrue);
    expect(api.tieneToken, isTrue);
    expect(controller.gastos.map((gasto) => gasto.id), [2]);
    expect(_idsHiveS7(22), [2]);
    expect(await Hive.boxExists('gastos_11'), isFalse);
  });
}

// Fuente docente local: reference-sesion07/test/gastos_controller_test.dart.
http.Response _jsonDocente(Object body, int code,
        {Map<String, String> h = const {}}) =>
    http.Response(jsonEncode(body), code,
        headers: {'content-type': 'application/json', ...h});

/// Servidor falso: usuarios y gastos en memoria según el contrato real.
MockClient _servidorDocente({
  List<Map<String, dynamic>> gastos = const [],
  bool registroDuplicado = false,
  bool sinRed = false,
  int? falloListar,
}) {
  return _clienteS8((req) async {
    if (sinRed) throw const SocketException('sin red');
    final ruta = req.url.path;
    if (ruta == '/usuarios/' && req.method == 'POST') {
      final b = jsonDecode(req.body) as Map;
      if ((b['password'] as String).length < 8) {
        return _jsonDocente({
          'detail': [
            {
              'type': 'string_too_short',
              'loc': ['body', 'password'],
              'msg': 'String should have at least 8 characters'
            }
          ]
        }, 422);
      }
      if (registroDuplicado) {
        return _jsonDocente({'detail': 'El email ya está registrado'}, 400);
      }
      return _jsonDocente({'id': 1, 'email': b['email']}, 201);
    }
    if (ruta == '/usuarios/token') {
      expect(req.headers['content-type'],
          contains('application/x-www-form-urlencoded'));
      expect(req.bodyFields['username'], isNotEmpty);
      return _jsonDocente({'access_token': 'tok', 'token_type': 'bearer'}, 200);
    }
    if (ruta == '/usuarios/me') {
      return _jsonDocente({'id': 1, 'email': 'a@b.com'}, 200);
    }
    if (ruta == '/gastos/') {
      if (falloListar != null) {
        return _jsonDocente({'detail': 'x'}, falloListar);
      }
      expect(req.headers['authorization'], 'Bearer tok');
      return _jsonDocente(gastos, 200,
          h: {'x-total-count': '${gastos.length}'});
    }
    return _jsonDocente({'detail': 'no existe'}, 404);
  });
}

void _pruebasDocentesS7() {
  group('Diez casos docentes S7', () {
    late MockClient servidorActual;

    Future<void> conServidor(
      Future<void> Function() operacion,
      MockClient Function() crear,
    ) async {
      servidorActual = crear();
      addTearDown(servidorActual.close);
      await operacion();
    }

    Future<GastosController> entrar(MockClient cliente,
        {String pass = 'clave-1234'}) async {
      servidorActual = cliente;
      addTearDown(cliente.close);
      // La API S6 conserva un cliente, por eso el montaje cambia el servidor
      // delegado explícitamente en vez de confiar en zonas http.runWithClient.
      final api =
          GastosApiService(cliente: _ClienteDocenteS7(() => servidorActual));
      final g = GastosController(api: api);
      addTearDown(() async {
        await g.salir();
        g.onClose();
        await g.cierrePendiente;
      });
      await g.entrar('a@b.com', pass);
      return g;
    }

    final dosGastos = [
      {
        'id': 1,
        'descripcion': 'Almuerzo',
        'monto': 6.5,
        'categoria': 'comida',
        'fecha': '2026-10-05'
      },
      {
        'id': 2,
        'descripcion': 'Taxi',
        'monto': 3,
        'categoria': 'transporte',
        'fecha': '2026-10-05'
      },
    ];

    test('usuario nuevo: registro -> login -> lista vacía', () async {
      final g = await entrar(_servidorDocente());
      expect(g.sesionActiva.value, isTrue);
      expect(g.estado.value, EstadoCarga.exito);
      expect(g.gastos, isEmpty);
    });

    test('éxito: carga gastos y total (monto entero o decimal), sin banner',
        () async {
      final g = await entrar(_servidorDocente(gastos: dosGastos));
      expect(g.gastos.length, 2);
      expect(g.totalEnServidor.value, 2);
      expect(g.gastos[1].monto, 3.0);
      expect(g.desdeCache.value, isFalse);
    });

    test('400 al registrar (correo existente) se ignora y sigue al login',
        () async {
      final g = await entrar(_servidorDocente(registroDuplicado: true));
      expect(g.sesionActiva.value, isTrue);
    });

    test('422 al registrar: mensaje legible con el campo, sin sesión',
        () async {
      final g = await entrar(_servidorDocente(), pass: 'abc');
      expect(g.sesionActiva.value, isFalse);
      expect(g.mensajeAuth.value, startsWith('Datos inválidos — contraseña:'));
    });

    test('5xx sin nada en caché: error legible', () async {
      final g = await entrar(_servidorDocente(falloListar: 503));
      expect(g.estado.value, EstadoCarga.error);
      expect(g.mensajeError.value,
          'El servidor tuvo un problema. Inténtalo más tarde.');
    });

    // --- Pruebas de la Sesión 7: fallan hasta completar el Paso 2 / el Paso 5 ---

    test(
        'Paso 2 — sin conexión con caché: muestra lo guardado y marca desdeCache',
        () async {
      final g = await entrar(_servidorDocente(gastos: dosGastos));
      await conServidor(
          () => g.cargarGastos(), () => _servidorDocente(sinRed: true));
      expect(g.estado.value, EstadoCarga.exito);
      expect(g.desdeCache.value, isTrue);
      expect(g.gastos.length, 2);
      expect(g.ultimaSincronizacion, isNot('desconocida'));
    });

    test('Paso 2 — 5xx con caché: también cae a la caché', () async {
      final g = await entrar(_servidorDocente(gastos: dosGastos));
      await conServidor(
          () => g.cargarGastos(), () => _servidorDocente(falloListar: 503));
      expect(g.desdeCache.value, isTrue);
      expect(g.gastos.length, 2);
    });

    test('Paso 2 — al volver el servidor, el banner desaparece', () async {
      final g = await entrar(_servidorDocente(gastos: dosGastos));
      await conServidor(
          () => g.cargarGastos(), () => _servidorDocente(sinRed: true));
      expect(g.desdeCache.value, isTrue);
      expect(g.gastos.length, 2);
      await conServidor(
          () => g.cargarGastos(), () => _servidorDocente(gastos: dosGastos));
      expect(g.desdeCache.value, isFalse);
    });

    test('Paso 2 — un 401 NO usa la caché: vuelve al formulario', () async {
      final g = await entrar(_servidorDocente(gastos: dosGastos));
      await conServidor(
          () => g.cargarGastos(), () => _servidorDocente(falloListar: 401));
      expect(g.sesionActiva.value, isFalse);
      expect(g.desdeCache.value, isFalse);
      expect(g.mensajeAuth.value, startsWith('Tu sesión caducó'));
    });

    test('Paso 5 — cerrar sesión borra la caja del usuario', () async {
      final g = await entrar(_servidorDocente(gastos: dosGastos));
      expect(await Hive.boxExists('gastos_1'), isTrue);
      await g.salir();
      expect(await Hive.boxExists('gastos_1'), isFalse);
      expect(g.sesionActiva.value, isFalse);
    });
  });
}

/// Delega una petición aún sin finalizar. Encadenar dos MockClient.send sobre
/// la misma Request la finalizaría dos veces y no ejercitaría el contrato HTTP.
class _ClienteDocenteS7 extends http.BaseClient {
  _ClienteDocenteS7(this.actual);
  final http.Client Function() actual;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      actual().send(request);
}

// Categorías requeridas en S8, independientes de los escenarios S7 de lista.
MockClient _clienteS8(Future<http.Response> Function(http.Request) responder) =>
    MockClient((request) async {
      if (request.url.path == '/gastos/categorias') {
        return http.Response(
            jsonEncode({
              'categorias': [
                'comida',
                'transporte',
                'entretenimiento',
                'otros'
              ],
              'limite_por_categoria': 500.0
            }),
            200,
            headers: {'content-type': 'application/json'});
      }
      return responder(request);
    });
