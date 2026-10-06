// Flujo académico de la Sesión 6: registro → login → listar con await.
import 'package:get/get.dart';

import '../models/gasto.dart';
import 'places_controller.dart' show EstadoCarga;
import '../services/api_exception.dart';
import '../services/gastos_api_service.dart';

class GastosController extends GetxController {
  GastosController({GastosApiService? api}) : _api = api ?? GastosApiService();

  static const int _tamanoPagina = 20;
  final GastosApiService _api;
  final RxList<Gasto> gastos = <Gasto>[].obs;
  final Rx<EstadoCarga> estado = EstadoCarga.exito.obs;
  final RxString mensajeError = ''.obs;
  final RxInt totalEnServidor = 0.obs;
  final RxBool sesionActiva = false.obs;
  final RxBool autenticando = false.obs;
  final RxString mensajeAuth = ''.obs;
  final RxBool cargandoMas = false.obs;
  int _sesion = 0;
  int _carga = 0;

  bool get hayMas => gastos.length < totalEnServidor.value;
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
      sesionActiva.value = true;
      await cargarGastos();
    } on ApiException catch (error) {
      if (!isClosed && sesion == _sesion) mensajeAuth.value = error.mensaje;
    } catch (_) {
      if (!isClosed && sesion == _sesion) {
        mensajeAuth.value = 'No se pudo iniciar sesión. Inténtalo de nuevo.';
      }
    } finally {
      if (!isClosed && sesion == _sesion) autenticando.value = false;
    }
  }

  Future<void> cargarGastos() async {
    if (isClosed) return;
    final sesion = _sesion;
    final carga = ++_carga;
    cargandoMas.value = false;
    estado.value = EstadoCarga.cargando;
    mensajeError.value = '';
    try {
      final resultado = await _api.listarGastos(skip: 0, limit: _tamanoPagina);
      if (!_vigente(sesion, carga)) return;
      gastos.assignAll(resultado.gastos);
      totalEnServidor.value = resultado.total;
      estado.value = EstadoCarga.exito;
    } on ApiException catch (error) {
      if (!_vigente(sesion, carga)) return;
      _errorSesion(error);
      // Los datos previos se conservan cuando falla la red.
      mensajeError.value = error.mensaje;
      estado.value = EstadoCarga.error;
    } catch (_) {
      if (!_vigente(sesion, carga)) return;
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
      final resultado = await _api.listarGastos(
        skip: gastos.length,
        limit: _tamanoPagina,
      );
      if (!_vigente(sesion, carga)) return;
      gastos.addAll(resultado.gastos);
      totalEnServidor.value = resultado.total;
    } on ApiException catch (error) {
      if (!_vigente(sesion, carga)) return;
      _errorSesion(error);
      if (error.statusCode != 401) {
        Get.snackbar('No se pudo cargar más', error.mensaje);
      }
    } catch (_) {
      if (_vigente(sesion, carga)) {
        Get.snackbar('No se pudo cargar más', 'Inténtalo de nuevo.');
      }
    } finally {
      if (_vigente(sesion, carga)) cargandoMas.value = false;
    }
  }

  void _errorSesion(ApiException error) {
    if (error.statusCode == 401) {
      _api.cerrarSesion();
      sesionActiva.value = false;
      mensajeAuth.value = error.mensaje;
    }
  }

  void salir() {
    _sesion++;
    _carga++;
    _api.cerrarSesion();
    gastos.clear();
    totalEnServidor.value = 0;
    estado.value = EstadoCarga.exito;
    sesionActiva.value = false;
    autenticando.value = false;
    cargandoMas.value = false;
    mensajeAuth.value = '';
    mensajeError.value = '';
  }

  void invalidarTokenParaPruebas() => _api.invalidarTokenParaPruebas();

  void configurarTimeoutParaPruebas(Duration plazo) =>
      _api.configurarTimeoutParaPruebas(plazo);

  @override
  void onClose() {
    _sesion++;
    _carga++;
    _api.dispose();
    super.onClose();
  }
}
