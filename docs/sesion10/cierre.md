# Cierre técnico de la sesión 10

Verificación del 15 de octubre de 2026. La implementación, las pruebas, la
integración en GitHub y el APK de Actions están comprobados. **La práctica quedó
enviada en CEDIA 49761 a las 19:31 de Ecuador**, mediante el enlace exacto al
repositorio. La consulta posterior a la recarga confirmó «Enviado para calificar»
y «Sin calificar». La calificación docente permanece pendiente.

## Código e integración

- [Repositorio](https://github.com/btoaldas/BtoCediaFlutter).
- Implementación S10: [84cd7c4](https://github.com/btoaldas/BtoCediaFlutter/commit/84cd7c4a49f92f9ea0002262e65f0908925f7b63).
- [PR 1](https://github.com/btoaldas/BtoCediaFlutter/pull/1), integrado el
  15 de octubre a las 18:32:17 de Ecuador, commit
  [ee4ebd7](https://github.com/btoaldas/BtoCediaFlutter/commit/ee4ebd7f335ec37065cb4001e5ad0c944a53d888).
- La comprobación web encontró un fallo real: el Future sin catch escapaba a la
  zona de errores y llegaba crudo a consola. Se corrigió con runZonedGuarded;
  la repetición mostró el aviso amistoso, el registro controlado y cero errores
  crudos. [PR 2](https://github.com/btoaldas/BtoCediaFlutter/pull/2), integrado
  a las 18:48:05 de Ecuador, commit
  [5d35375](https://github.com/btoaldas/BtoCediaFlutter/commit/5d35375fa0edd7a45a72ef36f9582e116fba39b9).

## Calidad y control de fallos

Se verificaron 159 pruebas Flutter, 14 controles S10 ejecutados también con
LAB_PRUEBAS=true, 38 pruebas Node, análisis sin incidencias y resolución respetando
pubspec.lock. Los 14 controles son una pasada adicional de casos S10; no se suman
como casos nuevos al total de 159.

La [CI de la rama](https://github.com/btoaldas/BtoCediaFlutter/actions/runs/38822740020)
y la [CI del PR 1](https://github.com/btoaldas/BtoCediaFlutter/actions/runs/38822780126)
terminaron correctamente. Después de corregir el fallo web, también quedaron en
verde la [CI de corrección por push](https://github.com/btoaldas/BtoCediaFlutter/actions/runs/38825349016)
y la [CI del PR 2](https://github.com/btoaldas/BtoCediaFlutter/actions/runs/38825354017).

La [ejecución roja deliberada](https://github.com/btoaldas/BtoCediaFlutter/actions/runs/38823929127)
mostró 159 pruebas correctas y una falla intencional: esperaba 3 y obtuvo 2. La
rama `prueba/ci-rojo-s10-20261015` se conserva separada y nunca se integró. Este
resultado demuestra que una expectativa incorrecta bloquea la puerta de calidad.

GitGuardian detectó en PR 1 una cadena del adaptador de pruebas en memoria.
El caso 38262660 se clasificó como falso positivo; la comprobación 116723117178
quedó SKIPPED para ese caso, sin desactivar el escáner. La comprobación de PR 2
terminó SUCCESS. La configuración de permisos de Claude fue revisada como
archivo, pero no se cargó en una sesión de Claude para probar su eficacia.

## APK publicado y probado

El [Release v1.0.1](https://github.com/btoaldas/BtoCediaFlutter/releases/tag/v1.0.1)
procede de la [ejecución de Actions 38825739636](https://github.com/btoaldas/BtoCediaFlutter/actions/runs/38825739636),
terminada correctamente sobre 5d35375. Su
[APK descargable](https://github.com/btoaldas/BtoCediaFlutter/releases/download/v1.0.1/app-release.apk)
tiene 55 780 417 bytes; el SHA-256 local coincide con el digest del asset de
GitHub:

```text
f70c3ec7b131f0645888357ad721eea0868ef63ae10380f70fb06922372671c3
```

La etiqueta de entrega es **v1.0.1** y la versión interna del APK sigue siendo
**1.0.0+1**. El paquete es `com.bto.exploraec` y usa firma Android Debug para el
laboratorio; no se declara firma de tienda. El APK se distribuye como asset del
Release y no se copia al repositorio.

Se instaló como aplicación nueva en un emulador Android 16 API 36 ARM64. El
recorrido real fue login, Todas con 9 tarjetas, comida con 3 y regreso a Todas
con 9. Se repitió después de relanzar el proceso; la sesión persistió y el filtro
volvió a dar 9, 3 y 9. El total remoto se mantuvo en 9 y no se crearon, editaron
ni eliminaron gastos. El menú de release solo mostró Cerrar sesión, sin controles
para provocar errores de práctica.

Una captura inicial tras tocar comida mostró la pestaña Asistente. La causa no
se determinó; no se reprodujo al repetir con el nodo exacto y el árbol UI actual.
Las dos pasadas posteriores comprobaron el filtro. Se conserva el incidente en
la evidencia local; no se presenta aquella captura como filtro correcto.

Las pruebas de errores de pantalla y asíncrono se hicieron en web de depuración.
El APK se comprobó en emulador, no en un teléfono físico, y requiere el backend
del laboratorio disponible.

## Actividades del aula

La [práctica 10](https://cursos.cedia.org.ec/mod/assign/view.php?id=49761)
se entregó mediante texto en línea con la dirección exacta
`https://github.com/btoaldas/BtoCediaFlutter`. El estado de la actividad se
comprobó tras recargar: «Enviado para calificar», «Sin calificar» y última
modificación del jueves 15 de octubre de 2026 a las 19:31, zona
America/Guayaquil. El primer guardado había sido bloqueado; el envío posterior
con texto simple quedó confirmado. La pantalla del bloqueo no se usa como
constancia. El recibo público saneado está en
[verificacion-moodle-entrega.json](../../evidence/sesion10/verificacion-moodle-entrega.json);
la captura real se conserva en el informe final y en la evidencia local privada.

El [examen final](https://cursos.cedia.org.ec/mod/quiz/view.php?id=49763) ya fue
enviado y obtuvo 15 de 15 respuestas correctas, equivalentes a 10 de 10. Ese
cuestionario es independiente del proyecto final, actividad 49762, y no tiene
un repositorio de GitHub de examen inventado.

## Evidencia revisable

[Resumen estructurado del cierre](cierre-publicacion.json) y
[manifiesto de archivos y hashes](../../evidence/sesion10/manifiesto.json).
Las capturas publicables muestran únicamente la aplicación; se excluyen
credenciales, cuentas, direcciones de red, pantallas Moodle y el bloqueo.
Los originales y los logs completos permanecen en el laboratorio local.
