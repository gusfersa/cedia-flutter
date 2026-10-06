// Estado compartido de la práctica CEDIA MOD3.
// Referencia: Patricio-CEDIA/exploraec-app, ramas sesion-04 y sesion-05.
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../models/place.dart';
import '../services/location_service.dart';

enum EstadoCarga { cargando, exito, error }

class PlacesController extends GetxController {
  PlacesController({Future<Position> Function()? obtenerPosicion})
      : _obtenerPosicion =
            obtenerPosicion ?? LocationService.obtenerPosicionActual;

  final Future<Position> Function() _obtenerPosicion;
  final RxList<Place> lugares = <Place>[].obs;
  final Rx<EstadoCarga> estado = EstadoCarga.cargando.obs;
  final RxString mensajeError = ''.obs;
  final Rx<Position?> posicion = Rx<Position?>(null);
  final Rx<EstadoCarga> estadoPosicion = EstadoCarga.cargando.obs;
  final RxString mensajeErrorPosicion = ''.obs;
  final scrollController = ScrollController();

  bool _modoDebugError = false;
  bool _modoDebugVacio = false;
  int _cargaActual = 0;
  int _cargaPosicionActual = 0;
  Worker? _avisoEstado;

  @override
  void onInit() {
    super.onInit();
    _avisoEstado = ever(estado, (EstadoCarga valor) {
      if (valor == EstadoCarga.error) {
        Get.snackbar('Error', mensajeError.value);
      }
    });
    cargarLugares();
  }

  void simular(String modo) {
    _modoDebugError = modo == 'error';
    _modoDebugVacio = modo == 'vacio';
    cargarLugares();
  }

  Future<void> cargarLugares() async {
    final carga = ++_cargaActual;
    estado.value = EstadoCarga.cargando;
    mensajeError.value = '';
    try {
      final resultado = await fetchLugaresSimulado(
        forzarError: _modoDebugError,
        forzarVacio: _modoDebugVacio,
      );
      // Una respuesta anterior no debe reemplazar una simulación más reciente.
      if (isClosed || carga != _cargaActual) return;
      lugares.assignAll(resultado);
      estado.value = EstadoCarga.exito;
    } catch (error) {
      if (isClosed || carga != _cargaActual) return;
      mensajeError.value = '$error';
      estado.value = EstadoCarga.error;
    }
  }

  void agregarLugar(Place lugar) {
    // El alta es el estado vigente: una carga anterior no debe sobrescribirla.
    _cargaActual++;
    // Las listas contienen copias: añadir aquí no duplica la misma referencia.
    lugaresEjemplo.add(lugar);
    lugares.add(lugar);
    estado.value = EstadoCarga.exito;
    mensajeError.value = '';
    // Conservar la mejora de la Sesión 2: mostrar el nuevo lugar al guardarlo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed || !scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /// Estado derivado: se calcula desde la lista reactiva, sin otro contador.
  int get total => lugares.length;

  Future<void> cargarPosicion({bool forzar = false}) async {
    if (posicion.value != null && !forzar) {
      estadoPosicion.value = EstadoCarga.exito;
      return;
    }
    final carga = ++_cargaPosicionActual;
    estadoPosicion.value = EstadoCarga.cargando;
    mensajeErrorPosicion.value = '';
    try {
      final resultado = await _obtenerPosicion();
      if (isClosed || carga != _cargaPosicionActual) return;
      posicion.value = resultado;
      estadoPosicion.value = EstadoCarga.exito;
    } on LocationException catch (error) {
      if (isClosed || carga != _cargaPosicionActual) return;
      mensajeErrorPosicion.value = error.mensaje;
      estadoPosicion.value = EstadoCarga.error;
    } catch (error) {
      if (isClosed || carga != _cargaPosicionActual) return;
      mensajeErrorPosicion.value = '$error';
      estadoPosicion.value = EstadoCarga.error;
    }
  }

  double? distanciaA(Place lugar) {
    final origen = posicion.value;
    return origen == null ? null : distanciaAPlaceEnMetros(origen, lugar);
  }

  @override
  void onClose() {
    _avisoEstado?.dispose();
    scrollController.dispose();
    super.onClose();
  }
}
