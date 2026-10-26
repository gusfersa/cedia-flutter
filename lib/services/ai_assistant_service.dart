import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../models/resumen_gastos.dart';
import 'api_client.dart';

const kAiBackendUrl = String.fromEnvironment(
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

  static AccionPropuesta? desdeJson(dynamic json) {
    if (json is! Map) return null;
    final descripcion = json['descripcion'];
    final monto = json['monto'];
    final categoria = json['categoria'];
    if (json['tipo'] != 'registrar_gasto' ||
        descripcion is! String ||
        descripcion.trim().isEmpty ||
        monto is! num ||
        categoria is! String) {
      return null;
    }
    return AccionPropuesta(
      tipo: 'registrar_gasto',
      descripcion: descripcion.trim(),
      monto: monto.toDouble(),
      categoria: categoria,
    );
  }
}

class RespuestaIA {
  final String respuesta;
  final AccionPropuesta? accion;
  const RespuestaIA({required this.respuesta, this.accion});

  factory RespuestaIA.fromJson(Map<String, dynamic> json) {
    final texto = json['respuesta'];
    if (texto is! String || texto.trim().isEmpty) {
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

class AiAssistantService {
  final ApiClient _apiClient;
  final Dio _dio;

  AiAssistantService({ApiClient? apiClient, ApiClient? api, Dio? dio})
      : _apiClient = apiClient ?? api ?? (Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient()),
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: kAiBackendUrl,
              connectTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
            ));

  // Método utilizado por ChefCraft
  Future<Map<String, dynamic>> consultarAsistente(String mensaje) async {
    final respuesta = await _apiClient.post(
      '/api/ai/chat',
      data: {
        'mensaje': mensaje,
      },
    );

    if (respuesta.data is Map) {
      return Map<String, dynamic>.from(respuesta.data as Map);
    }
    return {
      'respuesta': 'No se pudo decodificar la respuesta del asistente.',
      'sugerencias': <String>[],
    };
  }

  // Métodos de compatibilidad con arneses previos de ExploraEC
  Future<T> protegerSesion<T>(
    String tokenOriginal,
    bool Function() vigente,
    Future<T> Function() operacion,
  ) async {
    return await operacion();
  }

  Future<RespuestaIA> preguntar(String consulta, ResumenGastos resumen) async {
    if (consulta.trim().isEmpty || consulta.length > 500) {
      throw AsistenteException('Escribe una consulta de 1 a 500 caracteres.',
          statusCode: 422);
    }
    try {
      final token = _apiClient.token;
      final r = await _dio.post(
        '/asistente',
        data: {'consulta': consulta.trim(), 'resumen': resumen.toJson()},
        options: Options(headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        }),
      );
      if (r.data is Map<String, dynamic>) {
        return RespuestaIA.fromJson(r.data as Map<String, dynamic>);
      }
      throw AsistenteException(
          'La respuesta del asistente no tiene el formato esperado.');
    } on DioException catch (e) {
      final codigo = e.response?.statusCode;
      if (codigo == 401) {
        _apiClient.alSesionCaducada?.call();
        throw AsistenteException('Tu sesión caducó, inicia sesión de nuevo.',
            statusCode: 401);
      }
      throw AsistenteException(
          'No se pudo conectar con el asistente. Revisa que el proxy esté encendido.',
          statusCode: codigo);
    }
  }
}
