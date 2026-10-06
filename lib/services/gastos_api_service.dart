// Contrato de la Sesión 6, basado en Patricio-CEDIA/exploraec-app.
import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/gasto.dart';
import 'api_exception.dart';

class GastosApiService {
  GastosApiService({http.Client? cliente, String? baseUrl, Duration? plazo})
      : _cliente = cliente ?? http.Client(),
        baseUrl =
            (baseUrl ?? ApiConfig.baseUrl).replaceFirst(RegExp(r'/+$'), ''),
        _plazo = plazo;

  final http.Client _cliente;
  final String baseUrl;
  Duration? _plazo;
  String? _token;
  int _generacionToken = 0;

  /// JWT solo en memoria: nunca se escribe en disco ni se imprime.
  bool get tieneToken => _token != null;

  Duration get plazo =>
      _plazo ?? const Duration(milliseconds: ApiConfig.timeoutMs);

  /// Adaptación del Paso 9: conserva la misma sesión mientras cambia el plazo.
  void configurarTimeoutParaPruebas(Duration valor) {
    if (valor <= Duration.zero) {
      throw ArgumentError.value(valor, 'valor', 'El plazo debe ser positivo.');
    }
    _plazo = valor;
  }

  void cerrarSesion() {
    _generacionToken++;
    _token = null;
  }

  /// Solo práctica: la siguiente petición recibirá un 401 real.
  void invalidarTokenParaPruebas() {
    _generacionToken++;
    _token = 'token-invalido';
  }

  Future<void> registrar(String email, String password) async {
    await _enviar(() => _cliente.post(
          Uri.parse('$baseUrl/usuarios/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        ));
  }

  Future<void> login(String email, String password) async {
    final generacion = ++_generacionToken;
    final respuesta = await _enviar(() => _cliente.post(
          Uri.parse('$baseUrl/usuarios/token'),
          // El Map se codifica como formulario, con el campo username.
          body: {'username': email, 'password': password},
        ));
    final json = _decodificar(respuesta);
    final token = json is Map ? json['access_token'] : null;
    if (token is! String || token.isEmpty) {
      throw ApiException(
          'Respuesta inesperada del servidor al iniciar sesión.');
    }
    // Un login pendiente no debe restaurar el token tras cerrar la sesión.
    if (generacion == _generacionToken) _token = token;
  }

  Future<({List<Gasto> gastos, int total})> listarGastos({
    int skip = 0,
    int limit = 20,
  }) async {
    final token = _token;
    if (token == null) {
      throw ApiException('Inicia sesión para ver tus gastos.', statusCode: 401);
    }
    final uri = Uri.parse('$baseUrl/gastos/').replace(
      queryParameters: {'skip': '$skip', 'limit': '$limit'},
    );
    final respuesta = await _enviar(() => _cliente.get(
          uri,
          headers: {'Authorization': 'Bearer $token'},
        ));
    final json = _decodificar(respuesta);
    if (json is! List) {
      throw ApiException('Respuesta inesperada del servidor al listar gastos.');
    }
    final gastos =
        json.whereType<Map<String, dynamic>>().map(Gasto.fromJson).toList();
    final total =
        int.tryParse(respuesta.headers['x-total-count'] ?? '') ?? gastos.length;
    return (gastos: gastos, total: total);
  }

  dynamic _decodificar(http.Response respuesta) {
    try {
      return jsonDecode(utf8.decode(respuesta.bodyBytes));
    } on FormatException {
      throw ApiException('El servidor envió una respuesta JSON inválida.');
    }
  }

  /// Todas las peticiones comparten un único timeout y traducción de errores.
  Future<http.Response> _enviar(
      Future<http.Response> Function() peticion) async {
    try {
      final respuesta = await peticion().timeout(plazo);
      if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
        return respuesta;
      }
      throw _errorHttp(respuesta);
    } on SocketException {
      throw ApiException(
          'No hay conexión con el servidor. Revisa tu red y que el backend esté encendido.');
    } on http.ClientException {
      throw ApiException(
          'No hay conexión con el servidor. Revisa tu red y que el backend esté encendido.');
    } on TimeoutException {
      throw ApiException(
          'El servidor tardó demasiado en responder. Revisa tu conexión e inténtalo de nuevo.');
    }
  }

  ApiException _errorHttp(http.Response respuesta) {
    final codigo = respuesta.statusCode;
    if (codigo == 401) {
      return ApiException(
          'Tu sesión caducó o las credenciales no son válidas. Inicia sesión de nuevo.',
          statusCode: codigo);
    }
    if (codigo >= 500) {
      return ApiException('El servidor tuvo un problema. Inténtalo más tarde.',
          statusCode: codigo);
    }
    return ApiException(_leerDetail(respuesta), statusCode: codigo);
  }

  String _leerDetail(http.Response respuesta) {
    try {
      final json = jsonDecode(utf8.decode(respuesta.bodyBytes));
      final detail = json is Map ? json['detail'] : null;
      if (detail is String) return detail;
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
        if (partes.isNotEmpty) return 'Datos inválidos — ${partes.join('; ')}';
      }
    } on FormatException {
      // Una respuesta no JSON también termina en un mensaje comprensible.
    }
    return 'La petición no pudo completarse (código ${respuesta.statusCode}).';
  }

  String _mensajeValidacion(Map error, String campo) {
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

  void dispose() {
    cerrarSesion();
    _cliente.close();
  }
}
