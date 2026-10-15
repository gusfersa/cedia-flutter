# Errores, secretos y alcance de la auditoría

## Registro y pantalla

Solo pasan al registro mensajes construidos con constantes controladas. No se
serializa el objeto error ni su stack. Los casos de prueba usan canarios
sintéticos con aspecto de Bearer/JWT, contraseña, clave, cabecera y rutas de
fixture; comprueban su ausencia en consola capturada, registro y UI. También se
usa un objeto cuyo toString lanza una excepción para detectar una serialización
accidental.

El límite de 20 se prueba enviando cinco errores de rango y veinte de formato:
la lista final contiene solo los veinte últimos. El logger recibe 25 entradas
saneadas, y la API pública de recientes no permite alterarlas.

Los errores previstos no se convierten en fallos globales: se comprueban 400,
fallback de red a Hive y 401 con cierre de sesión y limpieza del filtro. Se
conservan todos los tests anteriores del proyecto y del servidor S9.

## Comprobaciones permitidas

```sh
git check-ignore -v .env .claude/settings.local.json CLAUDE.local.md
git log --all --oneline -- .env
rg -n -F -e api_key -e api-key -e SECRET_KEY -e sk- lib test .github AGENTS.md
```

El historial solo consulta metadatos de .env; no lee su contenido. La búsqueda
literal puede señalar nombres de parámetros o canarios de tests: un resultado
no es por sí solo un secreto. La clasificación y códigos efectivos quedan en
`verificacion.json`. No se leyó .env, llavero, cookies ni credenciales.

La auditoría cubre fuentes de app, tests, workflows y cambios autorizados. No es
una certificación de todo el historial, archivos ignorados o servicios externos.
No se leyó ni rotó ningún secreto. El JWT sigue perteneciendo al almacenamiento
seguro existente; el backend falso valida tokens sintéticos por usuario.

## Límites operativos

- El registro evita el mensaje original completo: reduce detalle diagnóstico.
- No es telemetría remota ni almacenamiento persistente; se limita a esta sesión.
- Los permisos de Claude propuestos no constituyen un sandbox general ni se
  afirman cargados o verificados. Leer y ejecutar shell son superficies distintas.
- URLs de laboratorio son públicas y compilables. No colocar una credencial en
  vars, dart-define, evidencia o APK.
- La validación de Actions, dispositivo y publicación permanece pendiente; no
  hay capturas ni APK ficticios.
