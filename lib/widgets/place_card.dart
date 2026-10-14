// Tarjeta de la práctica CEDIA MOD3; referencia: ExploraEC, sesion-02.
// Sesión 7: añade el corazón de favorito, que lee/escribe PlacesController y
// se repinta con `Obx`; el favorito queda guardado en Hive.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/places_controller.dart';
import '../models/place.dart';
import '../screens/detail_screen.dart';
import '../theme/app_theme.dart';

class PlaceCard extends StatelessWidget {
  final Place place;
  const PlaceCard({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlacesController>();
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Stack(
        children: [
          InkWell(
            onTap: () => Get.to<void>(() => DetailScreen(place: place)),
            child: Semantics(
              label: '${place.nombre}, categoría ${place.categoria}',
              hint: 'Toca dos veces para ver el detalle',
              button: true,
              excludeSemantics: true,
              child: _buildContenido(context),
            ),
          ),
          Positioned(
            right: AppSpacing.xs,
            top: AppSpacing.xs,
            child: Obx(
              () => IconButton(
                icon: Icon(
                  controller.esFavorito(place)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color:
                      controller.esFavorito(place) ? Colors.red : Colors.grey,
                ),
                tooltip: controller.esFavorito(place)
                    ? 'Quitar de favoritos'
                    : 'Agregar a favoritos',
                onPressed: () => controller.alternarFavorito(place),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContenido(BuildContext context) {
    final estilos = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.place, size: 32, color: colores.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 40),
                  child: Text(
                    place.nombre,
                    style: estilos.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  place.categoria,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: estilos.bodySmall?.copyWith(
                    color: colores.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  place.descripcion,
                  style: estilos.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
