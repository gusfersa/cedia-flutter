// Detalle de la práctica CEDIA MOD3; referencia: ExploraEC sesion-02.
import 'package:flutter/material.dart';

import '../models/place.dart';
import '../services/location_service.dart';

class DetailScreen extends StatelessWidget {
  final Place place;
  final double? distanciaMetros;
  const DetailScreen({super.key, required this.place, this.distanciaMetros});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(place.nombre)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place.nombre,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(place.categoria)),
                if (distanciaMetros != null)
                  Chip(
                    avatar: const Icon(Icons.near_me, size: 16),
                    label:
                        Text('A ${formatearDistancia(distanciaMetros!)} de ti'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(place.descripcion, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
