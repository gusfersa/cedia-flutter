import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../models/receta.dart';

class FavoritosController extends GetxController {
  static const String boxName = 'recetas_favoritas';
  Box? _box;

  FavoritosController({Box? box}) : _box = box;

  final RxList<Receta> favoritos = <Receta>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    cargarFavoritos();
  }

  Future<Box> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    if (Hive.isBoxOpen(boxName)) {
      _box = Hive.box(boxName);
    } else {
      _box = await Hive.openBox(boxName);
    }
    return _box!;
  }

  Future<void> cargarFavoritos() async {
    isLoading.value = true;
    try {
      final box = await _getBox();
      final lista = <Receta>[];
      for (var i = 0; i < box.length; i++) {
        final item = box.getAt(i);
        if (item is Map) {
          lista.add(Receta.fromMap(item));
        }
      }
      favoritos.assignAll(lista);
    } catch (_) {
      favoritos.clear();
    } finally {
      isLoading.value = false;
    }
  }

  bool esFavorito(String id) {
    return favoritos.any((r) => r.id == id);
  }

  Future<void> toggleFavorito(Receta receta) async {
    try {
      final box = await _getBox();
      final index = favoritos.indexWhere((r) => r.id == receta.id);

      if (index >= 0) {
        // Eliminar de favoritos
        favoritos.removeAt(index);
        await box.delete(receta.id);
      } else {
        // Agregar a favoritos
        favoritos.add(receta);
        await box.put(receta.id, receta.toMap());
      }
    } catch (_) {
      // Manejo silencioso o reactivo
    }
  }
}
