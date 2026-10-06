# ExploraEC — prácticas CEDIA MOD3

Aplicación de formación en Flutter y Dart para las prácticas de widgets, tema, estados y accesibilidad del curso CEDIA MOD3.

## Versiones verificadas

| Práctica | Versión fija | Comprobación |
|---|---|---|
| Sesión 2: widgets básicos y avanzados | [19ff031](https://github.com/btoaldas/BtoCediaFlutter/tree/19ff031d586437d69fbc6350079e1cf51c0d3616) | 9 pruebas; lista/detalle/formulario/pestañas y hot reload/restart real |
| Sesión 3: tema, estados y accesibilidad | [78d2076](https://github.com/btoaldas/BtoCediaFlutter/tree/78d2076b7c9f03f5e64c209dc26f7054a86ffb77) | 17 pruebas; carga/vacío/error/reintento, lista/grilla y Semantics |
| Sesión 4: estado compartido con GetX | [5372f57](https://github.com/btoaldas/BtoCediaFlutter/tree/5372f57a7b4f0d5bec0008d5c1ec58510e450bf6) | 25 pruebas; instancia única, alta inmediata, contador, avisos, worker y concurrencia |
| Sesión 5: mapas y geolocalización | [d79f3b9](https://github.com/btoaldas/BtoCediaFlutter/tree/d79f3b94a8bada236060390318c64e83a03b5be3) | 36 pruebas; permisos Android reales, GPS emulado público, OSM, distancias y alta compartida |

Los informes y los ZIP de fuentes están organizados por práctica en `entregas/`.
Cada informe contiene un enlace clicable al commit exacto de su práctica.

Ambas prácticas fueron entregadas el 5 de octubre de 2026: Sesión 2 a las 19:58 y Sesión 3 a las 19:59. Moodle muestra «Enviado para calificar» y aún «Sin calificar»; los cuatro archivos descargados coinciden con sus originales por SHA-256.

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

Los lugares son ejemplos públicos en memoria. Sesión 5 incorpora el mapa; Favoritos continúa como pantalla provisional del curso.
Se verificó web sobre Edge, incluidos estados, formularios y controles accesibles, y Android API 36 ARM64 con Google Play Services. El GPS del emulador usa una coordenada pública de Quito. No se afirma teléfono físico ni prueba con TalkBack.

## Fuente académica

Basado en el material de [Patricio-CEDIA/exploraec-app](https://github.com/Patricio-CEDIA/exploraec-app), ramas `sesion-02` a `sesion-05`, y sus instructivos de práctica. Se conserva la atribución del curso.

## Sesión 4

La versión actual utiliza GetX 4.7.3. `PlacesController` comparte lista y estados entre pantallas; Inicio se actualiza mediante `Obx`. Guardar añade el lugar y actualiza el contador sin recargar. Se conservan el tema, los validadores, el detalle, las pestañas y el diseño adaptable.

[Explicación y requisitos](docs/practica-sesion04.md). Referencia del docente: rama `sesion-04`, commit `197a3d2df93b74b4ff706886f01d00c7f8275a0a`.

El ZIP de fuentes y el informe con enlaces a la versión fija se encuentran en `entregas/sesion04/`. Están preparados para la actividad 49406; la entrega en Moodle queda sujeta al visto bueno sobre los archivos exactos.

## Sesión 5

Mapa utiliza OpenStreetMap y observa la posición y la lista compartida. Los marcadores abren el detalle correspondiente con distancia en metros o kilómetros. Guardar un lugar actualiza Inicio y Mapa sin recargar. La aplicación normal usa Geolocator; la demostración web utiliza una coordenada pública de Quito.

[Explicación y requisitos](docs/practica-sesion05.md). Referencia docente: rama `sesion-05`, commit `39b5f23b50364181bccd001bcb1dcccfd4be221c`. Las 36 pruebas y las comprobaciones web y Android están aprobadas. Las capturas y los registros saneados están en `evidence/sesion05/`. El informe final de diez páginas y el ZIP de 58 fuentes están en `entregas/sesion05/`; el envío a la actividad 49411 espera el visto bueno de esos archivos exactos.

```bash
flutter run -d chrome -t lib/playground/mapa_demo_main.dart
```
