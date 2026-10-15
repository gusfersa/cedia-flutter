import 'package:flutter/material.dart';

/// La vista no recibe la excepción: ningún texto técnico llega a la pantalla.
class ErrorPantallaView extends StatelessWidget {
  const ErrorPantallaView({super.key, this.onVolver});

  final VoidCallback? onVolver;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: const Color(0xFFF8FAFC),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sentiment_dissatisfied_outlined, size: 40),
                  const SizedBox(height: 16),
                  const Text('Esta pantalla tuvo un problema',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text('Puedes volver e intentarlo de nuevo.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onVolver ??
                        () => Navigator.maybeOf(context)?.maybePop(),
                    child: const Text('Volver a un lugar seguro'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
