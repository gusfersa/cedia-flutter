// Dos carreras S8 entre instancias; sin Keychain, HTTP ni datos del usuario.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exploraec/controllers/auth_controller.dart';
import 'package:exploraec/repositories/gastos_repository.dart';
import 'package:exploraec/services/api_client.dart';
import 'package:exploraec/services/gastos_api_service.dart';
import 'package:exploraec/services/secure_token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Solo se sustituye el transporte; Auth, ApiClient y el repositorio son reales.
class _ServidorLocal implements HttpClientAdapter {
  bool sinRed = false;
  final rutas = <String>[];

  ResponseBody _json(Object cuerpo, {int? total}) =>
      ResponseBody.fromString(jsonEncode(cuerpo), 200, headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (total != null) 'x-total-count': ['$total'],
      });

  @override
  Future<ResponseBody> fetch(RequestOptions opciones, Stream<Uint8List>? cuerpo,
      Future<void>? cancelar) async {
    rutas.add(opciones.path);
    if (sinRed) {
      throw DioException(
        requestOptions: opciones,
        type: DioExceptionType.connectionError,
      );
    }
    if (opciones.path == '/usuarios/token') {
      final email = (opciones.data as Map)['username'];
      if (email != 'a@example.test' && email != 'b@example.test') {
        throw StateError('Identidad sintética desconocida');
      }
      return _json({
        'access_token':
            email == 'a@example.test' ? 'sintetico-a' : 'sintetico-b',
      });
    }
    final identidad = opciones.headers['Authorization'];
    if (identidad != 'Bearer sintetico-a' &&
        identidad != 'Bearer sintetico-b') {
      throw StateError('Petición sin identidad sintética válida');
    }
    if (opciones.path == '/usuarios/me') {
      final esA = identidad == 'Bearer sintetico-a';
      return _json({
        'id': esA ? 11 : 22,
        'email': esA ? 'a@example.test' : 'b@example.test',
      });
    }
    if (opciones.path == '/gastos/' && opciones.method == 'GET') {
      return _json([
        {
          'id': 1,
          'descripcion': 'Gasto sintético conservado',
          'monto': 3.5,
          'categoria': 'transporte',
          'fecha': '2026-10-13',
        },
      ], total: 1);
    }
    throw StateError('Ruta no prevista: ${opciones.path}');
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _nuevoApi(_ServidorLocal servidor) => ApiClient(
      dio: Dio(BaseOptions(baseUrl: 'http://sintetico.invalid'))
        ..httpClientAdapter = servidor,
    );

/// Backend físico compartido. SecureTokenStorage y su cola interior no se imitan.
/// La traza contiene operaciones, nunca valores de tokens.
class _BackendSeguro extends FlutterSecureStorage {
  final escrituraIniciada = Completer<void>();
  final permisoEscritura = Completer<void>();
  final eventos = <String>[];
  String? _valor;
  Zone? zonaLectura;

  bool get vacio => _valor == null;

  void liberar() {
    if (!permisoEscritura.isCompleted) permisoEscritura.complete();
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    eventos.add('read');
    zonaLectura = Zone.current;
    return _valor;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    eventos.add('write:inicia');
    if (!escrituraIniciada.isCompleted) {
      escrituraIniciada.complete();
      await permisoEscritura.future;
    }
    _valor = value;
    eventos.add('write:termina');
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    eventos.add('delete');
    _valor = null;
  }
}

/// Todas las operaciones usadas se delegan a la caja Hive real capturada.
class _CajaConFlushRetenido implements Box<dynamic> {
  _CajaConFlushRetenido(this.real, this.eventos);

  final Box<dynamic> real;
  final List<String> eventos;
  final flushIniciado = Completer<void>();
  final permisoFlush = Completer<void>();

  void liberar() {
    if (!permisoFlush.isCompleted) permisoFlush.complete();
  }

  @override
  String get name => real.name;
  @override
  bool get isOpen => real.isOpen;
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      real.get(key, defaultValue: defaultValue);
  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) => real.putAll(entries);
  @override
  Future<int> clear() => real.clear();

  @override
  Future<void> flush() async {
    eventos.add('flushA:inicia');
    if (!flushIniciado.isCompleted) flushIniciado.complete();
    await permisoFlush.future;
    await real.flush();
    eventos.add('flushA:termina');
  }

  @override
  Future<void> close() async {
    await real.close();
    eventos.add('closeA:termina');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
      'Operación de Box no delegada: ${invocation.memberName}');
}

void main() {
  testWidgets(
    'logout A precede a restauración B con escritura segura retenida',
    (tester) async {
      // Deja una cola completada en FakeAsync antes de usar la zona real.
      // Una cola static Future que retenga esa zona bloquearía runAsync.
      final apiPrevio = _nuevoApi(_ServidorLocal());
      final authPrevio = AuthController(
        api: apiPrevio,
        almacen: SecureTokenStorage(_BackendSeguro()),
      );
      var previoTerminado = false;
      final previo =
          authPrevio.cerrarSesion().then((_) => previoTerminado = true);
      await tester.pump();
      expect(previoTerminado, isTrue);
      await previo;
      authPrevio.onClose();
      apiPrevio.dispose();

      await tester.runAsync(() async {
        final backend = _BackendSeguro();
        final apiA = _nuevoApi(_ServidorLocal());
        final servidorB = _ServidorLocal();
        final apiB = _nuevoApi(servidorB);
        final authA = AuthController(
          api: apiA,
          almacen: SecureTokenStorage(backend),
        );
        AuthController? authB;
        Future<void>? logoutA;
        Future<void>? restauracionB;
        final loginA = authA.iniciarSesion('a@example.test', 'clave-sintetica');
        try {
          await backend.escrituraIniciada.future
              .timeout(const Duration(seconds: 5));
          expect(authA.usuario.value, isNull);
          final inicioCarrera = backend.eventos.length;
          logoutA = authA.cerrarSesion(); // Deliberadamente sin await.
          authB =
              AuthController(api: apiB, almacen: SecureTokenStorage(backend));
          final zonaB = Zone.current.fork();
          restauracionB = zonaB.run<Future<void>>(authB.restaurarSesion);
          await Future<void>(() {}); // Barrera de event loop; no sleep.
          backend.liberar();
          await Future.wait([loginA, logoutA, restauracionB]);

          expect(
            backend.eventos.skip(inicioCarrera).toList(),
            ['write:termina', 'delete', 'read'],
            reason: 'El logout pedido antes debe borrar antes de leer desde B',
          );
          expect(backend.vacio, isTrue);
          expect(authA.usuario.value, isNull);
          expect(apiA.token, isNull);
          expect(authB.usuario.value, isNull);
          expect(apiB.token, isNull);
          expect(servidorB.rutas, isEmpty);
          expect(backend.zonaLectura, same(zonaB),
              reason: 'La operación encolada debe conservar la zona de B');

          // La cola debe seguir sirviendo una sesión nueva después del logout.
          await authB.iniciarSesion('b@example.test', 'clave-sintetica');
          expect(authB.usuario.value?.id, 22);
          expect(backend.vacio, isFalse);
          expect(servidorB.rutas, ['/usuarios/token', '/usuarios/me']);
        } finally {
          backend.liberar();
          await Future.wait([
            loginA,
            if (logoutA != null) logoutA,
            if (restauracionB != null) restauracionB,
          ]);
          authA.onClose();
          authB?.onClose();
          apiA.dispose();
          apiB.dispose();
        }
      });
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'cerrar repo A termina antes de abrir repo B para el mismo usuario Hive',
    (tester) async {
      final apiPrevio = _nuevoApi(_ServidorLocal());
      final repoPrevio = GastosRepository(GastosApiService(api: apiPrevio));
      var previoTerminado = false;
      final previo = repoPrevio.cerrar().then((_) => previoTerminado = true);
      await tester.pump();
      expect(previoTerminado, isTrue);
      await previo;
      apiPrevio.dispose();

      await tester.runAsync(() async {
        final raiz = await Directory('.tmp/colas-multicontrolador')
            .create(recursive: true);
        final datos = await raiz.createTemp('hive_');
        Hive.init(datos.path);
        final favoritos = await Hive.openBox<bool>('favoritos');
        await favoritos.put('lugar-publico', true);
        final eventos = <String>[];
        final servidor = _ServidorLocal();
        final api = _nuevoApi(servidor)..token = 'sintetico-a';
        final servicio = GastosApiService(api: api);
        _CajaConFlushRetenido? capturada;
        Zone? zonaAperturaB;
        final zonaB = Zone.current.fork();
        final repoA = GastosRepository(servicio, abrirCaja: (nombre) async {
          final caja = await Hive.openBox<dynamic>(nombre);
          return capturada = _CajaConFlushRetenido(caja, eventos);
        });
        final repoB = GastosRepository(servicio, abrirCaja: (nombre) async {
          zonaAperturaB = Zone.current;
          eventos.add('openB:solicita');
          if (capturada!.real.isOpen) {
            throw StateError('B intentó abrir antes del cierre real de A');
          }
          final caja = await Hive.openBox<dynamic>(nombre);
          eventos.add('openB:termina');
          return caja;
        });
        Future<void>? cerrarA;
        Future<Object?>? resultadoB;
        try {
          await repoA.abrirParaUsuario(usuarioId: 11);
          final inicial = await repoA.recargar(limit: 20);
          expect(inicial.gastos.map((g) => g.id).toList(), [1]);
          expect(inicial.desdeCache, isFalse);
          expect((capturada!.real.get('gastos') as List).single['id'], 1);

          cerrarA = repoA.cerrar();
          await capturada!.flushIniciado.future
              .timeout(const Duration(seconds: 5));
          final abrirB = zonaB.run(() => repoB.abrirParaUsuario(usuarioId: 11));
          // Observa el error desde que se inicia para evitar errores huérfanos.
          resultadoB = abrirB.then<Object?>((_) => null,
              onError: (Object error) => error);
          await Future<void>(() {});
          final abrioMientrasFlush = eventos.contains('openB:solicita');
          capturada!.liberar();
          await cerrarA;
          final errorB = await resultadoB;

          expect(abrioMientrasFlush, isFalse,
              reason:
                  'La apertura de B debe esperar al flush y close de A; $eventos');
          expect(errorB, isNull);
          expect(eventos, [
            'flushA:inicia',
            'flushA:termina',
            'closeA:termina',
            'openB:solicita',
            'openB:termina',
          ]);
          expect(capturada!.real.isOpen, isFalse);
          expect(zonaAperturaB, same(zonaB),
              reason: 'El opener encolado debe conservar la zona de B');
          expect(Hive.isBoxOpen('gastos_11'), isTrue);
          expect(
              (Hive.box<dynamic>('gastos_11').get('gastos') as List)
                  .single['id'],
              1);

          final remoto = await repoB.recargar(limit: 20);
          expect(remoto.desdeCache, isFalse);
          expect(remoto.gastos.map((g) => g.id).toList(), [1]);
          servidor.sinRed = true;
          final cache = await repoB.recargar(limit: 20);
          expect(cache.desdeCache, isTrue);
          expect(cache.total, 1);
          expect(cache.gastos.single.toMap(), remoto.gastos.single.toMap());
          expect(Hive.isBoxOpen('favoritos'), isTrue);
          expect(favoritos.get('lugar-publico'), isTrue);
          await favoritos.flush();
          await favoritos.close();
          final favoritosReabiertos = await Hive.openBox<bool>('favoritos');
          expect(favoritosReabiertos.get('lugar-publico'), isTrue);
        } finally {
          capturada?.liberar();
          if (cerrarA != null) await cerrarA;
          if (resultadoB != null) await resultadoB;
          await repoA.cerrar();
          await repoB.cerrar();
          api.dispose();
          await Hive.close();
          // Se conservan los datos sintéticos; ninguna limpieza destructiva.
        }
      });
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
