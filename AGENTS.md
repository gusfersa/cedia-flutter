# ChefCraft — Proyecto Final de Aplicación Móvil con Flutter e IA

Proyecto personal de tema libre para la entrega final del curso CEDIA MOD3 Flutter e IA.
Objetivo: construir una aplicación Flutter propia, completa y robusta sobre un dominio libre (recetario inteligente y nutrición), con arquitectura en capas, autenticación, datos remotos, persistencia local y asistente de IA consumido a través de servidor propio.

Tecnología: Flutter, Dart, GetX, Hive, Dio, Flutter Secure Storage y servidor propio en Node.js.

## Dominio y Características Principales

1. **Autenticación (15%):**
   - Registro, inicio y cierre de sesión con tokens JWT en el backend propio.
   - Resguardo de token en almacenamiento seguro (`FlutterSecureStorage`).
   - Bloqueo y protección de operaciones para usuarios no autenticados.

2. **Datos reales (15%):**
   - Catálogo de 18 recetas culinarias completas (ingredientes, preparación, valor nutricional y categorías) servidas desde el backend propio (`GET /api/recetas`).

3. **Persistencia remota y colaborativa (20%):**
   - CRUD de recetas: creación remota (`POST /api/recetas`) y eliminación (`DELETE /api/recetas/:id`) protegidas por token Bearer.
   - Filtrado en servidor por categoría y búsqueda textual.

4. **Persistencia local (10%):**
   - Módulo de recetas favoritas con almacenamiento local en caja de **Hive** (`recetas_favoritas`).
   - Las recetas guardadas sobreviven al cierre completo de la app y están disponibles sin conexión.

5. **Asistente de IA con servidor propio (10%):**
   - Endpoint `POST /api/ai/chat` consumido por la app.
   - Respuestas contextualizadas sobre ingredientes, recetas, porciones y sustituciones culinarias.
   - Cero claves de modelos en el cliente; variables de entorno en el servidor ignoradas por Git.

6. **Gestión de estado con GetX (10%):**
   - Controladores reactivos: `AuthController`, `RecetasController`, `FavoritosController`, `AsistenteController`.
   - Sin llamadas directas de la UI hacia HTTP ni uso disperso de `setState`.

7. **Manejo de errores y UX (10%):**
   - Estados visuales explícitos de Carga, Vacío y Error con botón de reintento.
   - Mensajes diferenciados para códigos HTTP 400, 401, 404, 422 y 500/red.

8. **Arquitectura y Calidad (10%):**
   - Separación estricta: Pantallas (`screens/`) → Controladores (`controllers/`) → Servicios (`services/`) → Cliente HTTP (`ApiClient`).
   - Suite de pruebas automatizadas en Dart y Node.js.
   - Flujo de GitHub Actions con CI y generación automática de APK en Releases.
