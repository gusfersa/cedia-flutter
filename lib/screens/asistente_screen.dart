import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/asistente_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/mensaje_chat.dart';
import '../theme/app_theme.dart';
import '../widgets/sin_sesion_view.dart';

class AsistenteScreen extends StatefulWidget {
  const AsistenteScreen({super.key});

  @override
  State<AsistenteScreen> createState() => _AsistenteScreenState();
}

class _AsistenteScreenState extends State<AsistenteScreen> {
  final _textoController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _enviar(AsistenteController controller) {
    final texto = _textoController.text.trim();
    if (texto.isEmpty) return;
    _textoController.clear();
    controller.enviarMensaje(texto);
    _scrollAlFinal();
  }

  void _scrollAlFinal() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.secondary,
              child: Icon(Icons.psychology_alt_rounded, size: 20, color: Colors.white),
            ),
            SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chef Inteligente IA', style: TextStyle(fontSize: 16)),
                Text(
                  'Servidor Propio ChefCraft',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reiniciar conversación',
            onPressed: () {
              final controller = Get.find<AsistenteController>();
              controller.limpiarHistorial();
            },
          ),
        ],
      ),
      body: Obx(() {
        if (!authController.isAuthenticated) {
          return const SinSesionView(
            accion: 'para consultar ideas y recomendaciones al Asistente Culinario con IA',
          );
        }

        final aiController = Get.find<AsistenteController>();

        return Column(
          children: [
            // Banner de seguridad sin claves en el cliente
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0x142EC4B6),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: AppTheme.accent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Asistente procesado en backend privado (sin credenciales expuestas en la app).',
                      style: TextStyle(fontSize: 11, color: Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
            ),
            // Lista de mensajes
            Expanded(
              child: Obx(() {
                final mensajes = aiController.mensajes;
                final pensando = aiController.isThinking.value;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: mensajes.length + (pensando ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == mensajes.length && pensando) {
                      return _BurbujaPensando();
                    }
                    final m = mensajes[index];
                    return _BurbujaMensaje(
                      mensaje: m,
                      onSugerenciaTap: (sugerencia) {
                        _textoController.text = sugerencia;
                        _enviar(aiController);
                      },
                    );
                  },
                );
              }),
            ),
            // Barra de entrada de texto
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0D000000),
                    offset: Offset(0, -2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textoController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _enviar(aiController),
                        decoration: InputDecoration(
                          hintText: 'Pregúntale al Chef IA...',
                          hintStyle: const TextStyle(fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: AppTheme.primary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Obx(() {
                      final pensando = aiController.isThinking.value;
                      return Material(
                        color: AppTheme.primary,
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: pensando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          onPressed: pensando ? null : () => _enviar(aiController),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _BurbujaMensaje extends StatelessWidget {
  final MensajeChat mensaje;
  final Function(String) onSugerenciaTap;

  const _BurbujaMensaje({required this.mensaje, required this.onSugerenciaTap});

  @override
  Widget build(BuildContext context) {
    final esUsuario = mensaje.esUsuario;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: esUsuario ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: esUsuario ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!esUsuario) ...[
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.primary,
                  child: Icon(Icons.restaurant_rounded, size: 16, color: Colors.white),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: esUsuario ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(esUsuario ? 16 : 4),
                      bottomRight: Radius.circular(esUsuario ? 4 : 16),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        offset: Offset(0, 1),
                        blurRadius: 3,
                      ),
                    ],
                    border: esUsuario ? null : Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    mensaje.texto,
                    style: TextStyle(
                      fontSize: 14,
                      color: esUsuario ? Colors.white : const Color(0xFF1E293B),
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!esUsuario && mensaje.sugerencias.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: mensaje.sugerencias.map((s) {
                  return ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    backgroundColor: const Color(0xFFF1F5F9),
                    onPressed: () => onSugerenciaTap(s),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BurbujaPensando extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.primary,
            child: Icon(Icons.restaurant_rounded, size: 16, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
                SizedBox(width: 8),
                Text(
                  'El Chef está preparando tu respuesta...',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
