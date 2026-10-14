# Proxy ExploraIA — sesión 09

Adaptación académica de `Patricio-CEDIA/exploraec-app`, rama `sesion-09`.
Conservar la atribución docente. La referencia consultada no incluye una licencia explícita;
no se concede una licencia adicional sobre su material.

Esta entrega funciona exclusivamente en **modo REGLAS**, permitido por el
instructivo. No usa un LLM ni llama a un proveedor externo. El proxy propone;
la app pide confirmación y el backend de gastos valida y crea.

Requiere Node 18+ y ninguna dependencia. Desde la raíz:

```sh
node mock-server/mock-server.js
node --test mock-server/test/*.test.js
```

Escucha exclusivamente en `127.0.0.1`, puerto **3801** (`PORT` permite otro).
MCP: `MCP_URL`, por defecto `http://127.0.0.1:8000/mcp/`.
El emulador Android usa `http://10.0.2.2:3801`; web requiere
`--dart-define=LLM_BACKEND_URL=http://127.0.0.1:3801`.
Los únicos orígenes CORS son `http://localhost:8802`, `http://127.0.0.1:8802`,
`http://localhost:8803` y `http://127.0.0.1:8803`.
OPTIONS permite POST con `Authorization, Content-Type` sin exigir token al preflight.

## Contrato

POST `/asistente`, `Content-Type: application/json`, `Authorization: Bearer …`.
Cuerpo: `{consulta, resumen: {categorias: [{categoria, total, cantidad, disponible}], total_general}}`.
Solo se permiten comida, transporte, entretenimiento y otros; categorías únicas,
números finitos no negativos en el resumen y total coherente (tolerancia 0.01).
Consulta de 1 a 500 caracteres, cuerpo máximo 64 KiB, descripción máxima 200.
Una propuesta tiene `tipo: registrar_gasto`, descripción, categoría y monto
finito positivo hasta 1 000 000. Esta cota técnica **permite 600**: no anticipa
el límite de negocio 500 del backend.

Respuesta: `{respuesta, modo: "REGLAS", accion?}`. Cabeceras:
`X-Resumen-Origen: mcp`, `X-Asistente-Modo: REGLAS`.
El resumen del cliente se valida pero nunca se usa para responder: siempre se
ejecuta MCP `initialize → notifications/initialized → tools/call resumen_gastos`.
Acepta JSON o SSE, `structuredContent` o contenido JSON textual.
No llama herramientas de escritura ni contiene una ruta de creación de gastos.

Errores: 400 JSON inválido; 401 falta/token rechazado; 403 origen/preflight;
413 más de 64 KiB; 415 tipo; 422 contrato; 502 salida inválida;
503 MCP inaccesible, respuesta inválida o error de herramienta.
No hay fallback a números del cliente. Las respuestas de error son locales y
legibles; nunca reflejan el contenido del backend. El timeout MCP total es 10 s.
Los logs de peticiones contienen únicamente bytes, nombres fijos de campos,
número de categorías y origen. No contienen token, correo, consulta ni filas.

REGLAS reconoce «¿En qué categoría gasto más?», «¿Cuánto me queda en comida?»
y «Registra un almuerzo de 6.50 en comida». Una recomendación de lugares es
genérica y se declara como tal.

## Prueba de integración con el backend

No pasar contraseñas por argumentos: aparecerían en `ps`/historial.
`probar-e2e.js` lee `E2E_EMAIL`/`E2E_PASSWORD` del entorno, o
`E2E_CREDENTIALS_FILE`: un JSON privado `{email, password}` fuera del proyecto,
permisos 600. No crear ese archivo en el repositorio.

```sh
# Credenciales ya cargadas en ENV o archivo privado; backend/proxy ya encendidos.
node mock-server/probar-e2e.js
```

Configurable: `BACKEND_URL`, `PROXY_URL`, `MCP_URL`.
Comprueba health, login, la herramienta y el resumen real MCP, y los valores de
la respuesta del proxy enviándole deliberadamente un resumen vacío. Sale 0
solo si los cuatro pasos coinciden. No imprime credenciales, respuesta ni filas.
Las pruebas Node ejecutan esta misma cadena con fixtures en memoria y comprueban
también que la fixture no recibió escrituras de gastos.
