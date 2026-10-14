// Contrato docente de Patricio-CEDIA/exploraec-app, sesiones 6–8.
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

import '../models/gasto.dart';
import 'api_client.dart';

/// API de gastos sobre el mismo Dio que usa AuthController. La inyección de
/// un cliente HTTP conserva compatibilidad con consumidores de S6/S7, pasando
/// siempre por los interceptores y la traducción de errores de ApiClient.
class GastosApiService {
  GastosApiService(
      {ApiClient? api, http.Client? cliente, String? baseUrl, Duration? plazo})
      : client = api ?? ApiClient(baseUrl: baseUrl, plazo: plazo) {
    if (cliente != null) client.dio.httpClientAdapter = _AdaptadorHttp(cliente);
  }

  final ApiClient client;
  String get baseUrl => client.dio.options.baseUrl;
  bool get tieneToken => client.token != null;
  Duration get plazo => client.plazo;
  void configurarTimeoutParaPruebas(Duration valor) =>
      client.configurarTimeout(valor);
  void cerrarSesion() => client.token = null;
  void invalidarTokenParaPruebas() => client.token = 'token-invalido';

  Future<void> registrar(String email, String password) async {
    await client
        .post('/usuarios/', data: {'email': email, 'password': password});
  }

  /// Fachada de S6/S7 para consumidores del servicio; la app usa AuthController
  /// y añade validación /me y almacenamiento seguro antes de publicar usuario.
  Future<void> login(String email, String password) async {
    client.token = null;
    final generacion = client.generacionToken;
    try {
      final r = await client.post('/usuarios/token',
          data: {'username': email, 'password': password},
          options: Options(contentType: Headers.formUrlEncodedContentType));
      final token = r.data is Map ? (r.data as Map)['access_token'] : null;
      if (token is! String || token.isEmpty) {
        throw ApiException(
            'Respuesta inesperada del servidor al iniciar sesión.');
      }
      if (generacion == client.generacionToken) client.token = token;
    } on ApiException {
      if (generacion == client.generacionToken) rethrow;
    }
  }

  void _exigirToken() {
    if (!tieneToken) {
      throw ApiException('Inicia sesión para ver tus gastos.', statusCode: 401);
    }
  }

  Future<int> obtenerIdUsuario() async {
    _exigirToken();
    final r = await client.get('/usuarios/me');
    final id = r.data is Map ? (r.data as Map)['id'] : null;
    if (id is! int || id <= 0) {
      throw ApiException(
          'Respuesta inesperada del servidor al leer tu perfil.');
    }
    return id;
  }

  Future<({List<Gasto> gastos, int total})> listarGastos(
      {int skip = 0, int limit = 20}) async {
    _exigirToken();
    final r =
        await client.get('/gastos/', query: {'skip': skip, 'limit': limit});
    if (r.data is! List) {
      throw ApiException('Respuesta inesperada del servidor al listar gastos.');
    }
    final gastos = (r.data as List)
        .whereType<Map>()
        .map((g) => Gasto.fromJson(Map<String, dynamic>.from(g)))
        .toList();
    final total =
        int.tryParse(r.headers.value('x-total-count') ?? '') ?? gastos.length;
    return (gastos: gastos, total: total);
  }

  Future<({List<String> categorias, double limite})> listarCategorias() async {
    _exigirToken();
    final r = await client.get('/gastos/categorias');
    final json = r.data;
    if (json is! Map ||
        json['categorias'] is! List ||
        (json['categorias'] as List).any((c) => c is! String || c.isEmpty)) {
      throw ApiException(
          'Respuesta inesperada del servidor al leer las categorías.');
    }
    return (
      categorias: List<String>.from(json['categorias'] as List),
      limite: (json['limite_por_categoria'] as num?)?.toDouble() ?? 500
    );
  }

  Gasto _gasto(dynamic json) {
    if (json is! Map ||
        json['id'] is! int ||
        json['descripcion'] is! String ||
        json['monto'] is! num ||
        json['categoria'] is! String) {
      throw ApiException(
          'Respuesta inesperada del servidor al guardar el gasto.');
    }
    return Gasto.fromJson(Map<String, dynamic>.from(json));
  }

  Future<Gasto> crear(Map<String, dynamic> datos) async {
    _exigirToken();
    return _gasto((await client.post('/gastos/', data: datos)).data);
  }

  Future<Gasto> actualizar(int id, Map<String, dynamic> cambios) async {
    _exigirToken();
    return _gasto((await client.patch('/gastos/$id', data: cambios)).data);
  }

  Future<void> eliminar(int id) async {
    _exigirToken();
    await client.delete('/gastos/$id');
  }

  void dispose() => client.dispose();
}

/// Adaptador de transporte, sin otra implementación de sesión ni de errores.
class _AdaptadorHttp implements HttpClientAdapter {
  _AdaptadorHttp(this.cliente);
  final http.Client cliente;

  @override
  Future<ResponseBody> fetch(RequestOptions opciones, Stream<Uint8List>? cuerpo,
      Future<void>? cancelar) async {
    final peticion = http.Request(opciones.method, opciones.uri);
    peticion.headers.addAll(opciones.headers.map((k, v) => MapEntry(k, '$v')));
    if (cuerpo != null) {
      peticion.bodyBytes = (await cuerpo.toList()).expand((p) => p).toList();
    }
    try {
      final r = await cliente.send(peticion);
      return ResponseBody(r.stream.map(Uint8List.fromList), r.statusCode,
          headers: r.headers.map((k, v) => MapEntry(k, [v])));
    } catch (error, stack) {
      throw DioException(
          requestOptions: opciones,
          type: DioExceptionType.connectionError,
          error: error,
          stackTrace: stack);
    }
  }

  @override
  void close({bool force = false}) => cliente.close();
}
