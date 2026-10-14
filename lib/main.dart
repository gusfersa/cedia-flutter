// Práctica académica CEDIA MOD3, basada en Patricio-CEDIA/exploraec-app,
// sesiones 02–07. Lugares locales y JWT en memoria; Gastos usa una API REST
// con caché de Hive por usuario; los favoritos de lugares son persistentes.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'bindings/app_binding.dart';
import 'screens/favorites_screen.dart';
import 'screens/gastos_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // Hive necesita el motor de Flutter listo antes de pedir al sistema la
  // carpeta donde guardar sus archivos; por eso `main` es async.
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  // Solo la caja de favoritos: la de gastos depende de QUIÉN inicie sesión y
  // se abre después, en GastosRepository.abrirParaUsuario().
  await Hive.openBox<Map>('favoritos');
  runApp(const ExploraEcApp());
}

class ExploraEcApp extends StatelessWidget {
  const ExploraEcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'ExploraEC',
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
