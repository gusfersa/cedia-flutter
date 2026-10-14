# Sesión 9 — integración del asistente ExploraIA

Adaptación académica de Patricio-CEDIA/exploraec-app, rama sesion-09, commit df58f68b847a6b1e7a68335ea9fdb6f7eca646cb, con asistencia de IA para construcción y revisión. La referencia no incluye licencia explícita; se conserva su atribución y no se concede una licencia adicional.

## Funcionamiento

La quinta pestaña consulta GET /gastos/resumen mediante el mismo ApiClient y AuthController que Gastos. El controller verifica que la sesión original siga vigente antes de devolver los datos. AiAssistantService se registra una sola vez después de los servicios de autenticación y gastos.

El proxy funciona exclusivamente en modo **REGLAS**, permitido por el instructivo y declarado en pantalla. No llama a Gemini, Ollama ni a otro proveedor de modelos. Recupera el resumen real mediante la herramienta MCP de lectura resumen_gastos; no confía en los números recibidos del cliente. Un fallo MCP produce un error y no utiliza datos alternativos.

El cuerpo contiene únicamente consulta y resumen por categoría, sin historial, fechas, correo ni token. El token viaja en Authorization. Los logs registran bytes, nombres fijos de campos, número de categorías y origen; nunca credenciales o contenido de la consulta.

## Sesión y confirmación

AssistantScreen y AiAssistantService capturan usuario, token y generación. Los interceptores del ApiClient compartido rechazan peticiones y respuestas obsoletas. El guard de errores se ejecuta antes del interceptor S8 de 401, para impedir que una respuesta antigua cierre una sesión nueva.

Una propuesta no crea gastos automáticamente. Cancelar no genera POST; confirmar usa GastosController.crear y su recarga protegida. Busy abarca consulta, diálogo, POST y recarga. Si un POST ya salió al cerrar sesión, puede completarse para el usuario original; su resultado no se publica bajo una sesión nueva.

Se validan tipo, descripción, categoría y monto finito positivo. La cota técnica permite 600 para observar el rechazo real del backend por el límite 500. Los errores del backend y del proxy se muestran por separado.

## Ejecución

Requisitos: Flutter compatible con pubspec.yaml, Node 18+ y backend académico con MCP. Backend en 8000, proxy en **3801**; ambos en laboratorio local. El proxy enlaza únicamente 127.0.0.1. Los orígenes CORS se limitan a localhost/127.0.0.1 en 8802 y 8803.

```sh
node mock-server/mock-server.js
node --test mock-server/test/*.test.js
flutter test --reporter expanded
flutter analyze
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8803 --dart-define=API_BASE_URL=http://127.0.0.1:8000 --dart-define=LLM_BACKEND_URL=http://127.0.0.1:3801
```

Android usa http://10.0.2.2:3801 para alcanzar el host. Véase [el contrato del proxy](../mock-server/README.md) para autenticación, límites y prueba de cuatro eslabones. La prueba E2E recibe credenciales privadas por entorno o archivo; nunca por argumentos.

Las pruebas Dart conservan los siete casos docentes S9 y añaden catorce casos de validación, errores, confirmación, recarga y carreras entre sesiones. Las 38 pruebas Node cubren MCP JSON/SSE, sustitución de un resumen falso, cero escrituras del proxy, autenticación, CORS, límites y privacidad. La evidencia final distingue estas pruebas de la navegación y la cadena MCP reales.
