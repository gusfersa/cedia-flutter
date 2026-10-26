import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'bindings/app_binding.dart';
import 'controllers/favoritos_controller.dart';
import 'screens/home_screen.dart';
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
          Get.offAll(() => const HomeScreen());
        }
      },
    );

    // Inicialización de Hive para persistencia local de recetas favoritas
    await Hive.initFlutter();
    await Hive.openBox(FavoritosController.boxName);

    runApp(const ChefCraftApp());
  }, (error, stack) {
    PlatformDispatcher.instance.onError?.call(error, stack);
  });
}

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
      home: const HomeScreen(),
    );
  }
}

// Aliases para compatibilidad con arneses de prueba existentes
typedef ExploraEcApp = ChefCraftApp;
typedef RootShell = HomeScreen;
