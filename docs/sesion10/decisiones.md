# Decisiones y atribución S10

Práctica académica de ExploraEC, según el instructivo de la Sesión 10 facilitado
como contexto de solo lectura. Referencia docente:
[Patricio-CEDIA/exploraec-app, sesión 10](https://github.com/Patricio-CEDIA/exploraec-app/tree/sesion-10).
Se mantiene la base S9 del proyecto; no se copiaron directorios lib/test desde
el repositorio docente. La licencia upstream no se verificó en este encargo y
queda como comprobación previa a publicar derivados.

La construcción y las pruebas S10 se redactaron con asistencia de Codex a partir
del plan revisado. Esto no equivale a aceptación humana, integración, CI remota
verde, instalación de APK ni entrega académica.

## Captura de fallos inesperados

`ReporteErrores.instalar()` conserva los tres callbacks previos y los restaura
con `restaurar()`. Una segunda instalación no sustituye los originales ni duplica
registros. Los tests restauran en finally y tearDown para no ocultar fallos de
otras pruebas. No se encadena el logger anterior: podría imprimir la excepción
sin sanear.

Se prioriza minimización: `limpiar(Object)` clasifica con vocabulario cerrado y
no llama a `toString()`. El registro contiene origen y clase general del fallo;
no conserva objetos excepción, traza, cabeceras ni mensajes arbitrarios. Máximo
20 entradas, de solo lectura para consumidores. El coste es perder el detalle
técnico del mensaje original; es una decisión deliberada para esta práctica.

La vista de reserva no recibe datos de la excepción. En la app, su botón vuelve
a la ruta previa o reconstruye Inicio si no hay ruta anterior. El aviso asíncrono
es genérico y se programa después del frame. Los controles de práctica exigen
debug y `LAB_PRUEBAS=true`. La sesión se mantiene al volver de estos controles.

Las pruebas generan un Future sin catch y usan una zona puente al dispatcher:
el runner tiene su propia zona de errores. Esto prueba el callback instalado y
la interfaz, pero no sustituye provocar un error del motor en un dispositivo.

## Filtro y preservación de S9

La selección es un Rx nullable: null representa Todas. Categorías y tarjetas
son getters derivados de las páginas cargadas. Las categorías del formulario
siguen viniendo del servidor; no se usa esa lista para fabricar chips vacíos.

La selección se valida después de cada actualización completa de gastos y se
restablece al cambiar/cerrar sesión. `RxList.assignAll()` emite un vacío
intermedio: validar mediante ever descartaba indebidamente el filtro durante
recargas. Las pruebas de caché y paginación detectaron ese fallo y se conservaron.
Los getters no escriben Rx durante build.

El filtro no escribe Hive, no cambia suma, lista original, total remoto, skip,
tamaño de página ni CRUD. Se mantiene Cargar más con cero coincidencias y se
anuncia que el filtro se limita a las páginas cargadas.

## CI y APK

`ci.yml` es también workflow reutilizable: Release depende de la misma puerta
de análisis, Flutter y Node antes de compilar. Runner limpio, sin caché Flutter,
Java 17, Flutter 3.47.6 y Node 22.23.0 (la versión local medida). La resolución
respeta `pubspec.lock`; no se introducen dependencias ni actualizaciones
deliberadas.

Release tiene tres jobs: calidad, construir y publicar. Solo el último recibe
contents:write. Se conserva tanto el artefacto de Actions como el APK en un
Release. Se exige que la etiqueta remota ya exista (`--verify-tag`), según el
[manual de GitHub CLI](https://cli.github.com/manual/gh_release_create).
Una repetición no sobrescribe un Release ya existente.

El disparo manual solo compila/publica cuando la ref seleccionada es un tag v*;
en una rama ejecuta calidad y omite los dos jobs posteriores. El coordinador
decide cuándo crear tags y publicar.

`API_BASE_URL` y `LLM_BACKEND_URL` vienen de variables públicas de repositorio,
con valores de laboratorio para el emulador. Un dart-define acaba dentro del
binario: nunca incluir secretos. El Android existente firma release con la clave
de depuración del laboratorio; no se cambió ni se declara firma de tienda.
No se construyó ni instaló un APK en este encargo.

Fuentes de sintaxis consultadas: [checkout](https://github.com/actions/checkout),
[setup-java](https://github.com/actions/setup-java),
[setup-node](https://github.com/actions/setup-node),
[flutter-action](https://github.com/subosito/flutter-action),
[upload-artifact](https://github.com/actions/upload-artifact) y
[download-artifact](https://github.com/actions/download-artifact).
La lectura de documentación no prueba una ejecución de Actions.
