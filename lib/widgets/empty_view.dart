import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EmptyView extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String mensaje;
  final String? textoBoton;
  final VoidCallback? onAccion;

  const EmptyView({
    super.key,
    this.icono = Icons.restaurant_menu_outlined,
    this.titulo = 'No hay recetas disponibles',
    this.mensaje = 'No encontramos elementos para esta búsqueda o categoría.',
    this.textoBoton,
    this.onAccion,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: Color(0x14E05A47),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 54, color: AppTheme.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.dark,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            if (textoBoton != null && onAccion != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: onAccion,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(textoBoton!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
