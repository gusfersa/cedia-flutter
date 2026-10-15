// Práctica CEDIA S10, referencia: Patricio-CEDIA/exploraec-app.
// Implementación adaptada con asistencia IA; no almacena excepciones ni trazas.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../widgets/error_pantalla_view.dart';

/// Captura solo fallos inesperados. Los errores de API siguen su flujo habitual.
class ReporteErrores {
  ReporteErrores._();

  static bool _instalado = false;
  static FlutterExceptionHandler? _flutterAnterior;
  static bool Function(Object, StackTrace)? _dispatcherAnterior;
  static ErrorWidgetBuilder? _widgetAnterior;
  static final _recientes = <String>[];
  static List<String> get recientes => List.unmodifiable(_recientes);

  /// Idempotente: una segunda instalación no encadena ni sustituye callbacks.
  /// Los callbacks anteriores se guardan únicamente para restaurarlos; no se
  /// reenvía el error crudo a presentError ni a un logger previo.
  static void instalar({
    void Function(String)? imprimir,
    VoidCallback? alErrorAsincrono,
    VoidCallback? salidaSegura,
  }) {
    if (_instalado) return;
    _flutterAnterior = FlutterError.onError;
    _dispatcherAnterior = PlatformDispatcher.instance.onError;
    _widgetAnterior = ErrorWidget.builder;
    _instalado = true;

    void registrar(Object error, String origen) {
      // Sanear antes de guardar y antes de entregar datos al logger.
      final linea = '[ExploraEC] error no controlado -> $origen: '
          '${limpiar(error)}';
      if (_recientes.length == 20) _recientes.removeAt(0);
      _recientes.add(linea);
      try {
        (imprimir ?? debugPrint)(linea);
      } catch (_) {
        // El propio destino de registro no debe generar un bucle de errores.
      }
    }

    FlutterError.onError = (detalles) {
      registrar(detalles.exception, 'widget');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      registrar(error, 'asincrono');
      try {
        alErrorAsincrono?.call();
      } catch (_) {
        // La captura no depende de que exista un ScaffoldMessenger activo.
      }
      return true;
    };
    ErrorWidget.builder = (_) => ErrorPantallaView(onVolver: salidaSegura);
  }

  /// Vocabulario cerrado: no llama a toString(), no conserva mensajes, rutas,
  /// cabeceras, JWT, claves ni valores arbitrarios. Es deliberadamente más
  /// conservador que una lista de expresiones regulares de secretos conocidos.
  static String limpiar(Object error) {
    if (error is RangeError) return 'Acceso fuera de rango.';
    if (error is FormatException) return 'Dato con formato no válido.';
    if (error is StateError) return 'Estado inesperado.';
    if (error is ArgumentError) return 'Argumento no válido.';
    return 'Fallo inesperado.';
  }

  /// Usar en tearDown, incluso si la prueba falla. No deja handlers instalados
  /// ni entradas de otra prueba; restaura también callbacks que eran null.
  static void restaurar() {
    if (!_instalado) return;
    FlutterError.onError = _flutterAnterior;
    PlatformDispatcher.instance.onError = _dispatcherAnterior;
    ErrorWidget.builder = _widgetAnterior!;
    _flutterAnterior = null;
    _dispatcherAnterior = null;
    _widgetAnterior = null;
    _recientes.clear();
    _instalado = false;
  }
}
