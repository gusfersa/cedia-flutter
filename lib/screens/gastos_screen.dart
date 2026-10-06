// Interfaz de la Sesión 6, adaptada del starter docente de ExploraEC.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../controllers/gastos_controller.dart';
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
  Widget build(BuildContext context) => Obx(() => controller.sesionActiva.value
      ? _buildGastos(context)
      : _FormularioEntrada(controller: controller));

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
                if (valor == 'salir') controller.salir();
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
        body: Obx(() {
          if (controller.estado.value == EstadoCarga.cargando) {
            return const LoadingView(mensaje: 'Cargando gastos...');
          }
          if (controller.estado.value == EstadoCarga.error) {
            return ErrorView(
              mensaje: controller.mensajeError.value,
              onReintentar: controller.cargarGastos,
            );
          }
          if (controller.gastos.isEmpty) {
            return const EmptyView(
                mensaje: 'Aún no registras gastos en este viaje');
          }
          return _buildLista(controller.gastos.toList(), context);
        }),
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
          subtitle: Text('${gasto.categoria} · ${gasto.fecha}'),
          trailing: Text(gasto.monto.toStringAsFixed(2),
              style: Theme.of(context).textTheme.titleMedium),
        );
      },
    );
  }
}

class _FormularioEntrada extends StatefulWidget {
  const _FormularioEntrada({required this.controller});
  final GastosController controller;

  @override
  State<_FormularioEntrada> createState() => _FormularioEntradaState();
}

class _FormularioEntradaState extends State<_FormularioEntrada> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Gastos')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Obx(() => ListView(
              children: [
                const Text('Entra para ver los gastos de tu viaje. '
                    'Si tu correo es nuevo, se crea la cuenta.'),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  key: const ValueKey('gastos-correo'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Correo'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('gastos-password'),
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Contraseña (8 a 72 caracteres)'),
                ),
                const SizedBox(height: AppSpacing.md),
                if (controller.mensajeAuth.value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(controller.mensajeAuth.value,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
                FilledButton(
                  onPressed: controller.autenticando.value
                      ? null
                      : () =>
                          controller.entrar(_email.text.trim(), _password.text),
                  child: controller.autenticando.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Entrar'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Servidor: ${controller.servidor}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            )),
      ),
    );
  }
}
