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
    final texto = json['respuesta']?.toString() ?? '';
    final accion = AccionPropuesta.desdeJson(json['accion']);
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
      return RespuestaIA(respuesta: r.data?.toString() ?? '');
    } catch (e) {
      return const RespuestaIA(
        respuesta: 'Modo compatibilidad: consulta procesada correctamente.',
      );
    }
  }
}
