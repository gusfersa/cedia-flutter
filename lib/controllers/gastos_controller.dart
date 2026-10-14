// Basado en Patricio-CEDIA/exploraec-app, sesiones 6–8.
// Conserva paginación 20, generaciones de carga y cola capturada Hive de S7.
import 'package:get/get.dart';

import '../models/gasto.dart';
import '../repositories/gastos_repository.dart';
import '../services/api_client.dart';
import '../services/gastos_api_service.dart';
import 'auth_controller.dart';
import 'places_controller.dart' show EstadoCarga;

export '../repositories/gastos_repository.dart';

class GastosController extends GetxController {
  GastosController(
      {GastosApiService? api,
      AuthController? auth,
      GastosRepository? repository}) {
    _api = api ??
        GastosApiService(
            api: auth?.api ??
                (Get.isRegistered<ApiClient>()
                    ? Get.find<ApiClient>()
                    : ApiClient()));
    _authPropio = auth == null && !Get.isRegistered<AuthController>();
    _auth = auth ??
        (Get.isRegistered<AuthController>()
            ? Get.find<AuthController>()
            : AuthController(api: _api.client));
    _repository = repository ?? GastosRepository(_api);
    _limpieza = (borrar) => limpiar(borrarCache: borrar);
    _auth.agregarLimpieza(_limpieza);
    _escuchaAuth = ever(_auth.usuario, (usuario) {
      if (usuario != null && !_cerrado) _inicioPendiente = iniciar();
    });
  }

  static const _tamanoPagina = 20;
  late final GastosApiService _api;
  late final AuthController _auth;
  late final bool _authPropio;
  late final GastosRepository _repository;
  late final LimpiezaSesion _limpieza;
  late final Worker _escuchaAuth;
  final RxList<Gasto> gastos = <Gasto>[].obs;
  final RxList<String> categorias = <String>[].obs;
  final Rx<EstadoCarga> estado = EstadoCarga.exito.obs;
  final RxString mensajeError = ''.obs;
  final RxString avisoSincronizacion = ''.obs;
  final RxInt totalEnServidor = 0.obs;
  final RxBool sesionActiva = false.obs;
  final RxBool cargandoMas = false.obs;
  final RxBool desdeCache = false.obs;
  RxBool get autenticando => _auth.cargando;
  RxString get mensajeAuth => _auth.mensajeError;
  AuthController get auth => _auth;
  String get ultimaSincronizacion => _repository.ultimaSincronizacion;
  String get servidor => _api.baseUrl;
  bool get hayMas => !desdeCache.value && gastos.length < totalEnServidor.value;

  int _sesion = 0;
  int _carga = 0;
  int? _usuarioCaja;
  bool _cerrado = false;
  Future<void>? _cierrePendiente;
  Future<void>? _inicioPendiente;
  Future<void> get cierrePendiente => Future.wait<void>([
        if (_cierrePendiente != null) _cierrePendiente!,
        _auth.cierrePendiente
      ]).then<void>((_) {});
  Future<void> get inicioPendiente => _inicioPendiente ?? Future<void>.value();
  bool _sesionVigente(int sesion) =>
      !_cerrado && sesion == _sesion && _auth.estaAutenticado;
  bool _vigente(int sesion, int carga) =>
      _sesionVigente(sesion) && carga == _carga;

  @override
  void onInit() {
    super.onInit();
    if (_auth.estaAutenticado) _inicioPendiente = iniciar();
  }

  /// Fachada S6/S7: delega la autenticación real, no guarda una sesión paralela.
  Future<void> entrar(String email, String password) async {
    if (_cerrado || autenticando.value) return;
    await _auth.registrar(email, password, continuarSiExiste: true);
    if (_auth.estaAutenticado && !_cerrado) await inicioPendiente;
  }

  Future<void> iniciar() async {
    if (_cerrado || !_auth.estaAutenticado) return;
    final sesion = ++_sesion;
    _carga++;
    final id = _auth.usuario.value!.id;
    sesionActiva.value = true;
    estado.value = EstadoCarga.cargando;
    mensajeError.value = '';
    try {
      if (_usuarioCaja != id) {
        await _repository.abrirParaUsuario(usuarioId: id);
        if (!_sesionVigente(sesion)) return;
        _usuarioCaja = id;
      }
      await cargarCategorias();
      if (!_sesionVigente(sesion)) return;
      await cargarGastos();
    } on ApiException catch (error) {
      if (!_sesionVigente(sesion)) {
        await cierrePendiente;
        return;
      }
      if (error.statusCode == 401) {
        await _auth.sesionCaducada();
      } else {
        mensajeError.value = error.mensaje;
        estado.value = EstadoCarga.error;
      }
    } catch (_) {
      if (_sesionVigente(sesion)) {
        mensajeError.value =
            'No se pudieron preparar tus gastos. Inténtalo de nuevo.';
        estado.value = EstadoCarga.error;
      }
    }
  }

  Future<void> cargarCategorias() async {
    if (_cerrado || !_auth.estaAutenticado) return;
    final sesion = _sesion;
    final resultado = await _api.listarCategorias();
    if (_sesionVigente(sesion)) {
      categorias.assignAll(resultado.categorias.toSet());
    }
  }

  Future<void> cargarGastos() async {
    if (_cerrado || !sesionActiva.value || !_auth.estaAutenticado) return;
    final sesion = _sesion;
    final carga = ++_carga;
    cargandoMas.value = false;
    estado.value = EstadoCarga.cargando;
    mensajeError.value = '';
    try {
      final resultado = await _repository.recargar(limit: _tamanoPagina);
      if (!_vigente(sesion, carga)) return;
      gastos.assignAll({for (final g in resultado.gastos) g.id: g}.values);
      totalEnServidor.value = resultado.total;
      desdeCache.value = resultado.desdeCache;
      if (!resultado.desdeCache) avisoSincronizacion.value = '';
      estado.value = EstadoCarga.exito;
    } on ApiException catch (error) {
      if (!_vigente(sesion, carga)) {
        await cierrePendiente;
        return;
      }
      if (error.statusCode == 401) {
        await _auth.sesionCaducada();
        return;
      }
      desdeCache.value = false;
      mensajeError.value = error.mensaje;
      estado.value = EstadoCarga.error;
    } catch (_) {
      if (!_vigente(sesion, carga)) return;
      desdeCache.value = false;
      mensajeError.value =
          'No se pudieron cargar los gastos. Inténtalo de nuevo.';
      estado.value = EstadoCarga.error;
    }
  }

  Future<void> cargarMas() async {
    if (_cerrado ||
        !_auth.estaAutenticado ||
        !sesionActiva.value ||
        !hayMas ||
        cargandoMas.value ||
        estado.value == EstadoCarga.cargando) {
      return;
    }
    final sesion = _sesion;
    final carga = ++_carga;
    cargandoMas.value = true;
    try {
      final resultado = await _repository.siguientePagina(
          skip: gastos.length, limit: _tamanoPagina);
      if (!_vigente(sesion, carga)) return;
      final porId = {for (final g in gastos) g.id: g};
      for (final g in resultado.gastos) {
        porId[g.id] = g;
      }
      gastos.assignAll(porId.values);
      totalEnServidor.value = resultado.total;
    } on ApiException catch (error) {
      if (!_vigente(sesion, carga)) {
        await cierrePendiente;
        return;
      }
      if (error.statusCode == 401) {
        await _auth.sesionCaducada();
      } else {
        mensajeError.value = error.mensaje;
        if (Get.key.currentState != null) {
          Get.snackbar('No se pudo cargar más', error.mensaje);
        }
      }
    } catch (_) {
      if (_vigente(sesion, carga)) {
        mensajeError.value = 'No se pudo cargar más. Inténtalo de nuevo.';
      }
    } finally {
      if (_vigente(sesion, carga)) cargandoMas.value = false;
    }
  }

  int _exigirSesion() {
    if (_cerrado || !_auth.estaAutenticado || !sesionActiva.value) {
      throw ApiException('Inicia sesión para modificar tus gastos.',
          statusCode: 401);
    }
    return _sesion;
  }

  Future<void> crear(String descripcion, double monto, String categoria) async {
    final sesion = _exigirSesion();
    final g = await _api.crear(
        {'descripcion': descripcion, 'monto': monto, 'categoria': categoria});
    if (!_sesionVigente(sesion)) return;
    await _confirmar(sesion, gasto: g);
  }

  Future<void> actualizar(int id, Map<String, dynamic> cambios) async {
    final sesion = _exigirSesion();
    if (cambios.isEmpty) return;
    try {
      final g = await _api.actualizar(id, cambios);
      if (!_sesionVigente(sesion)) return;
      await _confirmar(sesion, gasto: g);
    } on ApiException catch (error) {
      if (error.statusCode == 404 && _sesionVigente(sesion)) {
        await _confirmar(sesion, eliminado: id);
      }
      rethrow;
    }
  }

  Future<void> eliminar(int id) async {
    final sesion = _exigirSesion();
    try {
      await _api.eliminar(id);
      if (!_sesionVigente(sesion)) return;
      await _confirmar(sesion, eliminado: id);
    } on ApiException catch (error) {
      if (error.statusCode == 404 && _sesionVigente(sesion)) {
        await _confirmar(sesion, eliminado: id);
      }
      rethrow;
    }
  }

  Future<void> _confirmar(int sesion, {Gasto? gasto, int? eliminado}) async {
    if (!_sesionVigente(sesion)) return;
    _carga++; // Una lista iniciada antes del CRUD no puede pisar su resultado.
    cargandoMas.value = false;
    final porId = {for (final g in gastos) g.id: g};
    if (eliminado != null && porId.remove(eliminado) != null) {
      totalEnServidor.value--;
    }
    if (gasto != null) {
      if (!porId.containsKey(gasto.id)) totalEnServidor.value++;
      porId[gasto.id] = gasto;
    }
    gastos.assignAll(porId.values);
    desdeCache.value = false;
    estado.value = EstadoCarga.exito;
    mensajeError.value = '';
    avisoSincronizacion.value = '';
    try {
      await _repository.confirmar(
          gasto: gasto, eliminado: eliminado, total: totalEnServidor.value);
    } catch (_) {
      if (_sesionVigente(sesion)) {
        avisoSincronizacion.value =
            'El cambio se guardó en el servidor, pero no se pudo actualizar la copia local.';
      }
    }
    if (!_sesionVigente(sesion)) return;
    final carga = ++_carga;
    try {
      final resultado = await _repository.recargar(limit: _tamanoPagina);
      if (!_vigente(sesion, carga)) return;
      if (resultado.desdeCache) {
        desdeCache.value = true;
        avisoSincronizacion.value =
            'El cambio se guardó en el servidor. No se pudo sincronizar la lista; puedes reintentar.';
      } else {
        gastos.assignAll({for (final g in resultado.gastos) g.id: g}.values);
        totalEnServidor.value = resultado.total;
      }
    } catch (error) {
      if (!_vigente(sesion, carga)) {
        await cierrePendiente;
        return;
      }
      if (error is ApiException && error.statusCode == 401) {
        await _auth.sesionCaducada();
      } else {
        // POST/PATCH/DELETE ya se confirmó: no se informa «falló guardar».
        avisoSincronizacion.value =
            'El cambio se guardó en el servidor. No se pudo sincronizar la lista; puedes reintentar.';
      }
    }
  }

  Future<void> limpiar({bool borrarCache = true}) {
    _sesion++;
    _carga++;
    _usuarioCaja = null;
    final cierre = borrarCache ? _repository.vaciar() : _repository.cerrar();
    _cierrePendiente = cierre;
    gastos.clear();
    categorias.clear();
    totalEnServidor.value = 0;
    desdeCache.value = false;
    cargandoMas.value = false;
    mensajeError.value = '';
    avisoSincronizacion.value = '';
    estado.value = EstadoCarga.exito;
    sesionActiva.value = false;
    return cierre;
  }

  Future<void> salir() => _auth.cerrarSesion();
  void invalidarTokenParaPruebas() => _auth.invalidarTokenParaPruebas();
  void configurarTimeoutParaPruebas(Duration plazo) =>
      _api.configurarTimeoutParaPruebas(plazo);

  @override
  void onClose() {
    if (_cerrado) return;
    _cerrado = true;
    _escuchaAuth.dispose();
    _auth.quitarLimpieza(_limpieza);
    limpiar(borrarCache: false);
    if (_authPropio) {
      _auth.onClose();
      _api.dispose();
    }
    super.onClose();
  }
}
