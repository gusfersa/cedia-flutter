import 'package:get/get.dart';

import '../controllers/places_controller.dart';

// Registrar una única dependencia antes de construir la primera pantalla.
class PlacesBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<PlacesController>()) {
      Get.put(PlacesController());
    }
  }
}
