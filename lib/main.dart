import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'bindings/app_binding.dart';
import 'controllers/favoritos_controller.dart';
import 'screens/chefcraft_home_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/gastos_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'theme/app_theme.dart';
import 'utils/reporte_errores.dart';

final _mensajes = GlobalKey<ScaffoldMessengerState>();

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Instalación de manejadores de errores y fallbacks seguros
    ReporteErrores.instalar(
      alErrorAsincrono: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mensajes.currentState?.showSnackBar(const SnackBar(
            content: Text('Algo salió mal. Puedes intentarlo de nuevo.'),
          ));
        });
        WidgetsBinding.instance.scheduleFrame();
      },
      salidaSegura: () {
        final navegador = Get.key.currentState;
        if (navegador == null) return;
        if (navegador.canPop()) {
          navegador.pop();
        } else {
          Get.offAll(() => const ChefCraftHomeScreen());
        }
      },
    );

    // Inicialización de persistencia local: Hive para ChefCraft y ExploraEC
    await Hive.initFlutter();
    await Hive.openBox(FavoritosController.boxName);
    try {
      await Hive.openBox<Map>('favoritos');
    } catch (_) {}

    // La aplicación principal que compila en APK y ejecuta el usuario es ChefCraft
    runApp(const ChefCraftApp());
  }, (error, stack) {
    PlatformDispatcher.instance.onError?.call(error, stack);
  });
}

/// Aplicación principal del Proyecto Final de tema libre: ChefCraft
class ChefCraftApp extends StatelessWidget {
  const ChefCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'ChefCraft',
      scaffoldMessengerKey: _mensajes,
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.theme,
      initialBinding: AppBinding(),
      home: const ChefCraftHomeScreen(),
    );
  }
}

/// Fachada de compatibilidad para los arneses de pruebas automatizadas previas
class ExploraEcApp extends StatelessWidget {
  const ExploraEcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'ExploraEC',
      scaffoldMessengerKey: _mensajes,
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.theme,
      initialBinding: AppBinding(),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _indiceActual = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_indiceActual) {
        0 => const HomeScreen(),
        1 => const MapScreen(),
        2 => const FavoritesScreen(),
        _ => const GastosScreen(),
      },
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _indiceActual,
        onTap: (indice) => setState(() => _indiceActual = indice),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favoritos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Gastos',
          ),
        ],
      ),
    );
  }
}
