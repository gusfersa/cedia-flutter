# Práctica de la Sesión 4 — estado compartido con GetX

Los pasos obligatorios 0–5 del instructivo están implementados. Inicio usa
`GetView<PlacesController>` y `Obx`; el binding registra una única instancia;
guardar un lugar actualiza la lista y el contador sin volver a cargar datos.
La navegación usa `Get.to` y `Get.back`. El aviso de error se crea con `ever`
en `onInit` y su suscripción se libera en `onClose`.

Se conservan el tema, los estados, la validación, la accesibilidad y el diseño
responsivo de las prácticas anteriores. Los datos permanecen en memoria.

El paso 6 (favoritos e idioma) es opcional y queda fuera de esta entrega.
Mapa y Favoritos conservan las pantallas provisionales de la Sesión 2.

Referencia académica: `Patricio-CEDIA/exploraec-app`, rama `sesion-04`.
