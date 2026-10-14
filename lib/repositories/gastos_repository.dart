import 'dart:async';

import 'package:hive/hive.dart';

import '../models/gasto.dart';
import '../services/api_exception.dart';
import '../services/gastos_api_service.dart';

/// Servidor primero; caché privada por usuario, solo de lectura.
/// El JWT pertenece a AuthController/ApiClient y nunca entra en esta caja.
class GastosRepository {
  GastosRepository(
    this._api, {
    Future<Box<dynamic>> Function(String nombre)? abrirCaja,
  }) : _abrirCaja = abrirCaja ?? ((nombre) => Hive.openBox<dynamic>(nombre));

  final GastosApiService _api;
  final Future<Box<dynamic>> Function(String nombre) _abrirCaja;
  Box<dynamic>? _caja;
  int _generacion = 0;
  int _versionCarga = 0;
  static final _cola = <Future<void> Function()>[];
  static bool _ocupada = false;
  final _aperturasConservadas = <int>{};

  static const _claveGastos = 'gastos';
  static const _claveTotal = 'total';
  static const _claveSincronizado = 'sincronizado';

  /// Reserva la sesión ANTES de /me. La cola ordena apertura, escritura y
  /// borrado; una apertura cancelada nunca cierra la caja de una sesión nueva.
  Future<void> abrirParaUsuario({int? usuarioId}) async {
    final generacion = ++_generacion;
    _versionCarga++;
    final anterior = _caja;
    _caja = null;
    if (anterior != null) {
      await _enDisco(() async {
        await _borrarCajaCapturada(anterior);
      });
    }
    if (generacion != _generacion) return;
    final id = usuarioId ?? await _api.obtenerIdUsuario();
    if (generacion != _generacion) return;
    await _enDisco(() async {
      if (generacion != _generacion) return;
      final nombre = 'gastos_$id';
      final estabaAbierta = Hive.isBoxOpen(nombre);
      final caja = await _abrirCaja(nombre);
      if (generacion != _generacion) {
        // Esta apertura es dueña de la caché privada, aunque ya hubiera datos
        // en disco. Una instancia que ya estaba abierta se conserva.
        if (!estabaAbierta && !identical(caja, _caja)) {
          if (_aperturasConservadas.remove(generacion)) {
            if (caja.isOpen) await caja.close();
          } else {
            await _borrarCajaCapturada(caja);
          }
        }
        return;
      }
      _caja = caja;
    });
  }

  Future<({List<Gasto> gastos, int total, bool desdeCache})> recargar({
    required int limit,
  }) async {
    final caja = _caja;
    final generacion = _generacion;
    final version = ++_versionCarga;
    try {
      final resultado = await _api.listarGastos(skip: 0, limit: limit);
      await _guardarSiVigente(
        caja,
        generacion,
        version,
        0,
        resultado.gastos,
        resultado.total,
      );
      return (
        gastos: resultado.gastos,
        total: resultado.total,
        desdeCache: false,
      );
    } on ApiException catch (error) {
      if (!_fallaDeInfraestructura(error)) rethrow;
      final cache = await _enDisco(() async {
        if (!_vigente(caja, generacion, version)) return null;
        return _leer(caja);
      });
      if (cache == null) rethrow;
      return (gastos: cache.gastos, total: cache.total, desdeCache: true);
    }
  }

  /// No hay fallback al paginar: solo pueden leerse las páginas ya guardadas.
  Future<({List<Gasto> gastos, int total})> siguientePagina({
    required int skip,
    required int limit,
  }) async {
    final caja = _caja;
    final generacion = _generacion;
    final version = ++_versionCarga;
    final resultado = await _api.listarGastos(skip: skip, limit: limit);
    await _guardarSiVigente(
      caja,
      generacion,
      version,
      skip,
      resultado.gastos,
      resultado.total,
    );
    return (gastos: resultado.gastos, total: resultado.total);
  }

  String get ultimaSincronizacion {
    final caja = _caja;
    final iso = caja != null && caja.isOpen
        ? caja.get(_claveSincronizado) as String?
        : null;
    final fecha = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (fecha == null) return 'desconocida';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  /// Desvincula la caja y cancela cargas de inmediato. El borrado esperado usa
  /// la instancia capturada, nunca la caja que otra sesión abra después.
  Future<void> vaciar() {
    _generacion++;
    _versionCarga++;
    final caja = _caja;
    _caja = null;
    return _enDisco(() async {
      if (caja != null) await _borrarCajaCapturada(caja);
    });
  }

  /// Dispose cierra el recurso capturado, conservando su contenido en disco.
  /// Una apertura pendiente también se cierra sin borrar al terminar.
  Future<void> cerrar() {
    _aperturasConservadas.add(_generacion);
    _generacion++;
    _versionCarga++;
    final caja = _caja;
    _caja = null;
    return _enDisco(() async {
      if (caja != null && caja.isOpen) {
        await caja.flush();
        await caja.close();
      }
    });
  }

  /// Guarda el resultado confirmado del CRUD antes de recargar. Si la red
  /// falla después, el fallback no vuelve a una versión anterior del gasto.
  Future<void> confirmar({Gasto? gasto, int? eliminado, required int total}) {
    final caja = _caja;
    final generacion = _generacion;
    final version = ++_versionCarga;
    return _enDisco(() async {
      if (!_vigente(caja, generacion, version)) return;
      final porId = {for (final g in _leer(caja)?.gastos ?? <Gasto>[]) g.id: g};
      if (eliminado != null) porId.remove(eliminado);
      if (gasto != null) porId[gasto.id] = gasto;
      await _guardar(caja!, 0, porId.values.toList(), total);
    });
  }

  /// Se llama dentro de la cola y opera solo sobre la instancia capturada.
  /// Cerrar primero libera IndexedDB antes de pedir el borrado al gestor Hive.
  Future<void> _borrarCajaCapturada(Box<dynamic> caja) async {
    final nombre = caja.name;
    if (caja.isOpen) {
      await caja.clear();
      await caja.flush();
      await caja.close();
    }
    await Hive.deleteBoxFromDisk(nombre);
  }

  Future<T> _enDisco<T>(Future<T> Function() operacion) {
    final resultado = Completer<T>();
    _cola.add(Zone.current.bindCallback(() async {
      try {
        resultado.complete(await operacion());
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

  bool _vigente(Box<dynamic>? caja, int generacion, int version) =>
      generacion == _generacion &&
      version == _versionCarga &&
      identical(caja, _caja) &&
      caja != null &&
      caja.isOpen;

  bool _fallaDeInfraestructura(ApiException error) =>
      error.statusCode == null || error.statusCode! >= 500;

  Future<void> _guardarSiVigente(
    Box<dynamic>? caja,
    int generacion,
    int version,
    int skip,
    List<Gasto> nuevos,
    int total,
  ) =>
      _enDisco(() async {
        // Comprobar DENTRO de la cola, no antes de un await de otra escritura.
        if (!_vigente(caja, generacion, version)) return;
        await _guardar(caja!, skip, nuevos, total);
      });

  Future<void> _guardar(
    Box<dynamic> caja,
    int skip,
    List<Gasto> nuevos,
    int total,
  ) async {
    final previos = skip > 0 ? (_leer(caja)?.gastos ?? <Gasto>[]) : <Gasto>[];
    final porId = {for (final gasto in previos) gasto.id: gasto};
    for (final gasto in nuevos) {
      porId[gasto.id] = gasto;
    }
    // Una sola escritura mantiene juntos lista, total y fecha. Las escrituras
    // posteriores esperan ésta y vuelven a comprobar sesión y versión.
    await caja.putAll({
      _claveGastos: porId.values.map((gasto) => gasto.toMap()).toList(),
      _claveTotal: total,
      _claveSincronizado: DateTime.now().toIso8601String(),
    });
  }

  ({List<Gasto> gastos, int total})? _leer(Box<dynamic>? caja) {
    if (caja == null || !caja.isOpen) return null;
    final guardado = caja.get(_claveGastos);
    if (guardado is! List) return null;
    final gastos = guardado
        .map((mapa) => Gasto.fromMap(mapa as Map))
        .toList(growable: false);
    final total = (caja.get(_claveTotal) as num?)?.toInt() ?? gastos.length;
    return (gastos: gastos, total: total);
  }
}
