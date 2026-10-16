# ExploraEC — prácticas CEDIA MOD3

Aplicación de formación en Flutter y Dart: widgets, accesibilidad, mapas, persistencia, autenticación segura, gastos y asistente del curso CEDIA MOD3.

## Versiones verificadas

| Práctica | Versión fija | Comprobación |
|---|---|---|
| Sesión 2: widgets básicos y avanzados | [19ff031](https://github.com/btoaldas/BtoCediaFlutter/tree/19ff031d586437d69fbc6350079e1cf51c0d3616) | 9 pruebas; lista/detalle/formulario/pestañas y hot reload/restart real |
| Sesión 3: tema, estados y accesibilidad | [78d2076](https://github.com/btoaldas/BtoCediaFlutter/tree/78d2076b7c9f03f5e64c209dc26f7054a86ffb77) | 17 pruebas; carga/vacío/error/reintento, lista/grilla y Semantics |
| Sesión 4: estado compartido con GetX | [5372f57](https://github.com/btoaldas/BtoCediaFlutter/tree/5372f57a7b4f0d5bec0008d5c1ec58510e450bf6) | 25 pruebas; instancia única, alta inmediata, contador, avisos, worker y concurrencia |
| Sesión 5: mapas y geolocalización | [d79f3b9](https://github.com/btoaldas/BtoCediaFlutter/tree/d79f3b94a8bada236060390318c64e83a03b5be3) | 36 pruebas; permisos Android reales, GPS emulado público, OSM, distancias y alta compartida |
| Sesión 6: gastos desde el backend | [0c35a2b](https://github.com/btoaldas/BtoCediaFlutter/tree/0c35a2b5a6e4e19b38b6443cc56363cd18716b7b) | 61 pruebas normales y 1 adicional; API/PostgreSQL reales, vacío/tres gastos, conexión, 401/422 y timeout autenticado 1 ms→15 s |

Los informes y los ZIP de fuentes están organizados por práctica en `entregas/`.
Cada informe contiene un enlace clicable al commit exacto de su práctica.

Ambas prácticas fueron entregadas el 5 de octubre de 2026: Sesión 2 a las 19:58 y Sesión 3 a las 19:59. Moodle muestra «Enviado para calificar» y aún «Sin calificar»; los cuatro archivos descargados coinciden con sus originales por SHA-256.

Sesiones 4 y 5 fueron entregadas el mismo día a las 21:33, tras aprobar sus archivos finales. Ambas muestran «Enviado para calificar» y «Sin calificar». Los cuatro archivos se descargaron y coinciden con los aprobados; el estado y sus nombres también se comprobaron en la interfaz del aula. Los registros están en `evidence/sesion04/verificacion-moodle-entrega.json` y `evidence/sesion05/verificacion-moodle-entrega.json`.

## Ejecutar y comprobar

Requiere Flutter. Validado con Flutter 3.47.6 y Dart 3.13.5 en web.

```bash
flutter pub get
flutter analyze
flutter test --reporter expanded --timeout 20s
dart run lib/playground/dart_basics.dart
flutter run -d chrome
```

Contador independiente:

```bash
flutter run -d chrome -t lib/playground/contador_demo_main.dart
```

En el contador, incrementar y pulsar `r` conserva el valor; `R` reinicia el estado.
En Sesión 3, el menú de práctica permite simular normal, vacío y error. Reintentar vuelve a cargar; el error continúa mientras siga seleccionado ese modo.
Lista bajo 600; cuadrícula de dos columnas desde 600 y tres desde 900.

## Alcance

Los lugares son ejemplos públicos en memoria. Sesión 5 incorpora el mapa; Sesión 7 añade favoritos persistentes y caché de gastos por usuario.
Se verificó web sobre Edge, incluidos estados, formularios y controles accesibles, y Android API 36 ARM64 con Google Play Services. El GPS del emulador usa una coordenada pública de Quito. No se afirma teléfono físico ni prueba con TalkBack.

## Fuente académica

Basado en el material de [Patricio-CEDIA/exploraec-app](https://github.com/Patricio-CEDIA/exploraec-app), ramas `sesion-02` a `sesion-09`, y sus instructivos de práctica. Se conserva la atribución del curso. Las referencias docentes consultadas no declaran licencia; no se les asigna una licencia inventada.

## Sesión 4

La versión actual utiliza GetX 4.7.3. `PlacesController` comparte lista y estados entre pantallas; Inicio se actualiza mediante `Obx`. Guardar añade el lugar y actualiza el contador sin recargar. Se conservan el tema, los validadores, el detalle, las pestañas y el diseño adaptable.

[Explicación y requisitos](docs/practica-sesion04.md). Referencia del docente: rama `sesion-04`, commit `197a3d2df93b74b4ff706886f01d00c7f8275a0a`.

El ZIP de fuentes y el informe con enlaces a la versión fija se encuentran en `entregas/sesion04/`. Se entregaron y verificaron en la actividad 49406.

## Sesión 5

Mapa utiliza OpenStreetMap y observa la posición y la lista compartida. Los marcadores abren el detalle correspondiente con distancia en metros o kilómetros. Guardar un lugar actualiza Inicio y Mapa sin recargar. La aplicación normal usa Geolocator; la demostración web utiliza una coordenada pública de Quito.

[Explicación y requisitos](docs/practica-sesion05.md). Referencia docente: rama `sesion-05`, commit `39b5f23b50364181bccd001bcb1dcccfd4be221c`. Las 36 pruebas y las comprobaciones web y Android están aprobadas. Las capturas y los registros saneados están en `evidence/sesion05/`. El informe final de diez páginas y el ZIP de 58 fuentes están en `entregas/sesion05/`; se entregaron y verificaron en la actividad 49411.

```bash
flutter run -d chrome -t lib/playground/mapa_demo_main.dart
```

## Sesión 6

Gastos añade registro, login mediante formulario y listado paginado contra el backend real del curso. El JWT permanece en memoria; `X-Total-Count` determina el total. Se conservan Inicio, Mapa y Favoritos, y se reutilizan carga, vacío, error y reintento.

[Explicación y requisitos](docs/practica-sesion06.md). Backend docente fijo: [480481e](https://github.com/cj-murillo/proyecto-curso-spec-kit/tree/480481ed87cedcfd7681da9ecacbcd80ac4ef08f). Validación:61 pruebas normales, una adicional de laboratorio, análisis y formato aprobados; flujo visible en Edge con API y PostgreSQL reales, errores de conexión/401/422 y timeout autenticado1ms→15s. Las fuentes Android contienen Internet y HTTP de desarrollo; esta sesión se ejecutó en web con un adaptador CORS local documentado. No se afirma ejecución Android S6.

El backend, sus accesos y el agrupador de soporte no se incluyen en Git ni en el ZIP.

Entregables finales: [ZIP de 71 fuentes](entregas/sesion06/exploraec-sesion06.zip) e [informe de diez páginas](entregas/sesion06/informe-practica-sesion06-entrega-v3.pdf). El informe enlaza el commit exacto. Tras aprobar ambos archivos, se entregaron en Moodle, actividad 49556, el 5 de octubre de 2026 a las 22:21. El aula muestra «Enviado para calificar» y «Sin calificar»; las dos descargas son idénticas a los originales por SHA-256. La interfaz confirmó nombres, fecha y estado. [Constancia saneada](evidence/sesion06/verificacion-moodle-entrega.json).

## Sesión 7

[Versión fija sesion-07](https://github.com/btoaldas/BtoCediaFlutter/tree/sesion-07). Persistencia con Hive: favoritos del dispositivo y caché privada de gastos por usuario, servidor primero, aviso offline con fecha, reintento y limpieza al salir/401. JWT solo en memoria. [Requisitos y explicación](docs/practica-sesion07.md). Verificación final: 89 pruebas, incluidos 10 casos docentes; análisis/formato correctos y E2E Edge con API/PostgreSQL reales. No hay escritura offline, cifrado ni login sin red; idioma opcional no implementado. Informe y ZIP en `entregas/sesion07/`.

Entrega S7 completada en CEDIA 49577 el 13 de octubre de 2026 a las 23:05: «Enviado para calificar», todavía «Sin calificar». PDF y ZIP descargados idénticos por SHA256; GitHub público y copias locales OneDrive también verificados. [Hito de cierre](docs/hitos/2026-10-13-sesion07-entregada.md).

## Sesión 8

Autenticación segura con Dio/AuthController y CRUD completo; 124 pruebas, quince docentes, E2E web y almacenamiento seguro real Android entre procesos. [Requisitos, resultados y límites](docs/practica-sesion08.md). [Versión fija sesion-08](https://github.com/btoaldas/BtoCediaFlutter/tree/sesion-08). PDF y ZIP entregados en CEDIA 49588 el 14 de octubre a las 00:28: Enviado para calificar, Sin calificar; ambas descargas idénticas por bytes y SHA256. [Constancia](entregas/sesion08/constancia-entrega-20261014.json).

## Sesión 9

Quinta pestaña Asistente, modo **REGLAS** explícito, resumen real por MCP y confirmación antes de crear gastos. [Integración y ejecución](docs/sesion09-integracion.md). 145 pruebas Flutter (22 docentes S8/S9), 38 Node, análisis/formato correctos y cadena real de cuatro eslabones aprobada. Edge comprueba consultas, cancelación sin POST, alta 201, rechazo 600, errores diferenciados y aislamiento A/B. La petición solo lleva consulta y resumen; no historial ni credenciales. [Evidencia saneada](evidence/sesion09/verificacion-funcional.json). PDFv3 y ZIP entregados en CEDIA 49613 el 14 de octubre a las 00:49: Enviado para calificar, Sin calificar. Ambas descargas idénticas por bytes y SHA256; publicación pública y copias locales OneDrive comprobadas. [Hito final](docs/hitos/2026-10-14-sesion09-entregada.md).


## Sesión 10 — calidad, CI/CD y código con agentes

La rama de trabajo S10 añade captura central de errores inesperados, una vista amistosa y filtro de Gastos por categoría con GetX. «Todas» restaura las tarjetas; filtrar conserva los datos originales, totales, caché y paginación. Las categorías proceden de las páginas cargadas.

Verificación independiente del 15 de octubre de 2026: **159 pruebas Flutter**, **14 controles S10 con LAB_PRUEBAS=true**, **38 pruebas Node**, análisis sin incidencias y formato correcto. La base anterior de 145 pruebas y los 38 casos Node se conservan; no se añadieron dependencias. [Comandos y resultados](docs/sesion10/verificacion.json), [decisiones y atribución](docs/sesion10/decisiones.md), [reglas propuestas y permisos](docs/sesion10/arneses.md).

Los controles que provocan fallos requieren modo debug y `--dart-define=LAB_PRUEBAS=true`. El registro conserva hasta 20 mensajes controlados sin serializar excepciones, trazas ni credenciales. Se utilizó asistencia de IA; el diff y las pruebas se revisaron de forma independiente.

**Estado de publicación:** PR y sus enlaces pendientes de registrar; CI remota, ejecución roja de control, Release/APK e instalación todavía requieren comprobación. El destino es el [repositorio académico existente](https://github.com/btoaldas/BtoCediaFlutter). [Manifiesto de publicación S10](docs/manifiestos/2026-10-15-sesion10-publicacion.md). La actividad CEDIA 49761 cierra el 21 de octubre de 2026 a las 00:00; la entrega prevista es el enlace al repositorio, cuando el recorrido de calidad y APK esté verificado.


### Cierre técnico comprobado el 15 de octubre de 2026

Esta actualización sustituye el estado preliminar de comprobaciones pendiente
descrito arriba. El [PR 1](https://github.com/btoaldas/BtoCediaFlutter/pull/1)
quedó integrado con CI verde. La prueba real de navegador encontró un error
asíncrono que escapaba de la zona de captura; se corrigió con runZonedGuarded en
el [PR 2](https://github.com/btoaldas/BtoCediaFlutter/pull/2), integrado en
[5d35375](https://github.com/btoaldas/BtoCediaFlutter/commit/5d35375fa0edd7a45a72ef36f9582e116fba39b9).
La [CI de la corrección](https://github.com/btoaldas/BtoCediaFlutter/actions/runs/38825354017)
y GitGuardian terminaron correctamente. La
[CI roja deliberada](https://github.com/btoaldas/BtoCediaFlutter/actions/runs/38823929127)
falló por una expectativa 3 frente a resultado 2; su rama se conserva sin integrar.

El [Release v1.0.1](https://github.com/btoaldas/BtoCediaFlutter/releases/tag/v1.0.1)
contiene el APK generado por
[Actions 38825739636](https://github.com/btoaldas/BtoCediaFlutter/actions/runs/38825739636).
La descarga coincide con el digest SHA-256 de GitHub. Se instaló como aplicación
nueva en Android 16 API 36 y se comprobó login y filtro Todas 9 → comida 3 → Todas 9,
repetido tras relanzar el proceso con sesión persistente. La versión interna del
APK sigue siendo 1.0.0+1 y la firma es Android Debug de laboratorio.

**Entrega académica confirmada:**
[CEDIA 49761](https://cursos.cedia.org.ec/mod/assign/view.php?id=49761) muestra
«Enviado para calificar» y «Sin calificar», con última modificación del 15 de
octubre de 2026 a las 19:31 de Ecuador. El texto en línea contiene el enlace
exacto `https://github.com/btoaldas/BtoCediaFlutter`; se verificó tras recargar.
La calificación docente sigue pendiente.
[Constancia saneada](evidence/sesion10/verificacion-moodle-entrega.json).
[Resultados, límites y enlaces de cierre](docs/sesion10/cierre.md),
[registro estructurado](docs/sesion10/cierre-publicacion.json) y
[evidencias con hashes](evidence/sesion10/manifiesto.json).
