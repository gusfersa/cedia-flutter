// Mapa de la práctica CEDIA MOD3, ExploraEC sesion-05.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../controllers/places_controller.dart';
import '../models/place.dart';
import '../theme/app_theme.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.tileProvider});

  // Las pruebas sustituyen las teselas para no depender de la red.
  final TileProvider? tileProvider;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final controller = Get.find<PlacesController>();

  @override
  void initState() {
    super.initState();
    controller.cargarPosicion();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa')),
      body: Obx(() {
        if (controller.estadoPosicion.value == EstadoCarga.cargando) {
          return const LoadingView(mensaje: 'Obteniendo tu ubicación...');
        }
        if (controller.estadoPosicion.value == EstadoCarga.error) {
          return ErrorView(
            mensaje: controller.mensajeErrorPosicion.value,
            onReintentar: () => controller.cargarPosicion(forzar: true),
          );
        }
        return _buildMapa(
          controller.posicion.value!,
          controller.lugares.toList(),
        );
      }),
    );
  }

  Widget _buildMapa(Position posicion, List<Place> lugares) {
    final miUbicacion = LatLng(posicion.latitude, posicion.longitude);
    return FlutterMap(
      options: MapOptions(initialCenter: miUbicacion, initialZoom: 15),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.bto.exploraec',
          tileProvider: widget.tileProvider,
        ),
        MarkerLayer(
          markers: [
            Marker(
              key: const ValueKey('marcador-usuario'),
              point: miUbicacion,
              width: 40,
              height: 40,
              child: Semantics(
                label: 'Tu ubicación actual',
                child: const Icon(
                  Icons.my_location,
                  color: Colors.blue,
                  size: 32,
                ),
              ),
            ),
            for (final lugar in lugares) _marcadorLugar(lugar),
          ],
        ),
        const SimpleAttributionWidget(
          source: Text('Colaboradores de OpenStreetMap'),
        ),
      ],
    );
  }

  Marker _marcadorLugar(Place lugar) {
    void abrirDetalle() => Get.to<void>(
          () => DetailScreen(
            place: lugar,
            distanciaMetros: controller.distanciaA(lugar),
          ),
        );

    return Marker(
      key: ValueKey('capa-marcador-${lugar.id}'),
      point: LatLng(lugar.lat, lugar.lng),
      width: 48,
      height: 48,
      child: IconButton(
        key: ValueKey('marcador-${lugar.id}'),
        tooltip: 'Ver ${lugar.nombre} en el mapa',
        onPressed: abrirDetalle,
        icon: const Icon(Icons.place),
        iconSize: 36,
        color: AppTheme.teal,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
