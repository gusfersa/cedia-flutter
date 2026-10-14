# Práctica S7: persistencia local con Hive

Fecha: 2026-10-13. Aplicación académica ExploraEC, Sesión 7.

## Objetivo y fundamentos

La persistencia local permite conservar datos entre ejecuciones de la aplicación
y consultar una copia cuando el servidor deja de responder. Hive organiza esos
datos en cajas (`Box`) de pares clave–valor. Abrir, escribir, vaciar y cerrar
cajas son operaciones asíncronas que deben esperarse con `await`.

`main` inicializa el binding de Flutter, espera `Hive.initFlutter()` y abre la
caja de favoritos antes de montar la interfaz. Los modelos `Gasto` y `Place`
convierten sus datos a mapas de valores primitivos mediante `toMap/fromMap`;
esta práctica no necesita adapters generados. Los controllers mantienen el
estado reactivo que observa la interfaz con GetX.

## Arquitectura y módulos

| Módulo | Responsabilidad |
| --- | --- |
| `lib/main.dart` y `lib/bindings/` | Inicializar Hive, montar la aplicación y registrar dependencias |
| `lib/models/gasto.dart` y `lib/models/place.dart` | Representar gastos y lugares y serializarlos a mapas |
| `lib/services/gastos_api_service.dart` | Autenticación, perfil del usuario, consultas HTTP y JWT en memoria |
| `lib/repositories/gastos_repository.dart` | Consultar primero el servidor y gestionar la caché privada de Hive |
| `lib/controllers/gastos_controller.dart` | Coordinar sesión, recarga, paginación y estados de la pantalla |
| `lib/controllers/places_controller.dart` | Gestionar lugares y el espejo reactivo de favoritos persistentes |
| `lib/screens/gastos_screen.dart` y `lib/screens/favorites_screen.dart` | Mostrar gastos, aviso de caché, reintento y favoritos |
| `test/` | Verificar servicio, controllers, persistencia, carreras y widgets |

El repositorio separa las decisiones de almacenamiento de la presentación.
La pantalla de favoritos es un módulo propio; se conserva el placeholder
histórico de las prácticas anteriores.

## Caché de gastos por usuario

Después de autenticarse, la aplicación consulta `/usuarios/me` y abre
`gastos_<id>`. La caja almacena la lista, el total remoto y la fecha de última
sincronización en una sola escritura con `putAll`. Las páginas se acumulan
por ID: un gasto repetido actualiza su entrada sin duplicarla.

La recarga consulta primero el servidor. Solo un fallo de red, timeout o
respuesta 5xx permite usar la caché existente. Una lista guardada vacía también
es una copia válida. Sin copia se muestra el error. La interfaz indica que los
datos son guardados, muestra su fecha y ofrece Reintentar; una respuesta remota
correcta retira el aviso. No se piden nuevas páginas mientras se muestra caché.

Un 401 invalida la sesión y elimina su caché; los otros 4xx muestran el error
sin recurrir a datos guardados. Al cerrar sesión, gastos, total, JWT y aviso de
caché se invalidan en memoria antes de esperar la limpieza del almacenamiento.

### Limpieza portable y concurrencia

Las operaciones de apertura, escritura y limpieza se serializan en una cola.
Cada sesión reserva una generación y cada carga una versión; se comprueban
dentro de la cola para que respuestas antiguas no escriban en una sesión nueva.

La limpieza trabaja sobre la caja capturada, conserva su nombre y, si está
abierta, espera `clear()`, `flush()` y `close()`. Después solicita
`Hive.deleteBoxFromDisk(nombre)`. Cerrar primero libera la conexión IndexedDB
en web y evita que el borrado quede bloqueado. No se usa `Hive.boxExists` en
el código de ejecución ni se borra directamente una caja abierta con
`Box.deleteFromDisk`.

Si una apertura se cancela y esa operación abrió la caja, limpia, cierra y
borra su caché privada aunque hubiera datos previos en disco. Si la instancia
ya estaba abierta, la conserva. Las guardas de generación e identidad y la
cola evitan cerrar o borrar la caja de una sesión posterior.

## Favoritos y límites de la práctica

La caja `favoritos` pertenece al dispositivo y contiene decisiones sobre
lugares públicos. Sobrevive al cierre de sesión y al reinicio. Un lugar añadido
manualmente conserva todos sus campos si se marca como favorito; el catálogo
de Inicio sigue siendo un estado en memoria. Al desmarcarlo, el cambio también
se persiste.

El JWT permanece únicamente en memoria y no se guarda en Hive. Después de
reiniciar hace falta autenticarse con el servidor: no hay login sin conexión.
La caché de gastos es de lectura; no hay CRUD offline ni cola de sincronización
implementada. Hive no cifra los datos en esta práctica. La selección de idioma
del paso opcional no está implementada; la interfaz se mantiene en español.

## Respuesta de la práctica

Guardaría los últimos gastos por usuario y los favoritos del dispositivo; el JWT permanecería solo en memoria.
Crear gastos sin red requeriría una cola local separada de la caché, con estado pendiente de sincronización.
Cada pendiente tendría un ID provisional y una clave de idempotencia para enlazarlo con el ID aceptado por el servidor.
Un rechazo conservaría su motivo para corregirlo; ese diseño de CRUD offline no está implementado en esta sesión.

## Verificación reproducible

Comandos canónicos desde la raíz del proyecto, con Flutter y Dart en el PATH:

```sh
flutter pub get
dart format lib test
flutter analyze
flutter test
git diff --check
```

La preparación de esta verificación usó `flutter pub get --offline` con las
dependencias disponibles. El análisis y las pruebas usaron `--no-pub`;
`--reporter json` permitió contar resultados individuales. Los timeouts
externos fueron de 180 segundos para análisis y 300 segundos para la suite.

| Comprobación local | Resultado medido |
| --- | --- |
| Dependencias | Resolución correcta desde la caché |
| Formato | 40 archivos revisados, 0 cambios de formato |
| Análisis estático | 0 incidencias |
| Suite completa | 89 pruebas aprobadas en 9 suites, sin fallos ni timeout |

Las 89 pruebas incluyen 13 del servicio API y 32 del controller/repositorio de
gastos, con los diez casos docentes. Verifican aislamiento por usuario,
logout/401, respuestas tardías, escrituras ordenadas, caché offline y favoritos
reabiertos desde disco. La nueva prueba de limpieza exige que la caja se cierre
mientras el archivo todavía existe y comprueba su eliminación posterior por
Hive; al omitir el cierre de forma controlada, la prueba falla.

Los resultados y las comprobaciones adicionales se registran en
`evidence/sesion07/web-portable-final.json`. Los tests usan HTTP simulado y Hive real
en la VM; los widgets se verifican automáticamente. Las acciones que acceden
al disco se ejecutan con `tester.runAsync`, incluidas las aperturas del menú que
originan el callback de cierre de sesión.

La verificación complementaria en Edge utilizó la API y PostgreSQL reales del laboratorio. Se comprobaron tres favoritos tras recargar (incluido un lugar manual), Inicio con seis ejemplos, gastos A remotos y en caché al interrumpir la red de la pestaña, recuperación, logout y B con lista vacía, aviso para caché vacía, regreso a A y 401 con formulario vacío. Los favoritos sobreviven a logout y 401. El campo de contraseña se limpia al iniciar la petición y se cierra su edición; la credencial se usa solo como argumento transitorio. No se afirma ejecución funcional Android en esta sesión. Evidencia: `evidence/sesion07/e2e-web.json` y capturas.

## Referencia docente y asistencia

Referencia docente indicada: `Patricio-CEDIA/exploraec-app`, rama
`sesion-07`, commit `266d7330fc62eecffcb66789c2cb483cb01b0ece`.

La corrección y la documentación se prepararon con asistencia de IA.
Los resultados declarados corresponden a las comprobaciones ejecutadas sobre
esta versión de la práctica.
