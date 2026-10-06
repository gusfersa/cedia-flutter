// Formulario validado de la práctica CEDIA MOD3, ExploraEC sesion-02.
import 'package:flutter/material.dart';

import '../models/place.dart';

class AddPlaceScreen extends StatefulWidget {
  const AddPlaceScreen({super.key});

  @override
  State<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends State<AddPlaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _categoriaController = TextEditingController();
  final _descripcionController = TextEditingController();

  @override
  void dispose() {
    _nombreController.dispose();
    _categoriaController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    lugaresEjemplo.add(
      Place(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        nombre: _nombreController.text.trim(),
        categoria: _categoriaController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        // Coordenadas de ejemplo: esta sesión no solicita geolocalización.
        lat: -0.1807,
        lng: -78.4859,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar lugar')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const ValueKey('nombre'),
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del lugar',
                  hintText: 'Ej. Parque El Ejido',
                ),
                textInputAction: TextInputAction.next,
                validator: (valor) => (valor == null || valor.trim().isEmpty)
                    ? 'El nombre es obligatorio'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('categoria'),
                controller: _categoriaController,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  hintText: 'Ej. Cafeterías',
                ),
                textInputAction: TextInputAction.next,
                validator: (valor) => (valor == null || valor.trim().isEmpty)
                    ? 'La categoría es obligatoria'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('descripcion'),
                controller: _descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
                validator: (valor) =>
                    (valor == null || valor.trim().length < 10)
                        ? 'Escribe al menos 10 caracteres'
                        : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _guardar, child: const Text('Guardar')),
            ],
          ),
        ),
      ),
    );
  }
}
