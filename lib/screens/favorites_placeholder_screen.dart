import 'package:flutter/material.dart';

// Pantalla provisional requerida por la Sesión 2 del curso CEDIA MOD3.
class FavoritesPlaceholderScreen extends StatelessWidget {
  const FavoritesPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Próximamente: favoritos (Sesión 7)'),
        ),
      ),
    );
  }
}
