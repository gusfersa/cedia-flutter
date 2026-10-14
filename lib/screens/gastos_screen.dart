// Interfaz de la Sesión 6, adaptada del starter docente de ExploraEC.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../controllers/gastos_controller.dart';
import '../controllers/auth_controller.dart';
import '../services/api_exception.dart';
import '../widgets/sin_sesion_view.dart';
import 'gasto_form_screen.dart';
import '../config/api_config.dart';
import '../models/gasto.dart';
import '../controllers/places_controller.dart' show EstadoCarga;
import '../theme/app_theme.dart';
import '../widgets/empty_view.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';

class GastosScreen extends GetView<GastosController> {
  const GastosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Obx(() =>
        auth.estaAutenticado ? _buildGastos(context) : const SinSesionView());
  }

  Widget _buildGastos(BuildContext context) => Scaffold(
        appBar: AppBar(
          title:
              Obx(() => Text('Gastos (${controller.totalEnServidor.value})')),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recargar',
              onPressed: controller.cargarGastos,
            ),
            PopupMenuButton<String>(
              tooltip: 'Opciones de gastos',
              onSelected: (valor) {
                if (valor == 'salir') Get.find<AuthController>().cerrarSesion();
                if (valor == 'invalidar') {
                  controller.invalidarTokenParaPruebas();
                }
                if (valor == 'timeout-1') {
                  controller.configurarTimeoutParaPruebas(
                      const Duration(milliseconds: 1));
                  controller.cargarGastos();
                }
                if (valor == 'timeout-15') {
                  controller.configurarTimeoutParaPruebas(
                      const Duration(seconds: 15));
                  controller.cargarGastos();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'salir', child: Text('Cerrar sesión')),
                if (kDebugMode && ApiConfig.labPruebas)
                  PopupMenuItem(
                    value: 'invalidar',
                    child: Text('Invalidar token (solo práctica)'),
                  ),
                if (kDebugMode && ApiConfig.labPruebas)
                  PopupMenuItem(
                    value: 'timeout-1',
                    child: Text('Probar timeout de 1 ms'),
                  ),
                if (kDebugMode && ApiConfig.labPruebas)
                  PopupMenuItem(
                    value: 'timeout-15',
                    child: Text('Restaurar timeout de 15 s'),
                  ),
              ],
            ),
          ],
        ),
        floatingActionButton: Obx(() => FloatingActionButton(
              tooltip: 'Nuevo gasto',
              onPressed: controller.categorias.isEmpty
                  ? null
                  : () => Get.to(() => const GastoFormScreen()),
              child: const Icon(Icons.add),
            )),
        body: Obx(() {
          if (controller.estado.value == EstadoCarga.cargando) {
            return const LoadingView(mensaje: 'Cargando gastos...');
          }
          if (controller.estado.value == EstadoCarga.error) {
            return ErrorView(
              mensaje: controller.mensajeError.value,
              onReintentar: controller.iniciar,
            );
          }
          return Column(
            children: [
              if (controller.avisoSincronizacion.value.isNotEmpty)
                MaterialBanner(
                  content: Text(controller.avisoSincronizacion.value),
                  actions: [
                    TextButton(
                        onPressed: controller.cargarGastos,
                        child: const Text('Reintentar'))
                  ],
                )
              else if (controller.desdeCache.value)
                _bannerCache(context),
              Expanded(
                child: controller.gastos.isEmpty
                    ? const EmptyView(
                        mensaje: 'Aún no registras gastos en este viaje')
                    : _buildLista(controller.gastos.toList(), context),
              ),
            ],
          );
        }),
      );

  Widget _bannerCache(BuildContext context) => MaterialBanner(
        content: Text(
          'Sin conexión — mostrando tus gastos guardados '
          '(última sincronización: ${controller.ultimaSincronizacion})',
        ),
        leading: const Icon(Icons.cloud_off),
        actions: [
          TextButton(
            onPressed: controller.cargarGastos,
            child: const Text('Reintentar'),
          ),
        ],
      );

  Widget _buildLista(List<Gasto> gastos, BuildContext context) {
    final conBoton = controller.hayMas;
    final cargandoMas = controller.cargandoMas.value;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: gastos.length + (conBoton ? 1 : 0),
      itemBuilder: (context, indice) {
        if (indice == gastos.length) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: OutlinedButton(
              onPressed: cargandoMas ? null : controller.cargarMas,
              child: Text(cargandoMas ? 'Cargando...' : 'Cargar más'),
            ),
          );
        }
        final gasto = gastos[indice];
        return ListTile(
          key: ValueKey('gasto-${gasto.id}'),
          title: Text(gasto.descripcion),
          onTap: () => Get.to(() => GastoFormScreen(gasto: gasto)),
          subtitle: Text('${gasto.categoria} · ${gasto.fecha}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(gasto.monto.toStringAsFixed(2),
                style: Theme.of(context).textTheme.titleMedium),
            IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Eliminar',
                onPressed: () => confirmarEliminar(context, gasto)),
          ]),
        );
      },
    );
  }

  Future<void> confirmarEliminar(BuildContext context, Gasto gasto) async {
    final generacion = controller.auth.generacion;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text('¿Eliminar "${gasto.descripcion}"?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogo, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogo, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmado != true ||
        generacion != controller.auth.generacion ||
        !controller.auth.estaAutenticado) {
      return;
    }
    try {
      await controller.eliminar(gasto.id);
    } on ApiException catch (error) {
      if (generacion == controller.auth.generacion &&
          controller.auth.estaAutenticado) {
        Get.snackbar('No se pudo eliminar', error.mensaje);
      }
    }
  }
}
