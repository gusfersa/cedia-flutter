# Sesión 5 — mapas y geolocalización

Actividad CEDIA MOD3: 49411. Referencia académica: `Patricio-CEDIA/exploraec-app`, rama `sesion-05`, commit `39b5f23b50364181bccd001bcb1dcccfd4be221c`.

## Flujo implementado

`PlacesController` conserva el estado compartido de Sesión 4 y añade posición, carga y error de localización. El servicio comprueba que la ubicación esté activa, consulta el permiso, lo solicita cuando corresponde y distingue denegación de bloqueo permanente. La aplicación normal utiliza Geolocator con precisión alta.

Mapa observa la posición y una copia de la lista reactiva mediante `Obx`. OpenStreetMap proporciona las teselas, con atribución visible y sin API key. Hay un marcador de posición y uno por lugar. Cada botón abre el detalle del lugar y transmite su distancia calculada desde la posición disponible. El detalle muestra metros o kilómetros con unidades coherentes.

Guardar conserva el flujo validado de Sesión 4: añade una vez al controller sin recargar. El contador de Inicio y los marcadores del mapa usan la misma lista. Las coordenadas del alta son las coordenadas de demostración indicadas por el código docente; pueden coincidir con Parque La Carolina.

## Requisitos y comprobaciones

| Requisito | Implementación y prueba |
|---|---|
| Conservar estado compartido | Regresión de Sesiones 2, 3 y 4; altas sin recarga y respuesta pendiente invalidada. |
| Dependencias del curso | Geolocator 13.0.4, permission_handler 11.4.0, flutter_map 7.0.2 y latlong2 0.9.1; Get 4.7.3. |
| Permisos Android | Manifest principal con FINE, COARSE e Internet; identidad `com.bto.exploraec`. |
| Sensor y errores | Servicio activo, permiso concedido/solicitado/denegado/bloqueado, precisión alta, carga, error y reintento. |
| Mapa y marcadores | Teselas reales OSM, atribución, posición y seis lugares. Botones estándar con identidad estable, toque, acción accesible y teclado. |
| Detalle y distancias | Café Galletti a 0 m y Parque El Ejido a 1,5 km desde la coordenada pública de prueba; se verifica correspondencia del lugar. |
| Alta compartida | Inicio cambia de seis a siete; el mapa muestra siete lugares y el detalle del nuevo lugar abre desde su marcador. |

## Cómo reproducir

```bash
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter run
```

Para la demostración web determinista con la coordenada pública de Café Galletti:

```bash
flutter run -d chrome -t lib/playground/mapa_demo_main.dart
```

Ese entrypoint es una demostración académica con sensor inyectado; no obtiene la ubicación privada del usuario. `lib/main.dart` mantiene el servicio real. La demostración permite verificar mapa, dos distancias y lista compartida sin confundirla con una prueba nativa de permisos.

## Estado de validación

Código web: 36 pruebas aprobadas, análisis sin problemas y formato verificado. En Edge se comprobó la carga real de teselas, seis marcadores, dos detalles/distancias, activación accesible por teclado y clic, alta a siete y su aparición inmediata en el mapa. Un desfase de los marcadores accesibles se corrigió sustituyendo el control manual por `IconButton`.

Android: APK de `lib/main.dart` compilado e instalado en Android API 36 ARM64 con Google Play Services. Se verificaron diálogo nativo, denegación, reintento y permiso preciso durante el uso. Geolocator obtuvo la coordenada pública de Quito del GPS del emulador; el mapa cargó teselas reales. Café Galletti mostró 0 m y El Ejido 1,5 km. Añadir Quito Android cambió Inicio de seis a siete y añadió su marcador sin recargar; tocarlo abrió su detalle correcto.

El APK de depuración tiene 81.773.922 bytes y SHA-256 `e7e202ffb1e798c92dc9a8cf71b526e129aa8a3ec5d9a1cc84ecf2c5ab1fd5e4`. No se incluye el binario en Git; Flutter reproduce la compilación a partir de las fuentes Android. El entorno aislado utilizó únicamente las dos licencias aceptadas expresamente por el estudiante. La interacción ADB en el emulador también fue autorizada expresamente.

No se afirma GPS de teléfono físico, TalkBack ni ejecución iOS. Los opcionales del paso 7 —centrado y distancia en tarjetas— no se incorporan.

## Numeración del instructivo

0. Recapitulación de Sesión 4 y necesidad de compartir el estado.
1. Verificar el punto de partida y conservar las regresiones.
2. Dependencias y permisos nativos.
3. Permiso en tiempo real y posición actual.
4. Mapa real con marcadores.
5. Distancia en el Detalle.
6. El mismo controller alimenta Inicio y Mapa.
