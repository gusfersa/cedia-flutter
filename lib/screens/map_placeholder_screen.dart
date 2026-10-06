import 'package:flutter/material.dart';

// Pantalla provisional requerida por la Sesión 2 del curso CEDIA MOD3.
class MapPlaceholderScreen extends StatelessWidget {
  const MapPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Próximamente: mapa real (Sesión 5)'),
        ),
      ),
    );
  }
}
