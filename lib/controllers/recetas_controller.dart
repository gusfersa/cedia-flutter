import 'package:get/get.dart';

import '../models/receta.dart';
import '../services/api_exception.dart';
import '../services/recetas_service.dart';

class RecetasController extends GetxController {
  final RecetasService _recetasService;

  RecetasController({RecetasService? recetasService})
      : _recetasService = recetasService ?? RecetasService();

  final RxList<Receta> recetas = <Receta>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;
  final RxInt statusCodeError = 0.obs;

  final RxString categoriaSeleccionada = 'Todas'.obs;
  final RxString textoBusqueda = ''.obs;

  final List<String> categorias = const [
    'Todas',
    'Desayuno',
    'Almuerzo',
    'Cena',
    'Postre',
    'Saludable',
  ];

  @override
  void onInit() {
    super.onInit();
    cargarRecetas();
  }

  Future<void> cargarRecetas() async {
    isLoading.value = true;
    hasError.value = false;
    errorMessage.value = '';
    statusCodeError.value = 0;

    try {
      final lista = await _recetasService.getRecetas(
        categoria: categoriaSeleccionada.value == 'Todas' ? null : categoriaSeleccionada.value,
        busqueda: textoBusqueda.value.isEmpty ? null : textoBusqueda.value,
      );
      recetas.assignAll(lista);
    } on ApiException catch (e) {
      hasError.value = true;
      errorMessage.value = e.mensaje;
      statusCodeError.value = e.statusCode ?? 0;
    } catch (e) {
      hasError.value = true;
      errorMessage.value = 'No se pudo conectar con el catálogo de recetas. Verifica tu conexión o el estado del backend.';
      statusCodeError.value = 500;
    } finally {
      isLoading.value = false;
    }
  }

  void cambiarCategoria(String nuevaCategoria) {
    if (categoriaSeleccionada.value == nuevaCategoria) return;
    categoriaSeleccionada.value = nuevaCategoria;
    cargarRecetas();
  }

  void buscar(String query) {
    textoBusqueda.value = query;
    cargarRecetas();
  }

  Future<bool> crearReceta(Receta receta) async {
    isLoading.value = true;
    hasError.value = false;
    try {
      final nueva = await _recetasService.crearReceta(receta);
      recetas.insert(0, nueva);
      return true;
    } on ApiException catch (e) {
      hasError.value = true;
      errorMessage.value = e.mensaje;
      statusCodeError.value = e.statusCode ?? 0;
      return false;
    } catch (e) {
      hasError.value = true;
      errorMessage.value = 'Error al crear receta remota.';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> eliminarReceta(String id) async {
    try {
      await _recetasService.eliminarReceta(id);
      recetas.removeWhere((r) => r.id == id);
      return true;
    } on ApiException catch (e) {
      hasError.value = true;
      errorMessage.value = e.mensaje;
      return false;
    } catch (_) {
      return false;
    }
  }
}
