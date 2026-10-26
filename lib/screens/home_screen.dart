import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/recetas_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_view.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/receta_card.dart';
import 'asistente_screen.dart';
import 'favoritos_screen.dart';
import 'login_screen.dart';
import 'receta_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabActual = 0;
  final _busquedaController = TextEditingController();

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabActual,
        children: [
          _TabExplorar(busquedaController: _busquedaController),
          const FavoritosScreen(),
          const AsistenteScreen(),
          const _TabPerfil(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabActual,
        onDestinationSelected: (idx) => setState(() => _tabActual = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded, color: AppTheme.primary),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded, color: Colors.red),
            label: 'Favoritos',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_alt_outlined),
            selectedIcon: Icon(Icons.psychology_alt_rounded, color: AppTheme.primary),
            label: 'Chef IA',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppTheme.primary),
            label: 'Perfil',
          ),
        ],
      ),
      floatingActionButton: _tabActual == 0
          ? FloatingActionButton.extended(
              onPressed: () => Get.to(() => const RecetaFormScreen()),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva Receta'),
            )
          : null,
    );
  }
}

class _TabExplorar extends StatelessWidget {
  final TextEditingController busquedaController;

  const _TabExplorar({required this.busquedaController});

  @override
  Widget build(BuildContext context) {
    final recetasController = Get.find<RecetasController>();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.restaurant_menu_rounded, color: AppTheme.secondary),
            SizedBox(width: 8),
            Text('ChefCraft'),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(115),
          child: Column(
            children: [
              // Buscador de recetas
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: busquedaController,
                  onChanged: (q) => recetasController.buscar(q),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar por receta, ingrediente...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: busquedaController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              busquedaController.clear();
                              recetasController.buscar('');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // Selector horizontal de categorías
              SizedBox(
                height: 48,
                child: Obx(() {
                  final catActual = recetasController.categoriaSeleccionada.value;
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: recetasController.categorias.length,
                    itemBuilder: (context, index) {
                      final cat = recetasController.categorias[index];
                      final seleccionada = cat == catActual;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: seleccionada,
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            color: seleccionada ? Colors.white : AppTheme.dark,
                            fontWeight: seleccionada ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (_) => recetasController.cambiarCategoria(cat),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      body: Obx(() {
        if (recetasController.isLoading.value && recetasController.recetas.isEmpty) {
          return const LoadingView(mensaje: 'Cargando recetas del servidor...');
        }

        if (recetasController.hasError.value && recetasController.recetas.isEmpty) {
          return ErrorView(
            statusCode: recetasController.statusCodeError.value,
            mensaje: recetasController.errorMessage.value,
            onReintentar: () => recetasController.cargarRecetas(),
          );
        }

        if (recetasController.recetas.isEmpty) {
          return EmptyView(
            titulo: 'No se encontraron recetas',
            mensaje: 'Prueba cambiando la categoría seleccionada o borrando el término de búsqueda.',
            textoBoton: 'Ver todas las recetas',
            onAccion: () {
              busquedaController.clear();
              recetasController.textoBusqueda.value = '';
              recetasController.cambiarCategoria('Todas');
            },
          );
        }

        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () => recetasController.cargarRecetas(),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: recetasController.recetas.length,
            itemBuilder: (context, index) {
              final receta = recetasController.recetas[index];
              return RecetaCard(receta: receta);
            },
          ),
        );
      }),
    );
  }
}

class _TabPerfil extends StatelessWidget {
  const _TabPerfil();

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
      ),
      body: Obx(() {
        final usuario = authController.usuario.value;
        final estaAutenticado = authController.isAuthenticated;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.lg),
              CircleAvatar(
                radius: 46,
                backgroundColor: AppTheme.primary.withOpacity(0.12),
                child: Icon(
                  estaAutenticado ? Icons.person_rounded : Icons.person_outline_rounded,
                  size: 52,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                estaAutenticado ? usuario!.nombre : 'Usuario Invitado',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.dark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                estaAutenticado ? usuario!.email : 'Inicia sesión para desbloquear todas las funciones',
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Tarjeta de información técnica de la app
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      _FilaInfo(
                        icono: Icons.cloud_done_rounded,
                        titulo: 'Backend Propio',
                        valor: 'Node.js REST API',
                        color: Colors.green,
                      ),
                      const Divider(height: 24),
                      _FilaInfo(
                        icono: Icons.storage_rounded,
                        titulo: 'Persistencia Local',
                        valor: 'Hive Box (Offline)',
                        color: AppTheme.primary,
                      ),
                      const Divider(height: 24),
                      _FilaInfo(
                        icono: Icons.auto_awesome_rounded,
                        titulo: 'Asistente Inteligente',
                        valor: 'Servidor Privado IA',
                        color: AppTheme.secondary,
                      ),
                      const Divider(height: 24),
                      _FilaInfo(
                        icono: Icons.lock_outline_rounded,
                        titulo: 'Almacenamiento Token',
                        valor: 'Keychain / Keystore Seguro',
                        color: AppTheme.accent,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (estaAutenticado)
                ElevatedButton.icon(
                  onPressed: () => authController.logout(),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Cerrar Sesión'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => Get.to(() => const LoginScreen()),
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text('Iniciar Sesión o Registrarse'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _FilaInfo extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;
  final Color color;

  const _FilaInfo({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 22, color: color),
        const SizedBox(width: AppSpacing.md),
        Text(
          titulo,
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        const Spacer(),
        Text(
          valor,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.dark),
        ),
      ],
    );
  }
}
