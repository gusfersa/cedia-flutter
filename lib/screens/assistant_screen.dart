// Adaptado de Patricio-CEDIA/exploraec-app, sesión 09, pasos 4 y 5 activos.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/gastos_controller.dart';
import '../models/usuario.dart';
import '../services/ai_assistant_service.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _campo = TextEditingController();
  final _auth = Get.find<AuthController>();
  final _api = Get.find<ApiClient>();
  late final Worker _cambiosSesion;
  int _generacion = 0;
  bool _cargando = false;
  String? _respuesta;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cambiosSesion = ever(_auth.usuario, (_) {
      _generacion++;
      if (mounted) {
        setState(() {
          _respuesta = null;
          _error = null;
          _campo.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _generacion++;
    _cambiosSesion.dispose();
    _campo.dispose();
    super.dispose();
  }

  bool _vigente(int generacion, Usuario usuario, String token) =>
      mounted &&
      generacion == _generacion &&
      _auth.estaAutenticado &&
      identical(_auth.usuario.value, usuario) &&
      _api.token == token;

  Future<void> _preguntar() async {
    if (_cargando) return;
    final consulta = _campo.text.trim();
    final usuario = _auth.usuario.value;
    final token = _api.token;
    if (consulta.isEmpty || usuario == null || token == null || token.isEmpty) {
      return;
    }
    final generacion = _generacion;
    final servicio = Get.find<AiAssistantService>();
    setState(() {
      _cargando = true;
      _error = null;
      _respuesta = null;
    });
    try {
      await servicio.protegerSesion(
          token, () => _vigente(generacion, usuario, token), () async {
        final resumen = await Get.find<GastosController>().obtenerResumen();
        if (!_vigente(generacion, usuario, token)) return;
        final r = await servicio.preguntar(consulta, resumen);
        if (!_vigente(generacion, usuario, token)) return;
        setState(() => _respuesta = r.respuesta);
        if (r.accion != null) {
          await _confirmarAccion(r.accion!, generacion, usuario, token);
        }
      });
    } on ApiException catch (e) {
      if (_vigente(generacion, usuario, token)) {
        setState(() => _error = e.mensaje);
      }
    } on AsistenteException catch (e) {
      if (_vigente(generacion, usuario, token)) {
        setState(() => _error = e.mensaje);
      }
    } on FormatException {
      if (_vigente(generacion, usuario, token)) {
        setState(() =>
            _error = 'El backend devolvió un resumen de gastos inválido.');
      }
    } catch (_) {
      if (_vigente(generacion, usuario, token)) {
        setState(() =>
            _error = 'No se pudo completar la consulta. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _confirmarAccion(AccionPropuesta accion, int generacion,
      Usuario usuario, String token) async {
    if (!_vigente(generacion, usuario, token)) return;
    var decidido = false;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => Obx(() {
        // Leer Rx aun cuando la generación ya cambió, para que Obx siga
        // suscrito y retire la confirmación de la sesión anterior.
        final usuarioActual = _auth.usuario.value;
        final vigente =
            usuarioActual != null && _vigente(generacion, usuario, token);
        return AlertDialog(
          title: const Text('Confirmar acción'),
          content: Text(vigente
              ? 'El asistente en modo REGLAS propone registrar: ${accion.descripcion} — ${accion.monto.toStringAsFixed(2)} en ${accion.categoria}. ¿Confirmas?'
              : 'La sesión cambió. Cancela y vuelve a preguntar con tu sesión actual.'),
          actions: [
            TextButton(
                onPressed: () {
                  if (decidido) return;
                  decidido = true;
                  Navigator.pop(dialogo, false);
                },
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: !vigente
                    ? null
                    : () {
                        if (decidido || !_vigente(generacion, usuario, token)) {
                          return;
                        }
                        decidido = true;
                        Navigator.pop(dialogo, true);
                      },
                child: const Text('Registrar')),
          ],
        );
      }),
    );
    if (confirmado != true || !_vigente(generacion, usuario, token)) return;
    // crear() del contrato S8 recarga la lista/caché tras el POST. La zona
    // impide reusar el token nuevo incluso si cambia antes del interceptor.
    await Get.find<GastosController>()
        .crear(accion.descripcion, accion.monto, accion.categoria);
    if (!_vigente(generacion, usuario, token)) return;
    setState(() => _respuesta =
        'Listo: registré «${accion.descripcion}» por ${accion.monto.toStringAsFixed(2)} en ${accion.categoria}.');
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        if (!_auth.estaAutenticado) {
          return Scaffold(
            appBar: AppBar(title: const Text('Asistente')),
            body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Inicia sesión para consultar tus gastos.'),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                  onPressed: () => Get.to(() => const LoginScreen()),
                  child: const Text('Iniciar sesión')),
            ])),
          );
        }
        return _contenido(context);
      });

  Widget _contenido(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Asistente')),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
              color: colores.secondaryContainer,
              borderRadius: BorderRadius.circular(12)),
          child: const Text(
              'Modo REGLAS: respuestas deterministas, sin modelo de IA ni clave externa. Referencia académica «Sugerencia de IA»: verifica antes de decidir.'),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
            controller: _campo,
            maxLines: 2,
            maxLength: 500,
            enabled: !_cargando,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) {
              if (!_cargando) _preguntar();
            },
            decoration: const InputDecoration(
                labelText: 'Pregunta sobre tus gastos',
                border: OutlineInputBorder())),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
            onPressed: _cargando ? null : _preguntar,
            icon: _cargando
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chat_bubble_outline),
            label: const Text('Preguntar')),
        const SizedBox(height: AppSpacing.lg),
        if (_error != null)
          Text(_error!, style: TextStyle(color: colores.error))
        else if (_respuesta != null)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(_respuesta!)))
        else if (!_cargando)
          Text('Escribe una pregunta sobre tus gastos y toca «Preguntar».',
              style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
