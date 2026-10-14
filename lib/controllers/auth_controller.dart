// Basado en Patricio-CEDIA/exploraec-app, Sesión 8.
import 'dart:async';

import 'package:get/get.dart';

import '../models/usuario.dart';
import '../services/api_client.dart';
import '../services/secure_token_storage.dart';

typedef LimpiezaSesion = Future<void> Function(bool borrarCache);

/// Único dueño de la sesión. Publica usuario solo tras validar /me y completar
/// el almacenamiento seguro. Toda continuación comprueba su generación.
class AuthController extends GetxController {
  AuthController({ApiClient? api, SecureTokenStorage? almacen})
      : _api = api ?? Get.find<ApiClient>(),
        _almacen = almacen ?? SecureTokenStorage() {
    _alCaducar = () {
      sesionCaducada();
    };
    _api.alSesionCaducada = _alCaducar;
  }

  final ApiClient _api;
  final SecureTokenStorage _almacen;
  late final void Function() _alCaducar;
  final _limpiezas = <LimpiezaSesion>[];
  final Rxn<Usuario> usuario = Rxn<Usuario>();
  final RxBool cargando = false.obs;
  final RxBool restaurando = false.obs;
  final RxString mensajeError = ''.obs;
  final RxString avisoSesion = ''.obs;
  int _generacion = 0;
  bool _cerrado = false;
  static final _cola = <Future<void> Function()>[];
  static bool _ocupada = false;
  Future<void>? _cierrePendiente;
  Future<void>? _restauracion;

  bool get estaAutenticado => usuario.value != null;
  int get generacion => _generacion;
  ApiClient get api => _api;
  Future<void> get cierrePendiente => _cierrePendiente ?? Future<void>.value();
  Future<void> get restauracion => _restauracion ?? Future<void>.value();
  bool _vigente(int generacion) => !_cerrado && generacion == _generacion;

  void agregarLimpieza(LimpiezaSesion limpieza) => _limpiezas.add(limpieza);
  void quitarLimpieza(LimpiezaSesion limpieza) => _limpiezas.remove(limpieza);

  @override
  void onInit() {
    super.onInit();
    _restauracion = restaurarSesion();
  }

  Future<T> _enAlmacen<T>(Future<T> Function() accion) {
    final resultado = Completer<T>();
    _cola.add(Zone.current.bindCallback(() async {
      try {
        resultado.complete(await accion());
      } catch (error, stack) {
        resultado.completeError(error, stack);
      }
    }));
    _procesarCola();
    return resultado.future;
  }

  Future<void> _procesarCola() async {
    if (_ocupada) return;
    _ocupada = true;
    while (_cola.isNotEmpty) {
      await _cola.removeAt(0)();
    }
    _ocupada = false;
  }

  Future<void> iniciarSesion(String email, String password) =>
      _autenticar(email, password, registrar: false);

  /// La opción conserva la fachada de S6/S7; la pantalla de registro usa el
  /// comportamiento normal: un correo duplicado se informa y no hace login.
  Future<void> registrar(String email, String password,
          {bool continuarSiExiste = false}) =>
      _autenticar(email, password,
          registrar: true, continuarSiExiste: continuarSiExiste);

  Future<void> _autenticar(String email, String password,
      {required bool registrar, bool continuarSiExiste = false}) async {
    if (_cerrado || cargando.value) return;
    final generacion = ++_generacion;
    // Cancela una restauración pendiente antes de iniciar la sesión nueva.
    _api.token = null;
    cargando.value = true;
    final limpiezas = [for (final limpiar in _limpiezas) limpiar(true)];
    usuario.value = null;
    restaurando.value = false;
    mensajeError.value = '';
    avisoSesion.value = '';
    try {
      await Future.wait(limpiezas);
      await _enAlmacen(() async {
        if (_vigente(generacion)) await _almacen.borrar();
      });
      if (!_vigente(generacion)) return;
      if (registrar) {
        try {
          await _api
              .post('/usuarios/', data: {'email': email, 'password': password});
        } on ApiException catch (error) {
          if (!continuarSiExiste || error.statusCode != 400) rethrow;
        }
      }
      if (!_vigente(generacion)) return;
      final r = await _api.post('/usuarios/token',
          data: {'username': email, 'password': password},
          options: Options(contentType: Headers.formUrlEncodedContentType));
      if (!_vigente(generacion)) return;
      final token = r.data is Map ? (r.data as Map)['access_token'] : null;
      if (token is! String || token.isEmpty) {
        throw ApiException(
            'Respuesta inesperada del servidor al iniciar sesión.');
      }
      _api.token = token;
      final identidad = _api.generacionToken;
      final perfil = await _leerUsuario();
      if (!_vigente(generacion) || identidad != _api.generacionToken) return;
      await _enAlmacen(() async {
        if (_vigente(generacion) && identidad == _api.generacionToken) {
          await _almacen.guardar(token);
        }
      });
      if (!_vigente(generacion) || identidad != _api.generacionToken) return;
      usuario.value = perfil;
    } catch (error) {
      if (_vigente(generacion)) {
        _api.token = null;
        usuario.value = null;
        mensajeError.value =
            _mensaje(error, 'No se pudo iniciar sesión. Inténtalo de nuevo.');
        try {
          await _enAlmacen(() async {
            if (_vigente(generacion)) await _almacen.borrar();
          });
        } catch (limpieza) {
          if (_vigente(generacion)) {
            mensajeError.value +=
                ' ${_mensaje(limpieza, 'No se pudo limpiar el almacenamiento seguro.')}';
          }
        }
      } else {
        // Un /me 401 ya inició el cierre desde el interceptor.
        await cierrePendiente;
      }
    } finally {
      if (_vigente(generacion)) cargando.value = false;
    }
  }

  Future<Usuario> _leerUsuario() async {
    final r = await _api.get('/usuarios/me');
    if (r.data is! Map) {
      throw ApiException(
          'Respuesta inesperada del servidor al leer tu perfil.');
    }
    return Usuario.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<void> cargarUsuario() async {
    final generacion = _generacion;
    final identidad = _api.generacionToken;
    final perfil = await _leerUsuario();
    if (_vigente(generacion) &&
        identidad == _api.generacionToken &&
        _api.token != null) {
      usuario.value = perfil;
    }
  }

  Future<void> restaurarSesion() async {
    if (_cerrado || restaurando.value || cargando.value) return;
    final generacion = ++_generacion;
    restaurando.value = true;
    try {
      final token = await _enAlmacen(_almacen.leer);
      if (!_vigente(generacion) || token == null || token.isEmpty) return;
      _api.token = token;
      final identidad = _api.generacionToken;
      final perfil = await _leerUsuario();
      if (!_vigente(generacion) || identidad != _api.generacionToken) return;
      avisoSesion.value = '';
      usuario.value = perfil;
    } catch (error) {
      if (!_vigente(generacion)) {
        await cierrePendiente;
      } else if (error is ApiException && error.statusCode == 401) {
        await sesionCaducada();
      } else {
        // Sin red o storage inaccesible: no hay usuario validado, pero el
        // token en disco podría ser válido. No se borra para poder reintentar.
        _api.token = null;
        usuario.value = null;
        avisoSesion.value = _mensaje(
            error, 'No se pudo restaurar la sesión. Inténtalo de nuevo.');
      }
    } finally {
      if (_vigente(generacion)) restaurando.value = false;
    }
  }

  Future<void> sesionCaducada() {
    if (_cerrado) return cierrePendiente;
    final cierre =
        cerrarSesion(aviso: 'Tu sesión caducó, inicia sesión de nuevo.');
    if (Get.key.currentState != null) Get.until((ruta) => ruta.isFirst);
    return cierre;
  }

  /// Invalida primero conexión, operaciones y listas; el disco se espera al
  /// final y no puede borrar un token nuevo escrito después del logout.
  Future<void> cerrarSesion({String aviso = ''}) {
    if (_cerrado) return cierrePendiente;
    final generacion = ++_generacion;
    _api.token = null;
    final limpiezas = [for (final limpiar in _limpiezas) limpiar(true)];
    usuario.value = null;
    cargando.value = false;
    restaurando.value = false;
    avisoSesion.value = aviso;
    mensajeError.value = aviso;
    final borrado = _enAlmacen(_almacen.borrar);
    _cierrePendiente = Future.wait<void>([...limpiezas, borrado]).then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        if (_vigente(generacion)) {
          final detalle =
              _mensaje(error, 'No se pudo limpiar la sesión en disco.');
          avisoSesion.value =
              [aviso, detalle].where((p) => p.isNotEmpty).join(' ');
          mensajeError.value = avisoSesion.value;
        }
      },
    );
    return _cierrePendiente!;
  }

  String _mensaje(Object error, String reserva) =>
      error is ApiException ? error.mensaje : reserva;

  void invalidarTokenParaPruebas() => _api.token = 'token-invalido';

  @override
  void onClose() {
    if (_cerrado) return;
    _cerrado = true;
    _generacion++;
    if (identical(_api.alSesionCaducada, _alCaducar)) {
      _api.alSesionCaducada = null;
      _api.token = null;
    }
    final cierres = [for (final limpiar in _limpiezas) limpiar(false)];
    usuario.value = null;
    cargando.value = false;
    restaurando.value = false;
    // Dispose conserva el token seguro y el contenido de Hive.
    _cierrePendiente =
        cierres.isEmpty ? null : Future.wait<void>(cierres).then<void>((_) {});
    super.onClose();
  }
}
