// Contrato docente de Patricio-CEDIA/exploraec-app, sesiones 6–8.
import 'dart:convert';

import 'package:dio/dio.dart';

/// Error HTTP/red traducido, sin JSON técnico ni datos sensibles en la UI.
class ApiException implements Exception {
  ApiException(this.mensaje, {this.statusCode});
  final String mensaje;
  final int? statusCode;

  factory ApiException.desde(DioException error) {
    if (error.error is FormatException) {
      return ApiException('El servidor envió una respuesta JSON inválida.');
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
            'El servidor tardó demasiado en responder. Revisa tu conexión e inténtalo de nuevo.');
      case DioExceptionType.connectionError:
        return ApiException(
            'No hay conexión con el servidor. Revisa tu red y que el backend esté encendido.');
      case DioExceptionType.badResponse:
        return _desdeRespuesta(error.response!, error.requestOptions.path);
      case DioExceptionType.cancel:
        return ApiException('La sesión cambió. Inicia sesión de nuevo.');
      default:
        return ApiException(
            'No se pudo completar la petición. Inténtalo de nuevo.');
    }
  }

  static ApiException _desdeRespuesta(
      Response<dynamic> respuesta, String ruta) {
    final codigo = respuesta.statusCode;
    dynamic cuerpo = respuesta.data;
    if (cuerpo is String) {
      try {
        cuerpo = jsonDecode(cuerpo);
      } on FormatException {
        cuerpo = null;
      }
    }
    final detail = cuerpo is Map ? cuerpo['detail'] : null;
    if (codigo == 401) {
      return ApiException(
        Uri.parse(ruta).path == '/usuarios/token' && detail is String
            ? detail
            : 'Tu sesión caducó, inicia sesión de nuevo.',
        statusCode: codigo,
      );
    }
    if (codigo != null && codigo >= 500) {
      return ApiException('El servidor tuvo un problema. Inténtalo más tarde.',
          statusCode: codigo);
    }
    if (detail is String && detail.isNotEmpty) {
      return ApiException(detail, statusCode: codigo);
    }
    if (detail is List) {
      final partes = detail.whereType<Map>().map((error) {
        final loc = error['loc'];
        final campo = loc is List && loc.isNotEmpty ? '${loc.last}' : 'dato';
        final nombre = switch (campo) {
          'email' || 'username' => 'correo',
          'password' => 'contraseña',
          _ => campo,
        };
        return '$nombre: ${_mensajeValidacion(error, campo)}';
      }).toList();
      if (partes.isNotEmpty) {
        return ApiException('Datos inválidos — ${partes.join('; ')}',
            statusCode: codigo);
      }
    }
    return ApiException('La petición no pudo completarse (código $codigo).',
        statusCode: codigo);
  }

  static String _mensajeValidacion(Map error, String campo) {
    final contexto = error['ctx'] is Map ? error['ctx'] as Map : const {};
    final minimo = contexto['min_length'];
    final maximo = contexto['max_length'];
    return switch (error['type']) {
      'string_too_short' => minimo is num
          ? 'Debe tener al menos ${minimo.toInt()} caracteres'
          : 'Este valor es demasiado corto',
      'string_too_long' => maximo is num
          ? 'Debe tener como máximo ${maximo.toInt()} caracteres'
          : 'Este valor es demasiado largo',
      'missing' => 'Este campo es obligatorio',
      'string_type' => 'Escribe un texto válido',
      'int_parsing' ||
      'int_type' ||
      'float_parsing' ||
      'float_type' ||
      'decimal_parsing' ||
      'decimal_type' =>
        'Escribe un número válido',
      'greater_than' ||
      'greater_than_equal' ||
      'less_than' ||
      'less_than_equal' =>
        'El número está fuera del intervalo permitido',
      'enum' || 'literal_error' => 'Elige una opción permitida',
      'value_error' when campo == 'email' => 'Ingresa un correo válido',
      _ => 'Revisa este valor',
    };
  }

  @override
  String toString() => mensaje;
}
