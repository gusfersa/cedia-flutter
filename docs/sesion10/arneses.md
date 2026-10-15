# Reglas propuestas y equivalencia de arneses

AGENTS.md y CLAUDE.md se conservan. El coordinador puede agregar estas dos reglas
específicas después de revisarlas:

1. Las pruebas que instalen ReporteErrores deben restaurar FlutterError.onError,
   PlatformDispatcher.instance.onError y ErrorWidget.builder en finally antes
   de devolver el control al binding; añadir tearDown como respaldo. Nunca dejar
   un handler que oculte los errores del resto de la suite.
2. El filtro de Gastos solo deriva tarjetas de páginas cargadas; no modifica
   lista cruda, sumas, caché, total remoto ni skip. Validar la selección después
   de la actualización completa de RxList, nunca durante build, y mantener
   Cargar más accesible con cero coincidencias. Resetear al cambiar de sesión.

## Intención equivalente, configuración específica

| Capacidad | Claude Code | Codex | Otros agentes |
| --- | --- | --- | --- |
| Análisis, tests y diff | allow acotado en .claude/settings.json | instrucciones del proyecto y permisos de la sesión | permitir los mismos comandos locales |
| Leer .env o variantes | Read deny y denegación de shell con .env | restricción explícita del encargo y aislamiento revisado por el coordinador | bloquear archivos sensibles y revisar shell |
| Publicar o crear tags | deny para push, tag, Release, Actions y publicación de paquetes | fuera de autoridad del constructor | reservar al coordinador |
| Mutaciones de fuentes | solo las rutas del encargo | solo las rutas del encargo | mismo manifiesto de archivos |
| Evidencia | resultados reales, sin secretos | misma exigencia | misma exigencia |

El JSON compartido es neutral: no incluye cuentas, rutas locales, modelos,
credenciales ni configuraciones personales. La configuración local de Claude se
ignora en Git. Sintaxis según [permisos](https://code.claude.com/docs/en/permissions)
y [settings](https://code.claude.com/docs/en/settings) oficiales de Claude Code.
Las reglas de herramientas de archivo no limitan automáticamente cualquier
lector desde shell; un wrapper o una invocación alternativa también requiere
revisión. La configuración no se cargó en una sesión Claude para probar permisos.

OpenAI Docs distingue el sandbox de la política de aprobación: uno limita acceso
del proceso y la otra determina cuándo solicitar autorización. La lista de
comandos de Claude no se traslada automáticamente a Codex; el coordinador debe
comprobar la configuración efectiva en su entorno. No se cambió la configuración
local de Codex ni se afirma un sandbox activo de solo proyecto en este encargo.
Fuente: [Sandbox, documentación oficial](https://learn.chatgpt.com/docs/sandboxing).

En los demás arneses esta tabla expresa el contrato esperado; queda pendiente
validar los controles concretos de cada producto. Ningún permiso del arnés
sustituye la aceptación del diff o autoriza publicaciones por inferencia.
