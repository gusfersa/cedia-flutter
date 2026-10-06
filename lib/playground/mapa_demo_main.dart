// Demostración académica: coordenadas públicas de Café Galletti (Quito).
// No consulta el GPS del usuario. main.dart conserva el servicio real.
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../controllers/places_controller.dart';
import '../main.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(PlacesController(obtenerPosicion: () async {
    return Position(
      latitude: -0.1938,
      longitude: -78.4869,
      timestamp: DateTime.utc(2026, 10, 1),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }));
  runApp(const ExploraEcApp());
}
