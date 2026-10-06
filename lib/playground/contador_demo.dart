// Práctica CEDIA MOD3; referencia: ExploraEC sesion-02.
import 'package:flutter/material.dart';

class ContadorDemo extends StatefulWidget {
  const ContadorDemo({super.key});

  @override
  State<ContadorDemo> createState() => _ContadorDemoState();
}

class _ContadorDemoState extends State<ContadorDemo> {
  int _veces = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('initState: el contador arrancó en $_veces');
  }

  @override
  void dispose() {
    debugPrint('dispose: el contador se cierra en $_veces');
    super.dispose();
  }

  void _incrementar() {
    setState(() {
      _veces++;
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('build: reconstruyendo con _veces = $_veces');
    return Scaffold(
      appBar: AppBar(title: const Text('ContadorDemo — práctica Sesión 2')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('_veces'),
            Text(
              '$_veces',
              key: const ValueKey('valor-contador'),
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementar,
        tooltip: 'Incrementar',
        child: const Icon(Icons.add),
      ),
    );
  }
}
