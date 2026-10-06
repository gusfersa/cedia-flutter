import 'package:geolocator/geolocator.dart';

// Coordenadas públicas del ejemplo docente; nunca consulta un sensor real.
Position posicionCafeGalletti() => Position(
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

class GeoFake extends GeolocatorPlatform {
  bool servicioActivo = true;
  LocationPermission permiso = LocationPermission.whileInUse;
  LocationPermission permisoSolicitado = LocationPermission.whileInUse;
  int consultasPermiso = 0;
  int solicitudesPermiso = 0;
  int lecturasPosicion = 0;
  LocationSettings? ajustes;

  @override
  Future<bool> isLocationServiceEnabled() async => servicioActivo;

  @override
  Future<LocationPermission> checkPermission() async {
    consultasPermiso++;
    return permiso;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    solicitudesPermiso++;
    return permisoSolicitado;
  }

  @override
  Future<Position> getCurrentPosition(
      {LocationSettings? locationSettings}) async {
    lecturasPosicion++;
    ajustes = locationSettings;
    return posicionCafeGalletti();
  }
}
