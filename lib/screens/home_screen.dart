// Lista navegable de la práctica CEDIA MOD3, basada en ExploraEC sesion-02.
import 'package:flutter/material.dart';

import '../models/place.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_view.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/place_card.dart';
import 'add_place_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  late Future<List<Place>> _futuroLugares;
  bool _modoDebugError = false;
  bool _modoDebugVacio = false;
  bool _mostrarUltimoAlCargar = false;

  @override
  void initState() {
    super.initState();
    _futuroLugares = fetchLugaresSimulado();
  }

  void _cargar() {
    setState(() {
      _futuroLugares = fetchLugaresSimulado(
        forzarError: _modoDebugError,
        forzarVacio: _modoDebugVacio,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _abrirFormulario() async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AddPlaceScreen()),
    );
    if (!mounted || guardado != true) return;
    _modoDebugError = false;
    _modoDebugVacio = false;
    _mostrarUltimoAlCargar = true;
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ExploraEC'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Simular estado (solo práctica)',
            onSelected: (valor) {
              _modoDebugError = valor == 'error';
              _modoDebugVacio = valor == 'vacio';
              _cargar();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'normal', child: Text('Simular: normal')),
              PopupMenuItem(value: 'vacio', child: Text('Simular: vacío')),
              PopupMenuItem(value: 'error', child: Text('Simular: error')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<Place>>(
        future: _futuroLugares,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(mensaje: 'Buscando lugares cercanos...');
          }
          if (snapshot.hasError) {
            return ErrorView(
              mensaje: '${snapshot.error}',
              onReintentar: _cargar,
            );
          }
          final lugares = snapshot.data ?? [];
          if (lugares.isEmpty) {
            return const EmptyView(mensaje: 'Todavía no hay lugares guardados');
          }
          return _buildLista(lugares);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormulario,
        tooltip: 'Agregar lugar',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLista(List<Place> lugares) {
    if (_mostrarUltimoAlCargar) {
      _mostrarUltimoAlCargar = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 80),
            itemCount: lugares.length,
            itemBuilder: (context, index) => PlaceCard(
              key: ValueKey(lugares[index].id),
              place: lugares[index],
            ),
          );
        }
        final columnas = constraints.maxWidth < 900 ? 2 : 3;
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            80,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnas,
            childAspectRatio: 2.2,
          ),
          itemCount: lugares.length,
          itemBuilder: (context, index) => PlaceCard(
            key: ValueKey(lugares[index].id),
            place: lugares[index],
          ),
        );
      },
    );
  }
}
