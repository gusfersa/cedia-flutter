// Lista navegable de la práctica CEDIA MOD3, basada en ExploraEC sesion-02.
import 'package:flutter/material.dart';

import '../models/place.dart';
import '../widgets/place_card.dart';
import 'add_place_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();

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
    setState(() {});
    // Después del nuevo layout, mostrar el lugar añadido al final de la lista.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ExploraEC')),
      body: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 6, bottom: 80),
        itemCount: lugaresEjemplo.length,
        itemBuilder: (context, index) => PlaceCard(
          key: ValueKey(lugaresEjemplo[index].id),
          place: lugaresEjemplo[index],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormulario,
        tooltip: 'Agregar lugar',
        child: const Icon(Icons.add),
      ),
    );
  }
}
