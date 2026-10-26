import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ErrorView extends StatelessWidget {
  final int? statusCode;
  final String mensaje;
  final VoidCallback? onReintentar;

  const ErrorView({
    super.key,
    this.statusCode,
    required this.mensaje,
    this.onReintentar,
  });

  String _obtenerTitulo() {
    switch (statusCode) {
      case 401:
        return 'Sesión no autorizada o caducada';
      case 400:
        return 'Solicitud incorrecta';
      case 404:
        return 'Recurso no encontrado';
      case 422:
        return 'Error de validación de datos';
      case 500:
      case 502:
      case 503:
        return 'Error interno en el servidor';
      default:
        return 'Error de conexión con el backend';
    }
  }

  IconData _obtenerIcono() {
    switch (statusCode) {
      case 401:
        return Icons.lock_clock_rounded;
      case 404:
        return Icons.search_off_rounded;
      case 422:
        return Icons.rule_folder_rounded;
      case 500:
      case 502:
      case 503:
        return Icons.dns_rounded;
      default:
        return Icons.wifi_off_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _obtenerTitulo();
    final icono = _obtenerIcono();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: Color(0x14F44336),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 52, color: Colors.red.shade700),
            ),
            const SizedBox(height: AppSpacing.md),
            if (statusCode != null && statusCode! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'Código HTTP: $statusCode',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.dark,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            if (onReintentar != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar conexión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.dark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
