import 'package:exploraec/models/place.dart';
import 'package:exploraec/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'helpers/geo_fake.dart';

void main() {
  final plataformaOriginal = GeolocatorPlatform.instance;
  late GeoFake geo;
  setUp(() {
    geo = GeoFake();
    GeolocatorPlatform.instance = geo;
  });
  tearDown(() => GeolocatorPlatform.instance = plataformaOriginal);

  test('Permiso concedido obtiene posición high sin volver a pedir permiso',
      () async {
    final posicion = await LocationService.obtenerPosicionActual();
    expect(posicion.latitude, -0.1938);
    expect(posicion.longitude, -78.4869);
    expect(geo.consultasPermiso, 1);
    expect(geo.solicitudesPermiso, 0);
    expect(geo.lecturasPosicion, 1);
    expect(geo.ajustes?.accuracy, LocationAccuracy.high);
  });

  test('Permiso denegado se solicita y continúa cuando se concede', () async {
    geo.permiso = LocationPermission.denied;
    final posicion = await LocationService.obtenerPosicionActual();
    expect(geo.solicitudesPermiso, 1);
    expect(geo.lecturasPosicion, 1);
    expect(posicion.latitude, -0.1938);
  });

  test('Rechazo del permiso explica el error y no lee la posición', () async {
    geo.permiso = LocationPermission.denied;
    geo.permisoSolicitado = LocationPermission.denied;
    await expectLater(
      LocationService.obtenerPosicionActual(),
      throwsA(isA<LocationException>().having(
        (error) => error.mensaje,
        'mensaje',
        contains('Permiso de ubicación denegado.'),
      )),
    );
    expect(geo.solicitudesPermiso, 1);
    expect(geo.lecturasPosicion, 0);
  });

  test('Bloqueo permanente indica Ajustes y no vuelve a solicitar permiso',
      () async {
    geo.permiso = LocationPermission.deniedForever;
    await expectLater(
      LocationService.obtenerPosicionActual(),
      throwsA(isA<LocationException>().having(
        (error) => error.mensaje,
        'mensaje',
        contains(
            'bloqueado permanentemente. Actívalo manualmente desde Ajustes'),
      )),
    );
    expect(geo.solicitudesPermiso, 0);
    expect(geo.lecturasPosicion, 0);
  });

  test('Servicio apagado se detecta antes del permiso y de leer el sensor',
      () async {
    geo.servicioActivo = false;
    await expectLater(
      LocationService.obtenerPosicionActual(),
      throwsA(isA<LocationException>().having(
        (error) => error.mensaje,
        'mensaje',
        contains('ubicación está desactivada'),
      )),
    );
    expect(geo.consultasPermiso, 0);
    expect(geo.solicitudesPermiso, 0);
    expect(geo.lecturasPosicion, 0);
  });

  test('Distancias públicas coherentes y formato en metros o kilómetros', () {
    final cafe = lugaresEjemplo.firstWhere((lugar) => lugar.id == '2');
    final parque = lugaresEjemplo.firstWhere((lugar) => lugar.id == '1');
    final posicion = posicionCafeGalletti();
    expect(distanciaAPlaceEnMetros(posicion, cafe), closeTo(0, 0.001));
    expect(distanciaAPlaceEnMetros(posicion, parque),
        inInclusiveRange(1400, 1700));
    expect(formatearDistancia(0), '0 m');
    expect(formatearDistancia(250.4), '250 m');
    expect(formatearDistancia(1500), '1.5 km');
    expect(geo.lecturasPosicion, 0);
  });
}
