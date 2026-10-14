# Sesión 8 — Autenticación segura y CRUD completo

Referencia: Patricio-CEDIA/exploraec-app, sesion-08, e66f6a3baafa5450edaca1aa74469fc5a82550fa, e instructivo de CEDIA 49588. Se conserva la atribución y la licencia no especificada.

## Implementación

ApiClient usa Dio e interceptores de token y 401 vinculados a la generación original. AuthController maneja registro, formulario OAuth2 de login, /me, restauración, errores legibles y cierre. El JWT va a flutter_secure_storage, nunca a Hive. Se conserva una fachada y adaptador HTTP para regresiones S6/S7; la app usa el cliente Dio compartido.

Gastos conserva la caché privada y la paginación real de veinte. Las categorías vienen del servidor; crear usa POST, editar PATCH solo con cambios y eliminar DELETE con confirmación. Las mutaciones confirmadas no se presentan como fallidas si únicamente falla la recarga posterior. Logout y 401 limpian memoria, almacenamiento seguro y caja privada; disponer controladores conserva la sesión persistente. Favoritos mantiene su caja independiente.

## Comprobación

124 pruebas correctas, incluidos los quince casos docentes, análisis sin observaciones. El punto de partida docente tenía 0/15 correctas. Se conservaron las regresiones y se añadieron carreras entre sesiones/controladores, almacenamiento y CRUD. Dos pruebas específicas detectan colas privadas o pérdida del contexto async. Navegación real Edge+API+PostgreSQL: registro, contraseña corta, error de login y correo repetido, cinco gastos, monto 6.50→7.00, cancelación de borrado, límite 500, caché offline, guardado sin red y reintento 201, restauración, 401, logout y favoritos tras reinicio. DELETE 204 se comprobó sobre un único gasto temporal propio y la lógica del controller con tests.

Android API36 ARM64: instrumentación de servicios sin Activity, plugin real 11.2.0 y app lab de ID distinto. Tres procesos prueban guardado, restauración validada por /me y borrado del JWT. El arnés confirma escritura física antes de terminar. No afirma recorrido visual Android, iOS ni dispositivo físico. Ver evidence/sesion08 y tool/android.

## Respuestas del instructivo

1. Otro teléfono no ve la copia de Hive de este dispositivo; puede obtener los gastos del servidor al autenticarse como el mismo usuario.
2. El servidor separa y autoriza los datos mediante el JWT; las cajas por usuario complementan esa separación en la caché local.
3. El token es una credencial y Hive lo guardaría sin cifrar; se utiliza el almacenamiento seguro del sistema.

## Reproducir

```sh
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Backend docente separado y sano, con CORS local para GET/POST/PATCH/DELETE. Para Android usar API_BASE_URL=http://10.0.2.2:8000. Credenciales y datos privados quedan fuera de fuentes y entregables. Cambio de contraseña opcional no implementado. Se utilizó asistencia de IA para interpretar la consigna, preparar código/documentación y apoyar verificaciones; solo se informan resultados medidos.
