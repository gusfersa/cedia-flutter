// Lista navegable de la práctica CEDIA MOD3, basada en ExploraEC sesion-02.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/places_controller.dart';
import '../models/place.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_view.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/place_card.dart';
import 'add_place_screen.dart';

class HomeScreen extends GetView<PlacesController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text('ExploraEC (${controller.total})')),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Simular estado (solo práctica)',
            onSelected: controller.simular,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'normal', child: Text('Simular: normal')),
              PopupMenuItem(value: 'vacio', child: Text('Simular: vacío')),
              PopupMenuItem(value: 'error', child: Text('Simular: error')),
            ],
          ),
        ],
      ),
      body: Obx(() {
        if (controller.estado.value == EstadoCarga.cargando) {
          return const LoadingView(mensaje: 'Buscando lugares cercanos...');
        }
        if (controller.estado.value == EstadoCarga.error) {
          return ErrorView(
            mensaje: controller.mensajeError.value,
            onReintentar: controller.cargarLugares,
          );
        }
        if (controller.lugares.isEmpty) {
          return const EmptyView(mensaje: 'Todavía no hay lugares guardados');
        }
        // Copiar dentro de Obx registra la dependencia también de los elementos.
        return _buildLista(controller.lugares.toList());
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.to<void>(() => const AddPlaceScreen()),
        tooltip: 'Agregar lugar',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLista(List<Place> lugares) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return ListView.builder(
            controller: controller.scrollController,
            padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 80),
            itemCount: lugares.length,
            itemBuilder: (context, index) => PlaceCard(
              key: ValueKey(lugares[index].id),
              place: lugares[index],
            ),
          );
        }
        final columnas = constraints.maxWidth < 900 ? 2 : 3;
        return GridView.builder(
          controller: controller.scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            80,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnas,
            childAspectRatio: 2.2,
          ),
          itemCount: lugares.length,
          itemBuilder: (context, index) => PlaceCard(
            key: ValueKey(lugares[index].id),
            place: lugares[index],
          ),
        );
      },
    );
  }
}
