import 'package:get/get.dart';

import '../models/mensaje_chat.dart';
import '../services/ai_assistant_service.dart';
import '../services/api_exception.dart';

class AsistenteController extends GetxController {
  final AiAssistantService _aiService;

  AsistenteController({AiAssistantService? aiService})
      : _aiService = aiService ?? AiAssistantService();

  final RxList<MensajeChat> mensajes = <MensajeChat>[].obs;
  final RxBool isThinking = false.obs;
  final RxString errorMessage = ''.obs;
  final RxInt statusCodeError = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _iniciarMensajeBienvenida();
  }

  void _iniciarMensajeBienvenida() {
    if (mensajes.isEmpty) {
      mensajes.add(
        MensajeChat.delAsistente(
          '¡Hola! Soy tu Chef Inteligente de ChefCraft 👨‍🍳.\n\n'
          'Puedo ayudarte con ideas para cocinar según tus ingredientes, '
          'sugerirte opciones de desayuno, almuerzo o cena, o darte tips '
          'de sustitución de ingredientes.\n\n'
          '¿Qué te gustaría preparar hoy?',
          sugerencias: [
            '¿Qué cocino con camarones y cebolla?',
            'Recomiéndame una cena ligera y saludable',
            '¿Cómo puedo sustituir el huevo en una receta?',
            'Opciones de desayuno con avena y plátano',
          ],
        ),
      );
    }
  }

  Future<void> enviarMensaje(String texto) async {
    final consulta = texto.trim();
    if (consulta.isEmpty) return;

    errorMessage.value = '';
    statusCodeError.value = 0;

    // Agregar mensaje del usuario
    mensajes.add(MensajeChat.delUsuario(consulta));
    isThinking.value = true;

    try {
      final respuesta = await _aiService.consultarAsistente(consulta);
      final textoRespuesta = respuesta['respuesta']?.toString() ??
          'Disculpa, no pude procesar la respuesta culinaria.';
      final sugerenciasRaw = respuesta['sugerencias'];
      final sugerencias = (sugerenciasRaw is List)
          ? sugerenciasRaw.map((e) => e.toString()).toList()
          : <String>[];

      mensajes.add(MensajeChat.delAsistente(textoRespuesta, sugerencias: sugerencias));
    } on ApiException catch (e) {
      statusCodeError.value = e.statusCode ?? 0;
      errorMessage.value = e.mensaje;
      mensajes.add(
        MensajeChat.delAsistente(
          '⚠️ ${e.mensaje}',
        ),
      );
    } catch (_) {
      statusCodeError.value = 500;
      errorMessage.value = 'No se pudo conectar con el servidor de IA.';
      mensajes.add(
        MensajeChat.delAsistente(
          '⚠️ No se pudo comunicar con el servidor propio de IA. Por favor verifica que el backend esté ejecutándose en el puerto configurado.',
        ),
      );
    } finally {
      isThinking.value = false;
    }
  }

  void limpiarHistorial() {
    mensajes.clear();
    _iniciarMensajeBienvenida();
  }
}
