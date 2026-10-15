# Corrección del error asíncrono en web

El recorrido real del 15 de octubre detectó que el botón de error asíncrono enviaba una excepción cruda a la consola web y no mostraba el aviso amistoso. El manejador PlatformDispatcher instalado no recibió ese error en esta plataforma. La prueba negativa se conserva; no se atribuye el fallo observado a Android.

El arranque usa ahora runZonedGuarded, con inicialización del binding y runApp dentro de la misma zona. Su manejador reenvía al registro central existente, que omite mensajes y trazas crudos. Referencias primarias: [Dart runZonedGuarded](https://api.dart.dev/dart-async/runZonedGuarded.html) y [Flutter PlatformDispatcher.onError](https://api.flutter.dev/flutter/dart-ui/PlatformDispatcher/onError.html).

Análisis local sin incidencias y 159 pruebas Flutter verdes tras la corrección. La verificación del recorrido web, CI y APK de esta revisión se incorporará al cierre. La versión v1.0.0 se conserva; la corrección se publicará mediante una etiqueta nueva tras comprobarla.
