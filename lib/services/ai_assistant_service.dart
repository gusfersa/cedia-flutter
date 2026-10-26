import 'api_client.dart';

class AiAssistantService {
  final ApiClient _apiClient;

  AiAssistantService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

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
}
