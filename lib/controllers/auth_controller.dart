import 'package:get/get.dart';

import '../models/usuario.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';

class AuthController extends GetxController {
  final AuthService _authService;

  AuthController({AuthService? authService})
      : _authService = authService ?? AuthService();

  final Rx<Usuario?> usuario = Rx<Usuario?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  bool get isAuthenticated => usuario.value != null;

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

  Future<void> logout() async {
    await _authService.logout();
    usuario.value = null;
    errorMessage.value = '';
  }
}
