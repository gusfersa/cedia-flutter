# Sesión 6 — gastos del viaje desde el backend

Actividad CEDIA MOD3: 49556. Apertura: 5 de octubre de 2026; cierre: 12 de octubre de 2026. El instructivo y las diapositivas tienen 39 páginas cada uno. Se preparan los pasos obligatorios0–9; el paso10, deslizar para actualizar, es opcional.

Frontend docente: `Patricio-CEDIA/exploraec-app`, rama `sesion-06`, commit `acaa1afb8fb362ae68525315fa35f22dacab04f0`. Backend docente: `cj-murillo/proyecto-curso-spec-kit`, commit `480481ed87cedcfd7681da9ecacbcd80ac4ef08f`. Se conserva la atribución académica.

## Flujo y estado

Gastos amplía ExploraEC con una cuarta pestaña. Registro envía JSON a `/usuarios/`; login envía formulario con `username` y `password` a `/usuarios/token`; listado utiliza `Authorization: Bearer` y parámetros `skip`/`limit`. Las operaciones se esperan en ese orden. Un usuario ya registrado puede volver a iniciar sesión; los demás errores de registro no se omiten.

El token vive únicamente en memoria. El controller conserva la lista ante un error de conexión y descarta respuestas tardías después de cerrar sesión. El total corresponde a `X-Total-Count`, con páginas de20 elementos. El401 al recargar con token inválido vuelve al formulario, lo vacía y explica que hay que iniciar sesión de nuevo. Un422 identifica los campos en español sin mostrar JSON crudo. El servicio centraliza las peticiones y su plazo normal de15 segundos.

## Laboratorio real

La comprobación funcional de esta sesión utiliza Edge y el backend docente real con PostgreSQL16 y las migraciones del curso, en Docker. Las cuentas y los gastos son datos sintéticos de laboratorio, sin información financiera personal. El backend corre en la interfaz local; sus accesos no forman parte del repositorio ni del ZIP.

El backend docente carece de CORS. Un wrapper ASGI local añade únicamente los orígenes del navegador de prueba y expone la cabecera `X-Total-Count`. Conserva el negocio, la autenticación JWT y la base de datos originales. Esta adaptación permite verificar las mismas peticiones desde web; no se atribuye al backend original y no se entrega junto al proyecto Flutter.

Las fuentes Android contienen el permiso Internet y permiten HTTP local de desarrollo, como pide el paso5. La dirección por defecto es `http://10.0.2.2:8000`. No se afirma ejecución nativa de Sesión6; la prueba Android de Sesión5 permanece documentada en su propia versión.

## Reproducir

Con el backend docente ya configurado y activo:

```bash
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter run
```

Para web, el backend requiere el adaptador CORS local descrito:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8802 --dart-define=API_BASE_URL=http://127.0.0.1:8000 --dart-define=LAB_PRUEBAS=true
```

Los controles de plazo adicionales se habilitan únicamente en depuración con `LAB_PRUEBAS=true`. Cambian el timeout de la misma instancia HTTP autenticada a1ms y lo devuelven a15s. El modo normal conserva15s. Este ajuste prueba la petición real y el estado de error sin perder la sesión por un reinicio del navegador.

## Verificación

Completada: 61 pruebas normales aprobadas, incluidas las36 regresiones anteriores y25 nuevas, más una prueba de laboratorio del plazo autenticado1ms→15s. Análisis sin problemas, formato de38 archivos sin cambios y `git diff --check` limpio. La revisión independiente del código fue APTO. El APK y las fuentes históricas de Sesión5 se conservaron.

En Edge, el usuario nuevo produjo registro201, login200 y listado200 con total0 en ese orden. Tras crear tres gastos por la API real, la app mostró total3 y los montos6.50,3.25 y4.00. La consulta SQL de PostgreSQL confirmó las mismas descripciones, categorías, montos y fechas. La fecha de los gastos es2026-10-06 porque el servidor utiliza UTC; la ejecución local corresponde a la noche del5 de octubre.

Se capturó el estado de carga con latencia controlada de1800ms y se restauró inmediatamente la red normal. La desconexión afectó únicamente la pestaña de prueba mediante CUA/CDP, produjo un error de red real y, tras restaurar la conexión, Reintentar recuperó los mismos tres gastos. El backend permaneció activo y la lista previa se conserva en el controller, comprobado también por pruebas automatizadas.

Con la sesión ya iniciada y sin latencia añadida, el plazo1ms produjo el mensaje de timeout; volver a15 segundos recuperó los mismos gastos sin reiniciar sesión. Una petición puede terminar en el servidor después de que venza el plazo del cliente: ese resultado tardío no cambia el estado ya observado. El modo final conserva15 segundos.

Invalidar el token y recargar obtuvo401, cerró la sesión y mostró campos vacíos con explicación. Entrar de nuevo obtuvo400 por usuario existente, luego login200 y los tres gastos. Un correo sintético nuevo con contraseña de tres caracteres obtuvo422 y mostró «Datos inválidos — contraseña: Debe tener al menos8 caracteres»; no se guardó ese usuario. Las capturas y los registros saneados están en `evidence/sesion06/`.

El entregable contiene exclusivamente el proyecto Flutter y su informe. No incluye el backend, `.env`, credenciales, cachés, binarios ni el agrupador de soporte. La entrega Moodle sigue pendiente de aprobación de los archivos exactos. No se afirma dispositivo físico, ejecución Android S6, iOS ni TalkBack; el paso10 opcional no se incorporó.
