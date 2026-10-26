import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../screens/login_screen.dart';
import '../theme/app_theme.dart';

class SinSesionView extends StatelessWidget {
  final String accion;

  const SinSesionView({
    super.key,
    this.accion = 'para acceder a esta funcionalidad',
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
                color: Color(0x1FFF9F1C),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 52,
                color: AppTheme.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Inicio de Sesión Requerido',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.dark,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Debes iniciar sesión con tu cuenta $accion.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () => Get.to(() => const LoginScreen()),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Iniciar Sesión Ahora'),
            ),
          ],
        ),
      ),
    );
  }
}
