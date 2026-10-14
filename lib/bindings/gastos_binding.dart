import 'package:get/get.dart';

import '../controllers/gastos_controller.dart';
import '../controllers/auth_controller.dart';
import '../services/api_client.dart';
import '../services/ai_assistant_service.dart';

class GastosBinding extends Bindings {
  @override
  void dependencies() {
    final existente = Get.isRegistered<GastosController>()
        ? Get.find<GastosController>()
        : null;
    if (!Get.isRegistered<ApiClient>()) {
      Get.put(existente?.auth.api ?? ApiClient());
    }
    if (!Get.isRegistered<AuthController>()) {
      Get.put(existente?.auth ?? AuthController());
    }
    if (!Get.isRegistered<GastosController>()) Get.put(GastosController());
    if (!Get.isRegistered<AiAssistantService>()) {
      Get.put(AiAssistantService(), permanent: true);
    }
  }
}
