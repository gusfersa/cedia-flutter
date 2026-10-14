// Basado en Patricio-CEDIA/exploraec-app, Sesión 8.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/api_config.dart';
import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';
import 'register_screen.dart';

/// Inicio de sesión — Sesión 8. Muestra el error del servidor debajo del
/// formulario y deshabilita el botón mientras `cargando` es verdadero.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
    final pendiente = _auth.iniciarSesion(_email.text.trim(), password);
    final generacion = _auth.generacion;
    await pendiente;
    // Con sesión abierta, se vuelve a la pantalla de Gastos.
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
      appBar: AppBar(title: const Text('Iniciar sesión')),
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
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Escribe tu correo'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey('gastos-password'),
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Contraseña', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Escribe tu contraseña' : null,
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
                        : const Text('Entrar'),
                  )),
              TextButton(
                onPressed: () => Get.to(() => const RegisterScreen()),
                child: const Text('Crear una cuenta'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Servidor: ${ApiConfig.baseUrl}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
