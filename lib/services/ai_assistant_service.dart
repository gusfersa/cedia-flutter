// Adaptado de Patricio-CEDIA/exploraec-app, sesión 09 (pasos 4-8).
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../models/resumen_gastos.dart';
import 'api_client.dart';

const String kAiBackendUrl = String.fromEnvironment(
  'LLM_BACKEND_URL',
  defaultValue: 'http://10.0.2.2:3801',
);

class AccionPropuesta {
  final String tipo;
  final String descripcion;
  final double monto;
  final String categoria;

  const AccionPropuesta({
    required this.tipo,
    required this.descripcion,
    required this.monto,
    required this.categoria,
  });

  static AccionPropuesta? desdeJson(Object? json) {
    if (json is! Map) return null;
    final descripcion = json['descripcion'];
    final monto = json['monto'];
    final categoria = json['categoria'];
    if (json['tipo'] != 'registrar_gasto' ||
        descripcion is! String ||
        descripcion.trim().isEmpty ||
        descripcion.length > 200 ||
        monto is! num ||
        !monto.isFinite ||
        monto <= 0 ||
        monto > montoMaximoAsistente ||
        !categoriasAsistente.contains(categoria)) {
      return null;
    }
    return AccionPropuesta(
      tipo: 'registrar_gasto',
      descripcion: descripcion.trim(),
      monto: monto.toDouble(),
      categoria: categoria as String,
    );
  }
}

class RespuestaIA {
  final String respuesta;
  final AccionPropuesta? accion;
  const RespuestaIA({required this.respuesta, this.accion});

  factory RespuestaIA.fromJson(Map<String, dynamic> json) {
    final texto = json['respuesta'];
    if (texto is! String ||
        texto.trim().isEmpty ||
        texto.length > 2000 ||
        (json['modo'] != null && json['modo'] != 'REGLAS')) {
      throw AsistenteException(
          'La respuesta del asistente no tiene el formato esperado.');
    }
    final accion = AccionPropuesta.desdeJson(json['accion']);
    if (json['accion'] != null && accion == null) {
      throw AsistenteException(
          'El asistente propuso una acción inválida. No se registró ningún gasto.');
    }
    return RespuestaIA(respuesta: texto.trim(), accion: accion);
  }
}

class AsistenteException implements Exception {
  final String mensaje;
  final int? statusCode;
  AsistenteException(this.mensaje, {this.statusCode});
  @override
  String toString() => mensaje;
}

const _mensajeSesion =
    'Tu sesión cambió o caducó. Inicia sesión y vuelve a preguntar.';
final _claveZona = Object();
const _clavePeticion = 'exploraec.sesion09';

class _SesionAsistente {
  _SesionAsistente(this.token, this.vigente);
  final String token;
  final bool Function() vigente;
}

/// Token original también en resumen/crear/recargar: una operación S9 vive
/// dentro de una zona. Los interceptores rechazan peticiones y respuestas de
/// esa zona si hubo logout/relogin, sin afectar peticiones ajenas a ella.
class AiAssistantService {
  AiAssistantService({ApiClient? api, Dio? dio})
      : _api = api ?? Get.find<ApiClient>(),
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: kAiBackendUrl,
              connectTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
            )) {
    // Antes del interceptor S8 de 401: un 401 viejo nunca cierra la sesión nueva.
    _api.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (opciones, siguiente) {
            final sesion = Zone.current[_claveZona];
            if (sesion is _SesionAsistente) {
              opciones.extra[_clavePeticion] = sesion;
            }
            siguiente.next(opciones);
          },
          onResponse: (respuesta, siguiente) {
            final sesion = respuesta.requestOptions.extra[_clavePeticion];
            if (sesion is _SesionAsistente && !_vigente(sesion)) {
              siguiente.reject(_cancelada(respuesta.requestOptions));
            } else {
              siguiente.next(respuesta);
            }
          },
          onError: (error, siguiente) {
            final sesion = error.requestOptions.extra[_clavePeticion];
            if (sesion is _SesionAsistente && !_vigente(sesion)) {
              siguiente.reject(_cancelada(error.requestOptions));
            } else {
              siguiente.next(error);
            }
          },
        ));
    // Después de S8: no dejar que un token nuevo reemplace al capturado.
    _api.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (opciones, siguiente) {
        final sesion = opciones.extra[_clavePeticion];
        if (sesion is _SesionAsistente) {
          if (!_vigente(sesion)) {
            siguiente.reject(_cancelada(opciones));
            return;
          }
          opciones.headers['Authorization'] = 'Bearer ${sesion.token}';
        }
        siguiente.next(opciones);
      },
    ));
  }

  final ApiClient _api;
  final Dio _dio;

  bool _vigente(_SesionAsistente sesion) =>
      _api.token == sesion.token && sesion.vigente();

  DioException _cancelada(RequestOptions opciones) => DioException(
        requestOptions: opciones,
        type: DioExceptionType.cancel,
        error: AsistenteException(_mensajeSesion, statusCode: 401),
      );

  Future<T> protegerSesion<T>(String tokenOriginal, bool Function() vigente,
      Future<T> Function() operacion) async {
    final sesion = _SesionAsistente(tokenOriginal, vigente);
    if (!_vigente(sesion)) {
      throw AsistenteException(_mensajeSesion, statusCode: 401);
    }
    final resultado =
        await runZoned(operacion, zoneValues: {_claveZona: sesion});
    if (!_vigente(sesion)) {
      throw AsistenteException(_mensajeSesion, statusCode: 401);
    }
    return resultado;
  }

  Future<RespuestaIA> preguntar(String consulta, ResumenGastos resumen) async {
    final token = _api.token;
    if (token == null || token.trim().isEmpty) {
      throw AsistenteException(_mensajeSesion, statusCode: 401);
    }
    final sesion = Zone.current[_claveZona] as _SesionAsistente?;
    bool vigente() =>
        _api.token == token && (sesion == null || _vigente(sesion));
    if (!vigente()) throw AsistenteException(_mensajeSesion, statusCode: 401);
    if (consulta.trim().isEmpty || consulta.length > 500) {
      throw AsistenteException('Escribe una consulta de 1 a 500 caracteres.',
          statusCode: 422);
    }
    Map<String, dynamic> datos;
    try {
      datos = ResumenGastos.fromJson(resumen.toJson()).toJson();
    } on FormatException {
      throw AsistenteException(
          'El resumen del backend no tiene el formato esperado.');
    }
    try {
      final r = await _dio.post(
        '/asistente',
        data: {'consulta': consulta.trim(), 'resumen': datos},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (!vigente()) throw AsistenteException(_mensajeSesion, statusCode: 401);
      if (r.data is! Map<String, dynamic>) {
        throw AsistenteException(
            'La respuesta del asistente no tiene el formato esperado.');
      }
      return RespuestaIA.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (!vigente()) throw AsistenteException(_mensajeSesion, statusCode: 401);
      final codigo = e.response?.statusCode;
      if (codigo == 401) {
        _api.alSesionCaducada?.call();
        throw AsistenteException('Tu sesión caducó, inicia sesión de nuevo.',
            statusCode: 401);
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw AsistenteException(
            'El asistente tardó demasiado en responder. Inténtalo de nuevo.');
      }
      // No reflejar detail remoto: podría contener el token o la consulta.
      if (e.type == DioExceptionType.badResponse) {
        final mensaje = switch (codigo) {
          503 =>
            'El proxy no pudo obtener tu resumen por MCP. Revisa el backend e inténtalo de nuevo.',
          422 || 413 => 'El proxy rechazó el formato o tamaño de la consulta.',
          429 =>
            'El asistente alcanzó el límite de consultas. Inténtalo más tarde.',
          _ =>
            'El proxy del asistente respondió con un error. Inténtalo de nuevo.',
        };
        throw AsistenteException(mensaje, statusCode: codigo);
      }
      throw AsistenteException(
          'No se pudo conectar con el asistente. Revisa que el proxy esté encendido.');
    }
  }
}
