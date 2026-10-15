# Reproducción local S10

Ejecutar desde la raíz del checkout, con Flutter 3.47.6 y Dart 3.13.5 en PATH,
PUB_CACHE del entorno de laboratorio, CI=true, FLUTTER_SUPPRESS_ANALYTICS=true
y DART_SUPPRESS_ANALYTICS=true. Las rutas del SDK son configuración local y no
se guardan aquí. No buscar ni instalar otro SDK automáticamente.

## Línea base previa a editar fuentes

```sh
git rev-parse HEAD
git status --short
flutter --version
flutter pub get --enforce-lockfile
flutter test --reporter expanded --no-pub
node --test mock-server/test/*.test.js
```

Medición local previa: Flutter 145/145 y Node 38/38; códigos 0. No son conteos
inferidos de un historial anterior. El estado inicial contenía un recurso local
del coordinador sin seguimiento que se preservó.

## Cambios y puerta local

```sh
dart format lib/main.dart lib/controllers/gastos_controller.dart lib/screens/gastos_screen.dart lib/utils/reporte_errores.dart lib/widgets/error_pantalla_view.dart test/filtro_gastos_test.dart test/sesion_10_test.dart test/helpers/sesion10_fake.dart
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter test --no-pub --reporter expanded --dart-define=LAB_PRUEBAS=true test/sesion_10_test.dart test/filtro_gastos_test.dart
flutter test --no-pub --reporter expanded --dart-define=LAB_PRUEBAS=true
node --test mock-server/test/*.test.js
dart format --output=none --set-exit-if-changed lib/main.dart lib/controllers/gastos_controller.dart lib/screens/gastos_screen.dart lib/utils/reporte_errores.dart lib/widgets/error_pantalla_view.dart test/filtro_gastos_test.dart test/sesion_10_test.dart test/helpers/sesion10_fake.dart
git diff --check
git diff --exit-code -- AGENTS.md CLAUDE.md mock-server pubspec.yaml pubspec.lock
git diff --name-status
git status --short --untracked-files=all
```

Comprobación de sintaxis de configuración (PyYAML ya disponible en este entorno;
si falta en otro, reportar pendiente sin instalar herramientas globales):

```sh
python3 -c "import json,pathlib,yaml; [yaml.load(p.read_text(),Loader=yaml.BaseLoader) for p in pathlib.Path('.github/workflows').glob('*.yml')]; json.loads(pathlib.Path('.claude/settings.json').read_text()); print('YAML/JSON válidos')"
```

Los resultados finales efectivos, intentos fallidos y límites figuran en
`verificacion.json`. Logs íntegros locales: `.tmp/sesion10-ejecutor/`; no son
entregables versionables. Las pruebas conservan los directorios Hive temporales.

## Revisión del coordinador

Repetir ambas variantes de pruebas. Leer el diff de archivos existentes y los
archivos nuevos (git diff por sí solo no muestra los no seguidos). Confirmar
ausencia de borrados, lock intacto y que solo se integran las rutas autorizadas.

Después de integrar y contar con la autoridad correspondiente: verificar CI
push/PR, rechazo ante una prueba realmente rota y su diagnóstico, Release con
APK, instalación y navegación en emulador. Las URLs del APK deben apuntar a sus
servicios de laboratorio; no se inició Docker ni un backend en esta construcción.
La comprobación de permisos del arnés se hace en la herramienta correspondiente;
no ejecutar una lectura de secretos para simularla.
