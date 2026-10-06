// Ubicación y distancias de la práctica CEDIA MOD3, ExploraEC sesion-05.
import 'package:geolocator/geolocator.dart';

import '../models/place.dart';

class LocationException implements Exception {
  final String mensaje;
  LocationException(this.mensaje);

  @override
  String toString() => mensaje;
}

class LocationService {
  LocationService._();

  static Future<Position> obtenerPosicionActual() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException(
        'La ubicación está desactivada en el dispositivo. Actívala en Ajustes y vuelve a intentar.',
      );
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied) {
      throw LocationException(
        'Permiso de ubicación denegado. ExploraEC lo necesita para mostrarte lugares cercanos.',
      );
    }
    if (permiso == LocationPermission.deniedForever) {
      throw LocationException(
        'Permiso de ubicación bloqueado permanentemente. Actívalo manualmente desde Ajustes de la app.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}

double distanciaAPlaceEnMetros(Position origen, Place destino) {
  return Geolocator.distanceBetween(
    origen.latitude,
    origen.longitude,
    destino.lat,
    destino.lng,
  );
}

String formatearDistancia(double metros) {
  if (metros < 1000) return '${metros.round()} m';
  return '${(metros / 1000).toStringAsFixed(1)} km';
}
