// Flujo académico de la Sesión 6: registro → login → listar con await.
// Sesión 7: la lista pasa por GastosRepository (servidor primero, caché de
// Hive por usuario), conservando paginación y las protecciones de concurrencia.
import 'package:get/get.dart';

import '../models/gasto.dart';
import '../repositories/gastos_repository.dart';
import 'places_controller.dart' show EstadoCarga;
import '../services/api_exception.dart';
import '../services/gastos_api_service.dart';

export '../repositories/gastos_repository.dart';

class GastosController extends GetxController {
  GastosController({GastosApiService? api}) : _api = api ?? GastosApiService();

  static const int _tamanoPagina = 20;
  final GastosApiService _api;
  late final GastosRepository _repository = GastosRepository(_api);
  final RxList<Gasto> gastos = <Gasto>[].obs;
  final Rx<EstadoCarga> estado = EstadoCarga.exito.obs;
  final RxString mensajeError = ''.obs;
  final RxInt totalEnServidor = 0.obs;
  final RxBool sesionActiva = false.obs;
  final RxBool autenticando = false.obs;
  final RxString mensajeAuth = ''.obs;
  final RxBool cargandoMas = false.obs;

  /// `true` solo cuando la última carga exitosa vino de la caché local (el
  /// servidor no respondió): la UI lo usa para avisar «datos guardados».
  final RxBool desdeCache = false.obs;

  String get ultimaSincronizacion => _repository.ultimaSincronizacion;

  int _sesion = 0;
  int _carga = 0;
  Future<void> _cierrePendiente = Future<void>.value();

  /// Permite esperar la limpieza async iniciada por un callback o por onClose.
  Future<void> get cierrePendiente => _cierrePendiente;

  bool get hayMas => !desdeCache.value && gastos.length < totalEnServidor.value;
  String get servidor => _api.baseUrl;
  bool _vigente(int sesion, int carga) =>
      !isClosed && sesion == _sesion && carga == _carga;

  Future<void> entrar(String email, String password) async {
    if (isClosed || autenticando.value) return;
    final sesion = ++_sesion;
    autenticando.value = true;
    mensajeAuth.value = '';
    try {
      // Un 400 de registro indica correo existente: continuar al login.
      try {
        await _api.registrar(email, password);
      } on ApiException catch (error) {
        if (error.statusCode != 400) rethrow;
      }
      if (isClosed || sesion != _sesion) return;
      await _api.login(email, password);
      if (isClosed || sesion != _sesion) return;
      // Sesión 7: abre (o crea) la caja `gastos_<id>` de este usuario.
      await _repository.abrirParaUsuario();
      if (isClosed || sesion != _sesion) return;
      sesionActiva.value = true;
      await cargarGastos();
    } on ApiException catch (error) {
      if (!isClosed && sesion == _sesion) {
        await _cerrarSesion(mensaje: error.mensaje);
      }
    } catch (_) {
      if (!isClosed && sesion == _sesion) {
        await _cerrarSesion(
          mensaje: 'No se pudo iniciar sesión. Inténtalo de nuevo.',
        );
      }
    } finally {
      if (!isClosed && sesion == _sesion) autenticando.value = false;
    }
  }

  Future<void> cargarGastos() async {
    if (isClosed || !sesionActiva.value) return;
    final sesion = _sesion;
    final carga = ++_carga;
    cargandoMas.value = false;
    estado.value = EstadoCarga.cargando;
    mensajeError.value = '';
    try {
      final resultado = await _repository.recargar(limit: _tamanoPagina);
      if (!_vigente(sesion, carga)) return;
      gastos.assignAll(
          {for (final gasto in resultado.gastos) gasto.id: gasto}.values);
      totalEnServidor.value = resultado.total;
      desdeCache.value = resultado.desdeCache;
      estado.value = EstadoCarga.exito;
    } on ApiException catch (error) {
      if (!_vigente(sesion, carga)) return;
      if (error.statusCode == 401) {
        await _errorSesion(error);
        return;
      }
      // Los datos previos se conservan cuando falla la red.
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
    if (isClosed ||
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
        skip: gastos.length,
        limit: _tamanoPagina,
      );
      if (!_vigente(sesion, carga)) return;
      final porId = {for (final gasto in gastos) gasto.id: gasto};
      for (final gasto in resultado.gastos) {
        porId[gasto.id] = gasto;
      }
      gastos.assignAll(porId.values);
      totalEnServidor.value = resultado.total;
    } on ApiException catch (error) {
      if (!_vigente(sesion, carga)) return;
      if (error.statusCode == 401) {
        await _errorSesion(error);
        return;
      }
      Get.snackbar('No se pudo cargar más', error.mensaje);
    } catch (_) {
      if (_vigente(sesion, carga)) {
        Get.snackbar('No se pudo cargar más', 'Inténtalo de nuevo.');
      }
    } finally {
      if (_vigente(sesion, carga)) cargandoMas.value = false;
    }
  }

  Future<void> _errorSesion(ApiException error) async {
    if (error.statusCode == 401) {
      await _cerrarSesion(mensaje: error.mensaje);
    }
  }

  Future<void> salir() => _cerrarSesion();

  Future<void> _cerrarSesion({String mensaje = ''}) {
    _sesion++;
    _carga++;
    _api.cerrarSesion();
    // Invalida el repositorio antes de emitir cambios reactivos: ninguna
    // respuesta pendiente puede leer/escribir la caja de esta sesión.
    final borrado = _repository.vaciar();
    _cierrePendiente = borrado;
    // Limpia la vista de inmediato; el borrado de la caja se espera después.
    gastos.clear();
    totalEnServidor.value = 0;
    desdeCache.value = false;
    estado.value = EstadoCarga.exito;
    sesionActiva.value = false;
    autenticando.value = false;
    cargandoMas.value = false;
    mensajeAuth.value = mensaje;
    mensajeError.value = '';
    // Sesión 7: cierra y borra la caja de Hive de este usuario, para que otra
    // persona que use el mismo teléfono no vea estos gastos.
    return borrado;
  }

  void invalidarTokenParaPruebas() => _api.invalidarTokenParaPruebas();

  void configurarTimeoutParaPruebas(Duration plazo) =>
      _api.configurarTimeoutParaPruebas(plazo);

  @override
  void onClose() {
    _cerrarSesion();
    _api.dispose();
    super.onClose();
  }
}
