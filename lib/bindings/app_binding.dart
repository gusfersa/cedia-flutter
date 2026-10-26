import 'package:get/get.dart';

import '../controllers/asistente_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/favoritos_controller.dart';
import '../controllers/recetas_controller.dart';
import '../services/ai_assistant_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/recetas_service.dart';
import '../services/secure_token_storage.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    // 1. Clientes y almacenamiento base
    final apiClient = Get.put<ApiClient>(ApiClient(), permanent: true);
    final tokenStorage = Get.put<SecureTokenStorage>(SecureTokenStorage(), permanent: true);

    // 2. Servicios
    final authService = Get.put<AuthService>(
      AuthService(apiClient: apiClient, tokenStorage: tokenStorage),
      permanent: true,
    );
    final recetasService = Get.put<RecetasService>(
      RecetasService(apiClient: apiClient),
      permanent: true,
    );
    final aiService = Get.put<AiAssistantService>(
      AiAssistantService(apiClient: apiClient),
      permanent: true,
    );

    // 3. Controladores GetX
    Get.put<AuthController>(AuthController(authService: authService), permanent: true);
    Get.put<FavoritosController>(FavoritosController(), permanent: true);
    Get.put<RecetasController>(RecetasController(recetasService: recetasService), permanent: true);
    Get.put<AsistenteController>(AsistenteController(aiService: aiService), permanent: true);
  }
}
