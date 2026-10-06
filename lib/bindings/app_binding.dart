import 'package:get/get.dart';

import 'gastos_binding.dart';
import 'places_binding.dart';

/// Cada módulo comparte una sola instancia entre sus pantallas.
class AppBinding extends Bindings {
  @override
  void dependencies() {
    PlacesBinding().dependencies();
    GastosBinding().dependencies();
  }
}
