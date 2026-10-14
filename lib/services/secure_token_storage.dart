import 'dart:async';

// Basado en Patricio-CEDIA/exploraec-app, Sesión 8.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_exception.dart';

/// JWT en Keychain/Keystore; nunca en Hive. La cola compartida ordena las
/// lecturas, escrituras y borrados incluso al recrear los controllers.
class SecureTokenStorage {
  SecureTokenStorage([FlutterSecureStorage? almacen])
      : _almacen = almacen ?? const FlutterSecureStorage();

  static const _clave = 'access_token';
  static final _cola = <Future<void> Function()>[];
  static bool _ocupada = false;
  final FlutterSecureStorage _almacen;

  Future<String?> leer() =>
      _ordenar(() => _almacen.read(key: _clave), 'leer el token del');

  Future<void> guardar(String token) => _ordenar(
      () => _almacen.write(key: _clave, value: token),
      'guardar el token en el');

  Future<void> borrar() =>
      _ordenar(() => _almacen.delete(key: _clave), 'borrar el token del');

  Future<T> _ordenar<T>(Future<T> Function() accion, String verbo) {
    final resultado = Completer<T>();
    _cola.add(Zone.current.bindCallback(() async {
      try {
        resultado.complete(await accion());
      } catch (_) {
        resultado.completeError(ApiException(
            'No se pudo $verbo almacenamiento seguro. Inténtalo de nuevo.'));
      }
    }));
    _procesarCola();
    return resultado.future;
  }

  static Future<void> _procesarCola() async {
    if (_ocupada) return;
    _ocupada = true;
    while (_cola.isNotEmpty) {
      await _cola.removeAt(0)();
    }
    _ocupada = false;
  }
}
