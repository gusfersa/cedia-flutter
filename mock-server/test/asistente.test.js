'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { crearServidor, responderConReglas } = require('../mock-server');
const { obtenerResumenPorMcp, llamarHerramienta, ErrorMcp } = require('../mcp-cliente');
const { validarResumen, validarSalida, MAX_BODY, MAX_MONTO } = require('../validacion');
const { ejecutarE2e, leerCredenciales } = require('../probar-e2e');
const { escuchar, backendFixture, resumen } = require('./fixtures');

const vacio = { categorias: [], total_general: 0 };
const cuerpo = (consulta = '¿En qué categoría gasto más?') => ({ consulta, resumen: vacio });

async function montar(t, opciones = {}) {
  const backend = await backendFixture(t);
  const logs = [];
  const url = await escuchar(crearServidor({
    obtenerResumen: (auth) => obtenerResumenPorMcp(auth, { url: `${backend.url}/mcp/` }),
    log: (linea) => logs.push(linea), ...opciones,
  }), t);
  return { url, backend, logs };
}

async function pedir(url, valor = cuerpo(), headers = {}) {
  const r = await fetch(`${url}/asistente`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer fixture-token', ...headers },
    body: typeof valor === 'string' ? valor : JSON.stringify(valor),
  });
  return { r, datos: await r.json() };
}

test('MCP real sobre HTTP reemplaza números del cliente, conserva token/sesión y solo lee', async (t) => {
  const { url, backend, logs } = await montar(t);
  const { r, datos } = await pedir(url, { consulta: '¿En qué categoría gasto más?', resumen: {
    categorias: [{ categoria: 'otros', total: 400, cantidad: 10, disponible: 100 }], total_general: 400,
  } });
  assert.equal(r.status, 200);
  assert.equal(r.headers.get('x-resumen-origen'), 'mcp');
  assert.equal(datos.modo, 'REGLAS');
  assert.equal(datos.respuesta, 'Gastas más en transporte: 72.00 en 3 gasto(s).');
  assert.equal(datos.accion, undefined);
  assert.deepEqual(backend.estado.mensajes.map((m) => m.mensaje.method), ['initialize', 'notifications/initialized', 'tools/call']);
  assert.equal(backend.estado.mensajes[2].mensaje.params.name, 'resumen_gastos');
  assert.deepEqual(backend.estado.mensajes[2].mensaje.params.arguments, {});
  assert.ok(backend.estado.mensajes.every((m) => m.authorization === 'Bearer fixture-token'));
  assert.equal(backend.estado.mensajes[2].sesion, 'fixture-session');
  assert.equal(backend.estado.escrituras, 0);
  assert.match(logs[0], /^bytes=\d+ campos=consulta,resumen categorias=4 origen=mcp$/);
  assert.ok(!logs.join('').includes('fixture-token'));
});

test('Disponibilidad y propuesta de 600 medidas con MCP; el proxy jamás hace POST gastos', async (t) => {
  const { url, backend } = await montar(t);
  assert.equal((await pedir(url, cuerpo('¿Cuánto me queda en comida?'))).datos.respuesta,
    'Te quedan 480.00 en comida (límite de 500 por categoría).');
  const { r, datos } = await pedir(url, cuerpo('Registra un gasto de 600 en comida'));
  assert.equal(r.status, 200);
  assert.deepEqual(datos.accion, { tipo: 'registrar_gasto', descripcion: 'Gasto', monto: 600, categoria: 'comida' });
  assert.equal(backend.estado.escrituras, 0);
  assert.ok(backend.estado.mensajes.filter((m) => m.mensaje.method === 'tools/call')
    .every((m) => m.mensaje.params.name === 'resumen_gastos'));
});

for (const modo of ['sse', 'texto', 'envuelto']) {
  test(`Transporte MCP ${modo}: datos reales decodificados`, async (t) => {
    const { url, backend } = await montar(t);
    backend.estado.modo = modo;
    const { r, datos } = await pedir(url);
    assert.equal(r.status, 200);
    assert.match(datos.respuesta, /transporte: 72\.00/);
  });
}

for (const [modo, status] of [['401', 401], ['token', 401], ['rpcerror', 401],
  ['503', 503], ['error', 503], ['maljson', 503], ['id', 503], ['grande', 503], ['vacio', 503]]) {
  test(`MCP ${modo}: ${status}, sin fallback ni detalle privado`, async (t) => {
    const { url, backend, logs } = await montar(t);
    backend.estado.modo = modo;
    const { r, datos } = await pedir(url);
    assert.equal(r.status, status);
    assert.equal(r.headers.get('x-resumen-origen'), null);
    assert.equal(datos.respuesta, undefined);
    assert.equal(datos.accion, undefined);
    assert.ok(!JSON.stringify(datos).includes('fixture-token'));
    assert.equal(logs.length, 0);
  });
}

test('MCP inaccesible: mensaje 503 sin números del resumen del cliente', async (t) => {
  const url = await escuchar(crearServidor({ obtenerResumen: () => { throw new Error('consulta privada'); } }), t);
  const { r, datos } = await pedir(url);
  assert.equal(r.status, 503);
  assert.match(datos.detail, /MCP/);
  assert.ok(!datos.detail.includes('consulta privada'));
});

test('Resumen MCP malformado nunca sale como éxito', async (t) => {
  const { url, backend } = await montar(t);
  backend.estado.resumen.categorias[0].total = '20';
  const { r, datos } = await pedir(url);
  assert.equal(r.status, 503);
  assert.equal(datos.respuesta, undefined);
});

test('Falta/auth inválida se rechaza antes de llamar a MCP', async (t) => {
  const { url, backend } = await montar(t);
  for (const Authorization of ['', 'Basic fixture', 'Bearer', 'Bearer espacio extra']) {
    const { r } = await pedir(url, cuerpo(), { Authorization });
    assert.equal(r.status, 401);
    assert.equal(r.headers.get('www-authenticate'), 'Bearer');
  }
  assert.equal(backend.estado.mensajes.length, 0);
});

test('CORS preflight permite Authorization solo en cuatro orígenes exactos', async (t) => {
  const { url, backend } = await montar(t);
  for (const Origin of ['http://localhost:8802', 'http://127.0.0.1:8802', 'http://localhost:8803', 'http://127.0.0.1:8803']) {
    const r = await fetch(`${url}/asistente`, { method: 'OPTIONS', headers: {
      Origin, 'Access-Control-Request-Method': 'POST', 'Access-Control-Request-Headers': 'authorization,content-type',
    } });
    assert.equal(r.status, 204);
    assert.equal(r.headers.get('access-control-allow-origin'), Origin);
    assert.match(r.headers.get('access-control-allow-headers'), /Authorization/);
    const post = await pedir(url, cuerpo(), { Origin });
    assert.equal(post.r.headers.get('access-control-allow-origin'), Origin);
  }
  assert.equal(backend.estado.escrituras, 0);
  for (const Origin of ['http://localhost:8804', 'https://localhost:8802', 'http://localhost.evil:8802', 'null']) {
    const { r } = await pedir(url, cuerpo(), { Origin });
    assert.equal(r.status, 403);
    assert.equal(r.headers.get('access-control-allow-origin'), null);
  }
});

test('Preflight headers ajenos y métodos ajenos no son autorizados', async (t) => {
  const { url } = await montar(t);
  for (const [metodo, cabeceras] of [['DELETE', 'authorization'], ['POST', 'x-private']]) {
    const r = await fetch(`${url}/asistente`, { method: 'OPTIONS', headers: { Origin: 'http://localhost:8802',
      'Access-Control-Request-Method': metodo, 'Access-Control-Request-Headers': cabeceras } });
    assert.equal(r.status, 403);
  }
});

for (const [valor, codigo] of [['{', 400], ['null', 422], ['[]', 422], [3, 422],
  [{ ...cuerpo(), consulta: '' }, 422], [{ ...cuerpo(), consulta: 7 }, 422],
  [{ ...cuerpo(), consulta: 'x'.repeat(501) }, 422], [{ consulta: 'x' }, 422],
  [{ ...cuerpo(), resumen: { categorias: [null], total_general: 0 } }, 422],
  [{ ...cuerpo(), 'campo-secreto': 'contenido-secreto' }, 422]]) {
  test(`Entrada inválida (${typeof valor}, código ${codigo}) no consulta MCP`, async (t) => {
    const { url, backend, logs } = await montar(t);
    const { r, datos } = await pedir(url, valor);
    assert.equal(r.status, codigo);
    assert.equal(backend.estado.mensajes.length, 0);
    assert.equal(logs.length, 0);
    assert.ok(!JSON.stringify(datos).includes('contenido-secreto'));
  });
}

test('Tipos, cantidades, categorías, sumas y valores no finitos del resumen se validan', () => {
  for (const cambiar of [
    (r) => { r.categorias[0].categoria = 'inventada'; },
    (r) => { r.categorias.push(r.categorias[0]); },
    (r) => { r.categorias[0].total = Infinity; },
    (r) => { r.categorias[0].disponible = NaN; },
    (r) => { r.categorias[0].cantidad = 1.5; },
    (r) => { r.categorias[0].cantidad = -1; },
    (r) => { r.total_general = 900; },
  ]) {
    const r = resumen(); cambiar(r);
    assert.throws(() => validarResumen(r), { statusCode: 422 });
  }
});

test('Salida inválida, categoría inventada, montos no finitos o fuera de cota se rechazan', () => {
  const a = { tipo: 'registrar_gasto', descripcion: 'Gasto', monto: 600, categoria: 'comida' };
  assert.equal(validarSalida({ respuesta: 'ok', accion: a }).accion.monto, 600);
  for (const valor of [null, {}, { respuesta: '' }, { respuesta: 6 },
    ...[Infinity, NaN, 0, -1, MAX_MONTO + 1, '6'].map((monto) => ({ respuesta: 'ok', accion: { ...a, monto } })),
    { respuesta: 'ok', accion: { ...a, tipo: 'crear_usuario' } },
    { respuesta: 'ok', accion: { ...a, categoria: 'inventada' } },
    { respuesta: 'ok', accion: { ...a, descripcion: 'x'.repeat(201) } }]) {
    assert.throws(() => validarSalida(valor), { statusCode: 502 });
  }
});

test('Salida malformada se mide también por HTTP y no llega una propuesta', async (t) => {
  const { url } = await montar(t, { responder: () => ({ respuesta: 'ok', accion: { tipo: 'borrar' } }) });
  const { r, datos } = await pedir(url);
  assert.equal(r.status, 502);
  assert.equal(datos.accion, undefined);
});

test('64 KiB exactos aceptados; 64 KiB+1 rechaza longitud y cuerpo chunked', async (t) => {
  const { url } = await montar(t);
  const json = JSON.stringify(cuerpo());
  const limite = json + ' '.repeat(MAX_BODY - Buffer.byteLength(json));
  assert.equal((await pedir(url, limite)).r.status, 200);
  assert.equal((await pedir(url, limite + ' ')).r.status, 413);
  const codigo = await new Promise((resolve, reject) => {
    const req = http.request(`${url}/asistente`, { method: 'POST', headers: {
      Authorization: 'Bearer fixture-token', 'Content-Type': 'application/json', 'Transfer-Encoding': 'chunked',
    } }, (res) => { res.resume(); res.on('end', () => resolve(res.statusCode)); });
    req.on('error', reject);
    req.write(limite.slice(0, 32000));
    req.end(limite.slice(32000) + ' ');
  });
  assert.equal(codigo, 413);
});

test('Texto original, token y filas ausentes de logs', async (t) => {
  const { url, logs } = await montar(t);
  const { r } = await pedir(url, cuerpo('correo-privado@example.invalid consulta-privada'));
  assert.equal(r.status, 200);
  assert.equal(logs.length, 1);
  assert.ok(!logs.join('').includes('correo-privado'));
  assert.ok(!logs.join('').includes('consulta-privada'));
  assert.ok(!logs.join('').includes('fixture-token'));
  assert.ok(!logs.join('').includes('disponible'));
});

test('Solo resumen_gastos permitido: intento de escritura no abre sesión MCP', async (t) => {
  const { url, estado } = await backendFixture(t);
  await assert.rejects(llamarHerramienta('crear_gasto', {}, 'Bearer fixture-token', { url: `${url}/mcp/` }), ErrorMcp);
  assert.equal(estado.mensajes.length, 0);
  assert.equal(estado.escrituras, 0);
});

test('Prueba E2E docente mide toda la cadena sobre fixtures y falla ante datos falsos', async (t) => {
  const { url, backend } = await montar(t);
  const log = [];
  const opciones = { email: 'fixture@example.invalid', password: 'fixture-password',
    backendUrl: backend.url, proxyUrl: url, log: (s) => log.push(s) };
  assert.equal(await ejecutarE2e(opciones), 0);
  assert.equal(log.filter((s) => s.startsWith('OK')).length, 4);
  assert.ok(!log.join('').includes('fixture-password'));
  assert.ok(!log.join('').includes('fixture-token'));
  assert.equal(backend.estado.escrituras, 0);
  const falso = await escuchar(crearServidor({ obtenerResumen: () => resumen(),
    responder: () => ({ respuesta: 'Gastas más en comida: 999.00 en 9 gasto(s).' }), log: () => {} }), t);
  assert.equal(await ejecutarE2e({ ...opciones, proxyUrl: falso }), 1);
  assert.match(log.at(-1), /^FALLO 4\/4/);
});

test('E2E falla antes de consultar MCP ante login rechazado; credenciales desde ENV', async (t) => {
  const { url, estado } = await backendFixture(t);
  assert.deepEqual(leerCredenciales({ E2E_EMAIL: 'fixture@example.invalid', E2E_PASSWORD: 'fixture-password' }),
    { email: 'fixture@example.invalid', password: 'fixture-password' });
  assert.throws(() => leerCredenciales({}), /Define/);
  assert.equal(await ejecutarE2e({ email: 'fixture@example.invalid', password: 'incorrecta', backendUrl: url, log: () => {} }), 1);
  assert.equal(estado.mensajes.length, 0);
});

test('REGLAS no inventa categoría ausente ni altera el resumen', () => {
  const r = resumen();
  const antes = JSON.stringify(r);
  assert.match(responderConReglas('¿Cuánto me queda en comida?', vacio).respuesta, /no incluye/);
  responderConReglas('¿En qué categoría gasto más?', r);
  assert.equal(JSON.stringify(r), antes);
});
