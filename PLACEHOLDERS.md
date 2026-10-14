# Práctica de la Sesión 5 — mapas y geolocalización

El código de los pasos obligatorios 0–6 conecta `LocationService`,
`PlacesController`, `MapScreen` y el Detalle. El servicio usa las API reales de
Geolocator: consulta el servicio, comprueba o solicita el permiso y obtiene la
posición con precisión `high`. Distingue permiso denegado, bloqueo permanente
y servicio apagado. La posición y los lugares se comparten mediante GetX.

Mapa usa OpenStreetMap sin API key, atribución visible y el identificador
`com.bto.exploraec`. Dibuja un marcador de posición y uno por lugar; tocar un
lugar abre su detalle con la distancia calculada. El alta actualiza Inicio y
Mapa sin recargar lugares. Android declara `ACCESS_FINE_LOCATION`,
`ACCESS_COARSE_LOCATION` e `INTERNET` en el manifest principal.

Se conservan el tema, los estados, la validación, la accesibilidad y el diseño
responsivo anteriores. Los datos permanecen en memoria. La prueba nativa pasó
en Android API 36 ARM64 con Google Play Services: diálogo real, denegación,
reintento, concesión, posición obtenida por Geolocator, mapa, dos distancias y
alta compartida. El GPS del emulador se fijó a una coordenada pública de Quito;
no se afirma prueba en teléfono físico. Evidencia en `evidence/sesion05/`.

`lib/playground/mapa_demo_main.dart` es una demostración académica independiente:
inyecta la coordenada pública de Café Galletti, `-0.1938, -78.4869`, para verificar
mapa y distancias sin consultar la ubicación privada del usuario. No representa
una lectura del GPS. `lib/main.dart` conserva el servicio real.

El paso 7 (centrar el mapa y distancias en Inicio) es opcional y queda fuera.
Favoritos conserva su pantalla provisional. La pantalla provisional de Mapa
de la Sesión 2 se preserva en su archivo histórico y ya no se usa en la navegación.

Referencia académica: `Patricio-CEDIA/exploraec-app`, rama `sesion-05`,
commit `39b5f23b50364181bccd001bcb1dcccfd4be221c`.

## Avance de la Sesión 7 — Hive

El avance S7 añade cache privada de gastos por usuario, respaldo offline,
banner de sincronización y favoritos persistentes. La navegación ahora usa
`FavoritesScreen`, situada en `lib/screens/favorites_screen.dart`; la clase
provisional sigue conservada en `lib/screens/favorites_placeholder_screen.dart`.
`GastosRepository` está en `lib/repositories/gastos_repository.dart`, importado
y reexportado por `lib/controllers/gastos_controller.dart`.

Logout y 401 invalidan sesión/cargas, vacían la vista y esperan borrar solo la
caja de gastos de esa operación. Favoritos permanece en su caja independiente.
Los tests montan Hive explícitamente, incluyendo cerrar/reabrir desde disco.
La demo pública del mapa también inicializa Hive antes de crear PlacesController.
No se implementa idioma persistente ni escritura de gastos sin red.

Requisitos, respuestas de privacidad/offline, adaptación de los diez casos
docentes y verificación final: `docs/practica-sesion07.md`.
Evidencia final: `evidence/sesion07/web-portable-final.json` y `evidence/sesion07/e2e-web.json`.

Separación de módulos y fixture 401: `evidence/sesion07/modulos.json`.
