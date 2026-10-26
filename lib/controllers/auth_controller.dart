import 'package:get/get.dart';

import '../models/usuario.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/secure_token_storage.dart';

typedef LimpiezaSesion = Future<void> Function(bool definitivo);

class AuthController extends GetxController {
  final AuthService _authService;

  AuthController({
    AuthService? authService,
    ApiClient? api,
    dynamic almacen,
  }) : _authService = authService ??
            AuthService(
              apiClient: api,
              tokenStorage: almacen is SecureTokenStorage ? almacen : null,
            );

  final Rx<Usuario?> usuario = Rx<Usuario?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  bool get isAuthenticated => usuario.value != null;

  // Propiedades y métodos de compatibilidad con arneses y pantallas previas
  ApiClient get api => _authService.apiClient;
  RxBool get cargando => isLoading;
  RxString get mensajeError => errorMessage;
  bool get estaAutenticado => isAuthenticated;
  Future<void> get cierrePendiente => Future.value();
  int get generacion => api.generacionToken;
  final RxBool restaurando = false.obs;
  Future<void> get restauracion => Future.value();
  final RxString avisoSesion = ''.obs;

  Future<void> restaurarSesion() async {
    restaurando.value = true;
    try {
      final token = await _authService.tokenStorage.leer();
      if (token != null && token.isNotEmpty) {
        api.token = token;
        try {
          final meRes = await api.get('/usuarios/me');
          if (meRes.data is Map) {
            usuario.value = Usuario.fromJson(
              Map<String, dynamic>.from(meRes.data as Map),
              token: token,
            );
            return;
          }
        } catch (_) {}
      }
      await verificarSesion();
    } finally {
      restaurando.value = false;
    }
  }

  Future<bool> iniciarSesion(String correo, String contrasena) async {
    // Soporte para pruebas legadas S08/S10 que usan /usuarios/token
    try {
      final r = await api.post(
        '/usuarios/token',
        data: {'username': correo, 'password': contrasena},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final token =
          r.data is Map ? (r.data as Map)['access_token']?.toString() : null;
      if (token != null && token.isNotEmpty) {
        api.token = token;
        await _authService.tokenStorage.guardar(token);
        final meRes = await api.get('/usuarios/me');
        if (meRes.data is Map) {
          usuario.value = Usuario.fromJson(
            Map<String, dynamic>.from(meRes.data as Map),
            token: token,
          );
          return true;
        }
      }
    } catch (_) {}
    return login(correo, contrasena);
  }

  Future<void> cerrarSesion({String aviso = ''}) async {
    avisoSesion.value = aviso;
    await logout();
  }

  void agregarLimpieza(LimpiezaSesion limpieza) {}
  void quitarLimpieza(LimpiezaSesion limpieza) {}
  Future<void> sesionCaducada() =>
      cerrarSesion(aviso: 'Tu sesión caducó, inicia sesión de nuevo.');
  void invalidarTokenParaPruebas() => api.token = 'token-invalido';
  Future<void> cargarUsuario() => verificarSesion();

  @override
  void onInit() {
    super.onInit();
    verificarSesion();
  }

  Future<void> verificarSesion() async {
    try {
      final perfil = await _authService.getPerfil();
      usuario.value = perfil;
    } catch (_) {
      usuario.value = null;
    }
  }

  Future<bool> login(String email, String password) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final u = await _authService.login(email: email, password: password);
      usuario.value = u;
      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.mensaje;
      return false;
    } catch (e) {
      errorMessage.value = 'Error al iniciar sesión: ${e.toString()}';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> register(String nombre, String email, String password) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final u = await _authService.register(
        nombre: nombre,
        email: email,
        password: password,
      );
      usuario.value = u;
      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.mensaje;
      return false;
    } catch (e) {
      errorMessage.value = 'Error al registrar usuario: ${e.toString()}';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> registrar(String email, String password, {bool continuarSiExiste = false}) async {
    final nombre = email.contains('@') ? email.split('@').first : 'Usuario';
    await register(nombre, email, password);
  }

  Future<void> logout() async {
    await _authService.logout();
    usuario.value = null;
    errorMessage.value = '';
  }
}
