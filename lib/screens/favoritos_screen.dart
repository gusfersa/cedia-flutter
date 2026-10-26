import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/favoritos_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/receta_card.dart';

class FavoritosScreen extends StatelessWidget {
  const FavoritosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favController = Get.find<FavoritosController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Recetas Favoritas'),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.offline_pin_rounded, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Hive Local',
                  style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (favController.isLoading.value) {
          return const LoadingView(mensaje: 'Cargando favoritos guardados...');
        }

        if (favController.favoritos.isEmpty) {
          return EmptyView(
            icono: Icons.favorite_border_rounded,
            titulo: 'No tienes recetas favoritas',
            mensaje: 'Guarda tus recetas preferidas pulsando el icono de corazón en cualquier tarjeta para cocinarlas incluso sin internet.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          itemCount: favController.favoritos.length,
          itemBuilder: (context, index) {
            final receta = favController.favoritos[index];
            return RecetaCard(receta: receta);
          },
        );
      }),
    );
  }
}
