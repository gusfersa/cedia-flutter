import '../models/receta.dart';
import 'api_client.dart';

class RecetasService {
  final ApiClient _apiClient;

  RecetasService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<List<Receta>> getRecetas({String? categoria, String? busqueda}) async {
    final query = <String, dynamic>{};
    if (categoria != null && categoria != 'Todas') {
      query['categoria'] = categoria;
    }
    if (busqueda != null && busqueda.trim().isNotEmpty) {
      query['busqueda'] = busqueda.trim();
    }

    final respuesta = await _apiClient.get(
      '/api/recetas',
      query: query.isNotEmpty ? query : null,
    );

    final datos = respuesta.data;
    if (datos is Map && datos['recetas'] is List) {
      return (datos['recetas'] as List)
          .whereType<Map>()
          .map((r) => Receta.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    }
    return [];
  }

  Future<Receta> getRecetaPorId(String id) async {
    final respuesta = await _apiClient.get('/api/recetas/$id');
    final Map<String, dynamic> datos = respuesta.data is Map
        ? (respuesta.data as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    return Receta.fromJson(datos);
  }

  Future<Receta> crearReceta(Receta receta) async {
    final respuesta = await _apiClient.post(
      '/api/recetas',
      data: receta.toJson(),
    );

    final Map<String, dynamic> datos = respuesta.data is Map
        ? (respuesta.data as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final Map<String, dynamic> recetaJson = datos['receta'] is Map
        ? (datos['receta'] as Map).cast<String, dynamic>()
        : datos;
    return Receta.fromJson(recetaJson);
  }

  Future<void> eliminarReceta(String id) async {
    await _apiClient.delete('/api/recetas/$id');
  }
}
