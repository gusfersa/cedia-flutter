# Laboratorio nativo de sesión S8

Arnés para un APK **privado** de laboratorio, con `FlutterEngine` y plugins
reales, sin abrir una Activity ni usar mocks. Este directorio no modifica
`android/`, `lib/` o `pubspec.yaml`. El resultado de ejecución se registra en la evidencia de la práctica.

## Integración manual en una copia aislada

1. Partir de una **copia local nueva y completa** del proyecto S8 ya integrado,
   fuera de la app habitual. Deben existir `lib/controllers/auth_controller.dart`,
   `lib/services/api_client.dart` y `lib/services/secure_token_storage.dart`.
   Los TODO del instructivo de referencia no sirven como implementación.
2. Confirmar el contrato: `AuthController(api: ..., almacen: ...)`,
   `iniciarSesion`, `restaurarSesion`, `cerrarSesion`, `usuario.value.id`,
   `estaAutenticado`; `ApiClient(dio: ...)`, `token`, `generacionToken` que
   avanza al cambiar el token; `SecureTokenStorage(FlutterSecureStorage)` con
   `leer/guardar/borrar` serializados. El controlador y Dio no deben registrar
   credenciales, cuerpos HTTP ni cabeceras. El observador no altera HTTP.
3. En el Gradle **de la copia** conservar el namespace actual y aplicar
   `applicationIdSuffix = ".s08lab"` en `buildTypes.debug` al ID base
   `com.bto.exploraec`. El ID resuelto debe ser exactamente
   `com.bto.exploraec.s08lab`. No cambiar el ID de la aplicación existente.
   Usar `minSdk = 24` y Java/Kotlin 17. Si ya hay otro suffix, revisar el ID
   resultante antes de instalar.
4. Copiar `ServiciosInstrumentation.java` a
   `android/app/src/debug/java/com/bto/exploraec/s08lab/ServiciosInstrumentation.java`
   y fusionar `manifest-snippet.xml` con el manifiesto debug de esa copia.
   `instrumentation` es hijo de `manifest`, no de `application`.
   Si el merger detecta conflicto en `allowBackup`, resolverlo **en la copia**
   con `tools:replace="android:allowBackup"` y su namespace. Conservar el
   metadato `flutterEmbedding=2` y el registro automático de plugins.
5. Deben estar resueltas Dio y `flutter_secure_storage: 11.2.0`.
   El plugin local comprobado implementa `FlutterPlugin` con
   `getApplicationContext()`, sin `ActivityAware`. No necesita Activity para
   el almacenamiento estándar sin biometría. No registrar plugins dos veces.

## Compilar con configuración privada

El operador proporciona un JSON **privado y fuera del repositorio** con las
claves `username` y `password`, strings. Se transmite por entrada estándar hacia
`files/acceso-lab.json` del sandbox del nuevo paquete mediante `adb shell run-as`;
no se incorpora al APK. `API_BASE_URL` es un define público sin credenciales.
La URL admitida es `http://10.0.2.2:8000`, backend de pruebas del emulador.
La cuenta sintética ya debe existir: el arnés no crea usuarios ni carga secretos.
No incluir valores reales en comandos, Git, capturas, informes o logs.
No se genera ni escribe ese JSON desde este arnés.

Desde la copia, con `FLUTTER` apuntando al SDK:

```sh
flutter analyze tool/lab_secure_storage.dart
flutter build apk --debug -t tool/lab_secure_storage.dart --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Si `flutter` no está en PATH, usar la ruta del SDK local configurado.
Las credenciales permanecen en el sandbox de la app lab y fuera del APK.
El APK de instrumentación se conserva como artefacto local de prueba.
Confirmar ID, runner y permisos en el manifiesto fusionado/APK antes de instalar.
No compilar contra los stubs S8, ni contra el entrypoint normal `lib/main.dart`.

## Ejecución manual autorizada por el orquestador

Requiere emulador API 24+ disponible y backend de pruebas activo. Seleccionar
un serial explícito; no instalar ni usar dispositivos desde este encargo.
Antes de la primera instalación, comprobar que el ID lab aún no está instalado.
Si ya existe, detenerse y revisar su dueño y contenido. No usar fallback uninstall,
`pm clear` ni resets de Keystore. `adb install -r -t` está previsto para el nuevo
paquete, nunca para `com.bto.exploraec`.

```sh
adb -s "$SERIAL" shell pm path com.bto.exploraec.s08lab
adb -s "$SERIAL" install -r -t build/app/outputs/flutter-apk/app-debug.apk
adb -s "$SERIAL" shell am instrument -w -r -e fase guardar com.bto.exploraec.s08lab/com.bto.exploraec.s08lab.ServiciosInstrumentation > "$EVIDENCE/01-guardar.txt"
adb -s "$SERIAL" shell am instrument -w -r -e fase restaurar com.bto.exploraec.s08lab/com.bto.exploraec.s08lab.ServiciosInstrumentation > "$EVIDENCE/02-restaurar.txt"
adb -s "$SERIAL" shell am instrument -w -r -e fase cerrar com.bto.exploraec.s08lab/com.bto.exploraec.s08lab.ServiciosInstrumentation > "$EVIDENCE/03-cerrar.txt"
```

`EVIDENCE` debe ser una carpeta privada existente. Ejecutar los tres comandos
**por separado y en orden**, continuar solo si cada resultado pasa. Cada llamada
`am instrument` inicia una instrumentación independiente y `finish` termina su
proceso; no usar `am start`, gestos, `flutter run` ni relanzar la UI.
Para confirmar PIDs distintos de forma independiente, el operador puede observar
`adb -s "$SERIAL" shell pidof com.bto.exploraec.s08lab` durante cada fase desde
otra terminal; no hay un PID persistido usado para fingir la restauración.

## Criterio de aceptación y fallos

La salida `INSTRUMENTATION_RESULT: resultados=...` contiene JSON con **solo
booleanos**. Debe tener `ok=true`, `plugins_registrados=true`,
`sin_activity=true`, todas las comprobaciones de la fase en true y todos los
`error_*` en false. `INSTRUMENTATION_CODE: 0` significa éxito en este arnés;
`1`, fallo. El exit code del proceso adb por sí solo no demuestra éxito.

- `guardar`: exige token y marcador previamente ausentes; login real, respuesta
  200 de `/usuarios/me` con Bearer real, usuario autenticado y JWT leído del
  plugin igual al token en memoria. Captura el ID únicamente en almacenamiento
  seguro y comprueba su lectura. No lo incluye en resultados.
- `restaurar`: parte de memoria y usuario nulos en otro proceso; lee el JWT
  anterior, valida `/usuarios/me`, compara JWT persistido y usuario/ID tanto con
  el servidor como con el marcador del primer proceso.
- `cerrar`: demuestra primero la misma restauración válida y después invoca
  `cerrarSesion`; comprueba JWT en memoria, usuario y token seguro nulos.

No usa `Get.put` ni `onInit`: evita una segunda restauración automática.
Dispose cierra Dio y destruye el motor, **no hace logout**. El namespace
`cedia_s8_lab` usa `resetOnError:false`; nunca hay `deleteAll` ni limpieza de
almacenes existentes. Solo `cerrarSesion` borra el token de esta sesión lab.
El marcador se conserva después del cierre: una segunda fase `guardar` falla
para preservar evidencia. Otra campaña necesita aislamiento nuevo acordado,
sin borrar el anterior automáticamente.

Timeout nativo de 90 segundos incluso si main está bloqueado; errores reportados
por categoría fija, sin mensajes, stacks ni datos Dio. Java rechaza cualquier
payload con claves desconocidas o valores no booleanos. Los callbacks de Activity
miden si se creó/inició/reanudó alguna durante la instrumentación.

Además del caso positivo, probar fase inválida, backend inaccesible y un segundo
`guardar` con contenido previo: deben fallar. Revisar código del controlador y
logs privados del backend para verificar que ningún logger ajeno expone datos;
este arnés suprime prints Dart, pero no controla logs nativos de los plugins.

## Estado de verificación

SDK local leído: Flutter 3.47.6 / Dart 3.13.5. Interfaces de embedding y opciones
del plugin contrastadas con sus fuentes locales. `dart format` pasó el parser y
la segunda pasada no tuvo cambios. XML bien formado y claves Dart/Java coincidentes.
La clase Java pasó `JavaCompiler --release 17 -proc:none` contra `android.jar`
API 36 y el `flutter.jar` local, con salida de clases solo en memoria; esto no es
una compilación de APK ni una prueba de Keystore. La compilación integrada, el
análisis con S8 final y las tres fases nativas quedan a cargo del orquestador;
no hay una ejecución Android aprobada o simulada en este encargo.

## Resultado integrado — 14 de octubre de 2026

Las tres fases se ejecutaron en Android API36 ARM64 con plugins reales y tres procesos distintos. Guardar, restaurar mediante /usuarios/me y cerrar pasaron; el cierre dejó el JWT nulo y conservó el marcador. La prueba inicial detectó escritura aún pendiente al terminar una instrumentación sin Activity. El arnés ahora confirma físicamente la escritura con un commit vacío de SharedPreferences antes de finish; no cambia valores. Sin esa barrera no debe afirmarse persistencia por una lectura en memoria. Los controles negativos rechazan fase inválida y repetir guardar sobre el marcador existente. Evidencia saneada: ../../evidence/sesion08/almacenamiento-nativo.json. No acredita navegación visual Android ni cierre abrupto antes de completar escritura.
