# Manifiesto — publicación académica S10

Fecha: 15 de octubre de 2026. Estado: **preparado; publicación y entrega pendientes de evidencia**.

## Propósito, destino y autoridad

Completar y entregar la práctica de calidad, CI/CD y código con agentes del curso CEDIA MOD3. Se utiliza el repositorio público existente [btoaldas/BtoCediaFlutter](https://github.com/btoaldas/BtoCediaFlutter), dentro de la solicitud explícita de completar y entregar esta práctica. No se crea ni cambia la visibilidad de otro remoto. Las acciones externas corresponden al responsable de la publicación después de revisar las comprobaciones de este manifiesto.

Actividad: [CEDIA 49761](https://cursos.cedia.org.ec/mod/assign/view.php?id=49761). Cierre: 21-oct-2026, 00:00. La entrega prevista es **solo el enlace GitHub en texto en línea**; README, PR y Release/APK quedan accesibles en el repositorio.

## Cambio preparado y evidencia

Captura central de errores inesperados con registro controlado de 20 entradas; vista amistosa; filtro derivado por categoría; pruebas de widgets; workflows CI y Release APK; configuración neutral de permisos y documentación. Sin nuevas dependencias ni modificación del servidor S9.

Verificación independiente: 159 Flutter, 14 controles S10 con LAB_PRUEBAS=true, 38 Node, análisis sin incidencias, formato sin cambios y git diff --check correcto. Las fuentes integradas coinciden con las verificadas. [Conteos, comandos y huellas relativas](../sesion10/verificacion.json).

El constructor agotó su tiempo sin respuesta final. Se recuperaron y revisaron sus fuentes; este hecho se conserva en la evidencia y no se convierte en un éxito de proceso.

## Secuencia externa por comprobar

- [ ] Publicar la rama y crear PR hacia main; registrar URL y commit exactos.
- [ ] Comprobar CI verde de push y PR, incluyendo análisis, 159 Flutter y 38 Node.
- [ ] Ejecutar CI con una prueba intencionalmente rota en rama aislada; leer el fallo y conservar esa rama y evidencia. No integrar el cambio roto.
- [ ] Integrar el PR únicamente con la puerta de calidad en verde.
- [ ] Crear y publicar la etiqueta v1.0.0, previa comprobación de que el nombre está disponible.
- [ ] Comprobar que Actions analiza/prueba antes de compilar y publica el APK como artefacto y Release; registrar URL, commit y SHA-256.
- [ ] Descargar el APK del Release, instalarlo en emulador limpio, abrirlo, iniciar sesión y comprobar filtro/Todas y navegación; registrar resultados reales.
- [ ] Actualizar README y evidencia con los enlaces reales y estados comprobados.
- [ ] Entregar el enlace en CEDIA 49761 y verificar el estado visible.

## Límites y recuperación

PR, CI remota, etiqueta, Release, instalación y Moodle aún no constan completados en este manifiesto. No se inventan enlaces ni resultados. La configuración de permisos no se ha cargado en una sesión Claude para probar su efecto. No se modifica AGENTS/CLAUDE en esta adición documental.

La base 0204ba336eff948f1df2d86a15f4fd359b8ecd1a y el área aislada conservan las fuentes anteriores y el trabajo recuperado. Si falla una comprobación, se conserva su evidencia y se corrige en una nueva revisión; no se borran ramas, Releases, artefactos o instalaciones existentes ni se reescribe historia.

El Proyecto Final 49762 requiere un proyecto propio aparte y no forma parte de esta publicación S10.
