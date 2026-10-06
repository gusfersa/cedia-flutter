# Sesión 4 — estado compartido con GetX

Actividad CEDIA MOD3: 49406. Referencia académica: `Patricio-CEDIA/exploraec-app`, rama `sesion-04`, commit `197a3d2df93b74b4ff706886f01d00c7f8275a0a`.

## Por qué cambiar el estado local

En Sesión 3, Inicio administraba la solicitud y sus estados mediante `State`, `Future`, variables locales, `_cargar` y `setState`. El formulario modificaba los datos de ejemplo y devolvía un resultado; Inicio volvía a cargar al regresar. Otras pantallas no podían observar directamente ese estado local.

Sesión 4 concentra la lista y el estado de carga en una instancia de `PlacesController`. Las pantallas acceden a ella mediante GetX y observan los cambios sin repetir la solicitud después de guardar.

## Requisitos implementados

| Paso | Implementación |
|---|---|
| Controller | `RxList<Place> lugares`, `Rx<EstadoCarga> estado`, `RxString mensajeError`; `cargarLugares` usa la carga simulada con manejo de errores. |
| Instancia compartida | `PlacesBinding` registra una sola instancia. `GetMaterialApp` aplica el binding inicial y conserva el tema y configuración anteriores. |
| Inicio reactivo | `HomeScreen` usa `GetView<PlacesController>` y `Obx` para contenido y título. Carga, vacío, error y reintento siguen disponibles. |
| Formulario y navegación | `Get.find` obtiene el controller, `agregarLugar` modifica la lista y `Get.back` regresa sin recargar. Lista y detalle usan `Get.to`. |
| Estado derivado | `total` deriva de `lugares.length`; el título muestra `ExploraEC (6)` y cambia a `(7)` tras una sola alta. |
| Avisos y ciclo de vida | Aviso de alta y worker `ever` para error; el worker se registra en `onInit` y se libera en `onClose`. Se ignoran respuestas antiguas y posteriores al cierre. |

Las listas son copias para evitar duplicar un lugar por referencias compartidas. El formulario conserva validadores, impide doble guardado y espera el cierre de avisos anteriores antes de regresar y mostrar el nuevo aviso. Al agregar, se invalida cualquier carga pendiente para que una respuesta antigua no oculte el lugar recién guardado.

## Comprobación

```bash
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter run -d chrome
```

La verificación cubre la instancia única, el alta inmediata, el contador, la ausencia de nueva carga, el detalle, tres avisos en cola con doble pulsación, el worker de error, las cargas concurrentes y el cierre del controller. Se conserva la regresión de Sesiones 2 y 3: tema, espaciado, ocho anchos adaptables, validación y Semantics.

En Edge se comprobaron carga, vacío, error/reintento, formulario, alta, contador, aviso, detalle y pestañas. Las capturas se encuentran en `evidence/sesion04/`.

## Alcance

Verificado en web con Flutter 3.47.6, Dart 3.13.5 y Get 4.7.3. Los datos y errores son simulados según el curso. Mapa y Favoritos conservan sus pantallas provisionales. Favoritos reactivos e idioma del paso opcional 6 no se incorporan. No se afirma ejecución Android ni evaluación con TalkBack.

El informe PDF incluye enlaces a la versión exacta del código. La entrega en Moodle requiere el visto bueno sobre los archivos finales.
