// Práctica académica CEDIA MOD3, basada en Patricio-CEDIA/exploraec-app,
// sesiones 02–10. Lugares locales y JWT en almacenamiento seguro; Gastos usa una API REST
// con caché de Hive por usuario; los favoritos de lugares son persistentes.
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'bindings/app_binding.dart';
import 'screens/assistant_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/gastos_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'theme/app_theme.dart';
import 'utils/reporte_errores.dart';

final _mensajes = GlobalKey<ScaffoldMessengerState>();

void main() {
  // Inicialización y runApp comparten zona; cubre también los errores web.
  runZonedGuarded(() async {
    // Hive necesita el motor de Flutter listo antes de pedir al sistema la
    // carpeta donde guardar sus archivos durante el arranque asíncrono.
    WidgetsFlutterBinding.ensureInitialized();
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
          Get.offAll(() => const RootShell());
        }
      },
    );
    await Hive.initFlutter();
    // Solo la caja de favoritos: la de gastos depende de QUIÉN inicie sesión y
    // se abre después, en GastosRepository.abrirParaUsuario().
    await Hive.openBox<Map>('favoritos');
    runApp(const ExploraEcApp());
  }, (error, stack) {
    PlatformDispatcher.instance.onError?.call(error, stack);
  });
}

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
        3 => const GastosScreen(),
        _ => const AssistantScreen(),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Asistente',
          ),
        ],
      ),
    );
  }
}
