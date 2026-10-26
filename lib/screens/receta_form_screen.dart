import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/recetas_controller.dart';
import '../models/receta.dart';
import '../theme/app_theme.dart';
import '../widgets/sin_sesion_view.dart';

class RecetaFormScreen extends StatefulWidget {
  const RecetaFormScreen({super.key});

  @override
  State<RecetaFormScreen> createState() => _RecetaFormScreenState();
}

class _RecetaFormScreenState extends State<RecetaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _tiempoController = TextEditingController(text: '25');
  final _porcionesController = TextEditingController(text: '4');
  final _caloriasController = TextEditingController(text: '350');
  final _ingredientesController = TextEditingController();
  final _instruccionesController = TextEditingController();
  final _imageUrlController = TextEditingController(
    text: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600',
  );

  String _categoria = 'Almuerzo';
  String _dificultad = 'Fácil';

  final List<String> _categorias = const [
    'Desayuno',
    'Almuerzo',
    'Cena',
    'Postre',
    'Saludable',
  ];

  final List<String> _dificultades = const ['Fácil', 'Media', 'Avanzada'];

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _tiempoController.dispose();
    _porcionesController.dispose();
    _caloriasController.dispose();
    _ingredientesController.dispose();
    _instruccionesController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _guardarReceta() async {
    if (!_formKey.currentState!.validate()) return;

    final authController = Get.find<AuthController>();
    final recetasController = Get.find<RecetasController>();

    final ingredientes = _ingredientesController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final instrucciones = _instruccionesController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final nuevaReceta = Receta(
      id: '',
      titulo: _tituloController.text.trim(),
      descripcion: _descripcionController.text.trim(),
      categoria: _categoria,
      tiempoMinutos: int.tryParse(_tiempoController.text) ?? 20,
      porciones: int.tryParse(_porcionesController.text) ?? 2,
      dificultad: _dificultad,
      calorias: int.tryParse(_caloriasController.text) ?? 300,
      ingredientes: ingredientes.isNotEmpty ? ingredientes : ['Ingredientes al gusto'],
      instrucciones: instrucciones.isNotEmpty ? instrucciones : ['Preparar y servir caliente'],
      imageUrl: _imageUrlController.text.trim().isNotEmpty
          ? _imageUrlController.text.trim()
          : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600',
      autorId: authController.usuario.value?.id ?? 'usuario',
      autorNombre: authController.usuario.value?.nombre ?? 'Mi Chef',
      creadoEn: DateTime.now().toIso8601String(),
    );

    final exito = await recetasController.crearReceta(nuevaReceta);
    if (exito) {
      Get.back();
      Get.snackbar(
        '¡Receta Publicada!',
        '«${nuevaReceta.titulo}» fue guardada en el catálogo remoto.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.dark,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nueva Receta'),
      ),
      body: Obx(() {
        if (!authController.isAuthenticated) {
          return const SinSesionView(
            accion: 'para poder publicar nuevas recetas en el catálogo remoto',
          );
        }

        final recetasController = Get.find<RecetasController>();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (recetasController.hasError.value)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      recetasController.errorMessage.value,
                      style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                    ),
                  ),
                TextFormField(
                  controller: _tituloController,
                  decoration: const InputDecoration(
                    labelText: 'Título de la Receta',
                    hintText: 'Ej. Risotto de Espárragos',
                    prefixIcon: Icon(Icons.restaurant_menu_rounded),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 3) ? 'Ingresa al menos 3 caracteres' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descripcionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descripción Corta',
                    hintText: 'Explica qué hace especial a este plato...',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 5) ? 'Ingresa al menos 5 caracteres' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _categoria,
                        decoration: const InputDecoration(labelText: 'Categoría'),
                        items: _categorias
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _categoria = val);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _dificultad,
                        decoration: const InputDecoration(labelText: 'Dificultad'),
                        items: _dificultades
                            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _dificultad = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tiempoController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tiempo (min)',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                        validator: (v) => (v == null || int.tryParse(v) == null) ? 'Número válido' : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        controller: _porcionesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Porciones',
                          prefixIcon: Icon(Icons.people_outline),
                        ),
                        validator: (v) => (v == null || int.tryParse(v) == null) ? 'Número válido' : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        controller: _caloriasController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Kcal',
                          prefixIcon: Icon(Icons.local_fire_department_outlined),
                        ),
                        validator: (v) => (v == null || int.tryParse(v) == null) ? 'Número válido' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _ingredientesController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Ingredientes (uno por línea)',
                    hintText: '500g de harina\n2 huevos\n1 taza de leche',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Escribe al menos un ingrediente' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _instruccionesController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Instrucciones (un paso por línea)',
                    hintText: 'Paso 1: Mezclar los ingredientes secos.\nPaso 2: Incorporar los líquidos.',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Escribe al menos un paso' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'URL de Imagen (opcional)',
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Obx(() {
                  final cargando = recetasController.isLoading.value;
                  return ElevatedButton.icon(
                    onPressed: cargando ? null : _guardarReceta,
                    icon: cargando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload_rounded),
                    label: const Text('Publicar en Catálogo Remoto'),
                  );
                }),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        );
      }),
    );
  }
}
