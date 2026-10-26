import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/favoritos_controller.dart';
import '../models/receta.dart';
import '../screens/receta_detail_screen.dart';
import '../theme/app_theme.dart';

class RecetaCard extends StatelessWidget {
  final Receta receta;

  const RecetaCard({super.key, required this.receta});

  @override
  Widget build(BuildContext context) {
    final favController = Get.find<FavoritosController>();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Get.to(() => RecetaDetailScreen(receta: receta)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen de la receta con badges y botón de favorito
            Stack(
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Image.network(
                    receta.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: Icon(
                            Icons.restaurant_rounded,
                            size: 48,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Categoría badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xD91E293B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      receta.categoria,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Botón favorito
                Positioned(
                  top: 8,
                  right: 8,
                  child: Obx(() {
                    final esFav = favController.esFavorito(receta.id);
                    return Material(
                      color: const Color(0xE6FFFFFF),
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: Icon(
                          esFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: esFav ? Colors.red : const Color(0xFF64748B),
                          size: 20,
                        ),
                        onPressed: () => favController.toggleFavorito(receta),
                        tooltip: esFav ? 'Quitar de favoritos' : 'Guardar en favoritos',
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                    );
                  }),
                ),
              ],
            ),
            // Contenido textual
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    receta.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    receta.descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Metadatos: tiempo, calorías, dificultad
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${receta.tiempoMinutos} min',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const Icon(Icons.local_fire_department_outlined, size: 14, color: AppTheme.secondary),
                      const SizedBox(width: 4),
                      Text(
                        '${receta.calorias} kcal',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          receta.dificultad,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
