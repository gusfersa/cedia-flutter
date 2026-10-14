// Basado en Patricio-CEDIA/exploraec-app, Sesión 8.
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import 'api_exception.dart';

export 'package:dio/dio.dart' show Headers, Options;
export 'api_exception.dart';

/// Una sola conexión Dio. Cada petición conserva la identidad de la sesión
/// que la inició: un 401 tardío nunca invalida el token de otra sesión.
class ApiClient {
  ApiClient({Dio? dio, String? baseUrl, Duration? plazo})
      : dio = dio ?? Dio(),
        _plazo = plazo ?? const Duration(milliseconds: ApiConfig.timeoutMs) {
    if (baseUrl != null || this.dio.options.baseUrl.isEmpty) {
      this.dio.options.baseUrl =
          (baseUrl ?? ApiConfig.baseUrl).replaceFirst(RegExp(r'/+$'), '');
    }
    configurarTimeout(_plazo);
    this.dio.interceptors.add(InterceptorsWrapper(
          onRequest: (opciones, siguiente) {
            opciones.extra.putIfAbsent(_claveGeneracion, () => _generacion);
            opciones.extra.putIfAbsent(_claveToken, () => _token);
            final generacion = opciones.extra[_claveGeneracion];
            final solicitante = opciones.extra[_claveToken];
            if (_cerrado || generacion != _generacion) {
              siguiente.reject(DioException(
                requestOptions: opciones,
                type: DioExceptionType.cancel,
                error: 'La sesión cambió antes de enviar la petición.',
              ));
              return;
            }
            if (solicitante is String) {
              opciones.headers['Authorization'] = 'Bearer $solicitante';
            }
            siguiente.next(opciones);
          },
          onError: (error, siguiente) {
            final solicitud = error.requestOptions;
            if (error.response?.statusCode == 401 &&
                Uri.parse(solicitud.path).path != '/usuarios/token' &&
                solicitud.extra[_claveToken] != null &&
                solicitud.extra[_claveToken] == _token &&
                solicitud.extra[_claveGeneracion] == _generacion &&
                !_cerrado) {
              // El callback invalida memoria sin esperar el almacenamiento.
              alSesionCaducada?.call();
            }
            siguiente.next(error);
          },
        ));
  }

  static const _claveToken = 'exploraec.tokenSolicitante';
  static const _claveGeneracion = 'exploraec.generacionSolicitante';
  final Dio dio;
  String? _token;
  int _generacion = 0;
  bool _cerrado = false;
  Duration _plazo;
  void Function()? alSesionCaducada;

  String? get token => _token;
  set token(String? valor) {
    _generacion++;
    _token = valor;
  }

  int get generacionToken => _generacion;
  Duration get plazo => _plazo;

  void configurarTimeout(Duration valor) {
    if (valor <= Duration.zero) {
      throw ArgumentError.value(valor, 'plazo', 'El plazo debe ser positivo.');
    }
    _plazo = valor;
    dio.options.connectTimeout = valor;
    dio.options.receiveTimeout = valor;
    dio.options.sendTimeout = valor;
  }

  Options _opciones([Options? opciones]) => (opciones ?? Options()).copyWith(
        extra: {
          ...?opciones?.extra,
          _claveToken: _token,
          _claveGeneracion: _generacion,
        },
      );

  Future<Response<dynamic>> get(String ruta, {Map<String, dynamic>? query}) =>
      _enviar(
          () => dio.get(ruta, queryParameters: query, options: _opciones()));

  Future<Response<dynamic>> post(String ruta,
          {Object? data, Options? options}) =>
      _enviar(() => dio.post(ruta, data: data, options: _opciones(options)));

  Future<Response<dynamic>> put(String ruta, {Object? data}) =>
      _enviar(() => dio.put(ruta, data: data, options: _opciones()));

  Future<Response<dynamic>> patch(String ruta, {Object? data}) =>
      _enviar(() => dio.patch(ruta, data: data, options: _opciones()));

  Future<Response<dynamic>> delete(String ruta) =>
      _enviar(() => dio.delete(ruta, options: _opciones()));

  Future<Response<dynamic>> _enviar(
      Future<Response<dynamic>> Function() peticion) async {
    try {
      final respuesta = await peticion().timeout(_plazo);
      // También valida servidores que omiten Content-Type.
      if (respuesta.data is String &&
          (respuesta.data as String).isNotEmpty &&
          respuesta.statusCode != 204) {
        respuesta.data = jsonDecode(respuesta.data as String);
      }
      return respuesta;
    } on DioException catch (error) {
      throw ApiException.desde(error);
    } on TimeoutException {
      throw ApiException(
          'El servidor tardó demasiado en responder. Revisa tu conexión e inténtalo de nuevo.');
    } on FormatException {
      throw ApiException('El servidor envió una respuesta JSON inválida.');
    }
  }

  /// Solo libera conexión y memoria; el token persistente pertenece a Auth.
  void dispose() {
    _cerrado = true;
    token = null;
    alSesionCaducada = null;
    dio.close();
  }
}
