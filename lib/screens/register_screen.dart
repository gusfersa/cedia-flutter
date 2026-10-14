// Basado en Patricio-CEDIA/exploraec-app, Sesión 8.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';
import '../utils/validadores.dart';

/// Registro de una cuenta nueva — Sesión 8. Si el servidor acepta el
/// registro, `AuthController` inicia la sesión solo.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final AuthController _auth = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _auth.mensajeError.value = '';
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    final password = _password.text;
    _password.clear();
    FocusScope.of(context).unfocus();
    final pendiente = _auth.registrar(_email.text.trim(), password);
    final generacion = _auth.generacion;
    await pendiente;
    if (mounted &&
        _auth.generacion == generacion &&
        _auth.estaAutenticado &&
        ModalRoute.of(context)?.isCurrent == true) {
      Get.until((ruta) => ruta.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                key: const ValueKey('gastos-correo'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Correo', border: OutlineInputBorder()),
                validator: Validadores.correo,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey('gastos-password'),
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Contraseña (8 a 72 caracteres)',
                    border: OutlineInputBorder()),
                validator: Validadores.password,
              ),
              const SizedBox(height: AppSpacing.md),
              Obx(() => _auth.mensajeError.value.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(_auth.mensajeError.value,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    )),
              Obx(() => FilledButton(
                    onPressed: _auth.cargando.value ? null : _enviar,
                    child: _auth.cargando.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Crear cuenta'),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
