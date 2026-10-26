import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/favoritos_controller.dart';
import '../controllers/recetas_controller.dart';
import '../models/receta.dart';
import '../theme/app_theme.dart';

class RecetaDetailScreen extends StatefulWidget {
  final Receta receta;

  const RecetaDetailScreen({super.key, required this.receta});

  @override
  State<RecetaDetailScreen> createState() => _RecetaDetailScreenState();
}

class _RecetaDetailScreenState extends State<RecetaDetailScreen> {
  final Set<int> _ingredientesMarcados = {};

  void _confirmarEliminacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Receta'),
        content: Text('¿Estás seguro de eliminar «${widget.receta.titulo}» del catálogo remoto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () async {
              Navigator.pop(ctx);
              final controller = Get.find<RecetasController>();
              final exito = await controller.eliminarReceta(widget.receta.id);
              if (exito) {
                Get.back(); // Regresar al catálogo
                Get.snackbar(
                  'Receta Eliminada',
                  'Se eliminó «${widget.receta.titulo}» correctamente.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppTheme.dark,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favController = Get.find<FavoritosController>();
    final authController = Get.find<AuthController>();
    final receta = widget.receta;

    final esAutor = authController.isAuthenticated &&
        authController.usuario.value?.id == receta.autorId;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // AppBar expansible con imagen
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                receta.titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    receta.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFE2E8F0),
                      child: const Center(
                        child: Icon(Icons.restaurant_rounded, size: 64, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black38, Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Obx(() {
                final esFav = favController.esFavorito(receta.id);
                return IconButton(
                  icon: Icon(
                    esFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: esFav ? Colors.redAccent : Colors.white,
                  ),
                  onPressed: () => favController.toggleFavorito(receta),
                  tooltip: esFav ? 'Quitar de favoritos' : 'Guardar en favoritos',
                );
              }),
              if (esAutor)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  onPressed: () => _confirmarEliminacion(context),
                  tooltip: 'Eliminar mi receta',
                ),
            ],
          ),
          // Contenido detallado
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadatos principales en tarjetas
                  Row(
                    children: [
                      Expanded(
                        child: _InfoPill(
                          icono: Icons.timer_outlined,
                          titulo: 'Tiempo',
                          valor: '${receta.tiempoMinutos} min',
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _InfoPill(
                          icono: Icons.local_fire_department_outlined,
                          titulo: 'Energía',
                          valor: '${receta.calorias} kcal',
                          color: AppTheme.secondary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _InfoPill(
                          icono: Icons.people_outline_rounded,
                          titulo: 'Porciones',
                          valor: '${receta.porciones}',
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Categoría y autor
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          receta.categoria,
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        'Por ${receta.autorNombre}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    receta.descripcion,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF334155),
                      height: 1.5,
                    ),
                  ),
                  const Divider(height: 36),
                  // Sección Ingredientes
                  Row(
                    children: [
                      const Icon(Icons.check_box_outlined, color: AppTheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Ingredientes (${receta.ingredientes.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.dark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...receta.ingredientes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ing = entry.value;
                    final marcado = _ingredientesMarcados.contains(index);

                    return CheckboxListTile(
                      value: marcado,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppTheme.accent,
                      title: Text(
                        ing,
                        style: TextStyle(
                          fontSize: 14,
                          decoration: marcado ? TextDecoration.lineThrough : null,
                          color: marcado ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _ingredientesMarcados.add(index);
                          } else {
                            _ingredientesMarcados.remove(index);
                          }
                        });
                      },
                    );
                  }),
                  const Divider(height: 36),
                  // Sección Instrucciones
                  Row(
                    children: [
                      const Icon(Icons.format_list_numbered_rounded, color: AppTheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      const Text(
                        'Instrucciones de Preparación',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.dark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...receta.instrucciones.asMap().entries.map((entry) {
                    final numPaso = entry.key + 1;
                    final paso = entry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$numPaso',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              paso,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF334155),
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;
  final Color color;

  const _InfoPill({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(height: 2),
          Text(
            titulo,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
