import '../models/usuario.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';

class AuthService {
  final ApiClient _apiClient;
  final SecureTokenStorage _tokenStorage;

  AuthService({
    ApiClient? apiClient,
    SecureTokenStorage? tokenStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _tokenStorage = tokenStorage ?? SecureTokenStorage();

  Future<Usuario> register({
    required String nombre,
    required String email,
    required String password,
  }) async {
    final respuesta = await _apiClient.post(
      '/api/auth/register',
      data: {
        'nombre': nombre,
        'email': email,
        'password': password,
      },
    );

    final datos = respuesta.data is Map ? respuesta.data as Map<String, dynamic> : {};
    final token = datos['token']?.toString() ?? '';
    final usuarioJson = datos['usuario'] is Map ? datos['usuario'] as Map<String, dynamic> : {};

    if (token.isNotEmpty) {
      await _tokenStorage.guardar(token);
      _apiClient.token = token;
    }

    return Usuario.fromJson(usuarioJson, token: token);
  }

  Future<Usuario> login({
    required String email,
    required String password,
  }) async {
    final respuesta = await _apiClient.post(
      '/api/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    final datos = respuesta.data is Map ? respuesta.data as Map<String, dynamic> : {};
    final token = datos['token']?.toString() ?? '';
    final usuarioJson = datos['usuario'] is Map ? datos['usuario'] as Map<String, dynamic> : {};

    if (token.isNotEmpty) {
      await _tokenStorage.guardar(token);
      _apiClient.token = token;
    }

    return Usuario.fromJson(usuarioJson, token: token);
  }

  Future<Usuario?> getPerfil() async {
    final token = await _tokenStorage.leer();
    if (token == null || token.isEmpty) return null;

    _apiClient.token = token;
    try {
      final respuesta = await _apiClient.get('/api/auth/perfil');
      final datos = respuesta.data is Map ? respuesta.data as Map<String, dynamic> : {};
      return Usuario.fromJson(datos, token: token);
    } catch (_) {
      await _tokenStorage.borrar();
      _apiClient.token = null;
      return null;
    }
  }

  Future<void> logout() async {
    await _tokenStorage.borrar();
    _apiClient.token = null;
  }
}
