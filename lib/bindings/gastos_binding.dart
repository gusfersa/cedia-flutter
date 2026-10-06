import 'package:get/get.dart';

import '../controllers/gastos_controller.dart';

class GastosBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<GastosController>()) Get.put(GastosController());
  }
}
