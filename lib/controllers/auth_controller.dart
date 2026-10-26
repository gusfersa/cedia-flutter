import 'package:get/get.dart';

import '../models/usuario.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';

typedef LimpiezaSesion = Future<void> Function(bool definitivo);

class AuthController extends GetxController {
  final AuthService _authService;

  AuthController({AuthService? authService, ApiClient? api})
      : _authService = authService ?? AuthService(apiClient: api);

  final Rx<Usuario?> usuario = Rx<Usuario?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  bool get isAuthenticated => usuario.value != null;

  // Propiedades y métodos de compatibilidad con arneses previos
  ApiClient get api => _authService.apiClient;
  RxBool get cargando => isLoading;
  RxString get mensajeError => errorMessage;
  bool get estaAutenticado => isAuthenticated;
  Future<void>? get cierrePendiente => Future.value();

  void agregarLimpieza(LimpiezaSesion limpieza) {}
  void quitarLimpieza(LimpiezaSesion limpieza) {}

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

  Future<void> iniciarSesion(String email, String password) async {
    await login(email, password);
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

  Future<void> cerrarSesion({String aviso = ''}) async {
    await logout();
  }
}
