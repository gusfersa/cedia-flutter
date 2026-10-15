# Sesión 10: plan confirmado antes de implementar

Base revisada: `0204ba336eff948f1df2d86a15f4fd359b8ecd1a` (Sesión 9).
Ámbito: construcción aditiva local supervisada; el coordinador revisa e integra.
El único recurso previo sin seguimiento se conserva sin cambios.

## Cambios autorizados y rutas

1. `lib/utils/reporte_errores.dart`: instalar una vez los callbacks de Flutter,
   dispatcher y ErrorWidget; restaurarlos exactamente en pruebas. Conservar como
   máximo 20 mensajes de vocabulario controlado, sin texto crudo ni trazas.
2. `lib/widgets/error_pantalla_view.dart`: vista amistosa con salida segura.
   `lib/main.dart`: instalar antes de Hive, en la zona del binding; aviso genérico
   asíncrono y navegación de recuperación.
3. `lib/controllers/gastos_controller.dart`: selección reactiva y getters puros
   de categorías presentes y gastos filtrados. Validar selección después de cada
   actualización completa de lista; resetear en cambios/cierre de sesión.
   `lib/screens/gastos_screen.dart`: chips Todas/categorías, estado vacío y
   Cargar más accesible incluso sin coincidencias; controles de práctica
   condicionados por debug y LAB_PRUEBAS. Preservar menú y autenticación.
4. `test/helpers/sesion10_fake.dart`, `test/filtro_gastos_test.dart` y
   `test/sesion_10_test.dart`: backend falso con aislamiento por usuario,
   autenticación real de controladores, Hive temporal, efectos visibles,
   regresiones de caché/CRUD/paginación y restauración de handlers globales.
5. `.github/workflows/ci.yml`: push, PR y manual; Java 17, Flutter 3.47.6,
   dependencias bloqueadas, análisis y suites Flutter/Node, permisos de lectura.
   `.github/workflows/release-apk.yml`: tag v*, misma puerta, APK con URLs
   públicas por dart-define, artefacto y Release. Escritura solo en publicación.
6. `.claude/settings.json`: permisos de analizar/probar/diff, denegación de .env,
   publicación y etiquetas. `.gitignore`: añadir solo configuración local que
   falte. `docs/sesion10/`: decisiones, atribución, reglas propuestas, arneses,
   auditoría, checklist y `verificacion.json` con resultados efectivos.

No se prevén cambios en `pubspec.yaml` ni `pubspec.lock`: no hacen falta paquetes
nuevos. Se conservan AGENTS.md, CLAUDE.md, mock-server y pruebas anteriores.
No se ejecutan operaciones Git de escritura, GitHub, servidores ni Docker.

## Prueba de cierre

- Basal local previo: Flutter 145/145 y Node 38/38, ambos código 0.
  SDK 3.47.6 / Dart 3.13.5 comprobado; resolución bloqueada sin cambios.
- Formatear exclusivamente Dart modificado; análisis; pruebas S10; suite Flutter
  completa junto a handlers globales; suite Node completa.
- Segundo ángulo: pruebas de widget tocan chips y navegación, comparan IDs,
  suma/lista cruda y contenido Hive; cambian de usuario y prueban CRUD/caché.
- Registrar comandos, códigos y conteos reales en `verificacion.json`; logs
  completos únicamente en `.tmp/` local. No inventar capturas o permisos activos.
- Revisar diff íntegro, `git diff --check`, rutas permitidas y ausencia de
  borrados. CI remota, APK, emulador, publicación y entrega quedan pendientes
  para el coordinador después de integrar y obtener la autoridad necesaria.

## Recuperación

La base Git y el diff permiten revisar cada cambio. No se ejecuta ninguna
recuperación destructiva ni se borran recursos; la integración queda bajo control
del coordinador. No se modifica el contrato de errores esperados 400/401/red.
