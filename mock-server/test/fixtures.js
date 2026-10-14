'use strict';
// Todo en memoria y loopback: no Docker, DB, cuentas ni datos reales.
const http = require('node:http');
const { once } = require('node:events');

const resumen = () => ({ categorias: [
  { categoria: 'comida', total: 20, cantidad: 2, disponible: 480 },
  { categoria: 'transporte', total: 72, cantidad: 3, disponible: 428 },
  { categoria: 'entretenimiento', total: 0, cantidad: 0, disponible: 500 },
  { categoria: 'otros', total: 0, cantidad: 0, disponible: 500 },
], total_general: 92 });

async function escuchar(servidor, t) {
  servidor.listen(0, '127.0.0.1');
  await once(servidor, 'listening');
  t.after(async () => {
    const cierre = new Promise((resolve) => servidor.close(resolve));
    servidor.closeAllConnections();
    await cierre;
  });
  return `http://127.0.0.1:${servidor.address().port}`;
}

async function backendFixture(t, opciones = {}) {
  const estado = { mensajes: [], escrituras: 0, modo: 'json', resumen: resumen(), ...opciones };
  const servidor = http.createServer(async (req, res) => {
    const partes = [];
    for await (const parte of req) partes.push(parte);
    const texto = Buffer.concat(partes).toString('utf8');
    const json = (codigo, valor, extra = {}) => {
      res.writeHead(codigo, { 'Content-Type': 'application/json', ...extra });
      res.end(valor == null ? '' : JSON.stringify(valor));
    };
    if (req.url === '/health') return json(200, { status: estado.salud || 'ok' });
    if (req.url === '/usuarios/token') {
      const form = new URLSearchParams(texto);
      return form.get('username') === 'fixture@example.invalid' && form.get('password') === 'fixture-password'
        ? json(200, { access_token: 'fixture-token' }) : json(401, { detail: 'credenciales' });
    }
    if (req.url.startsWith('/gastos') && req.method === 'POST') {
      estado.escrituras++;
      return json(201, { id: estado.escrituras });
    }
    if (req.url !== '/mcp/') return json(404, {});
    const mensaje = JSON.parse(texto);
    estado.mensajes.push({ mensaje, authorization: req.headers.authorization,
      sesion: req.headers['mcp-session-id'], version: req.headers['mcp-protocol-version'] });
    if (req.headers.authorization !== 'Bearer fixture-token' || estado.modo === '401') {
      return json(401, { detail: 'fixture-token no autorizado' });
    }
    const rpc = (result) => ({ jsonrpc: '2.0', id: mensaje.id, result });
    if (mensaje.method === 'initialize') return json(200, rpc({
      protocolVersion: '2025-06-18', capabilities: { tools: {} },
      serverInfo: { name: 'fixture', version: '1' },
    }), { 'Mcp-Session-Id': 'fixture-session' });
    if (mensaje.method === 'notifications/initialized') return json(202, null);
    if (req.headers['mcp-session-id'] !== 'fixture-session') return json(400, {});
    if (mensaje.method === 'tools/list') return json(200, rpc({ tools: [{ name: 'resumen_gastos' }, { name: 'crear_gasto' }] }));
    if (estado.modo === '503') return json(503, { detail: 'dato que no debe filtrarse' });
    if (estado.modo === 'maljson') { res.writeHead(200, { 'Content-Type': 'application/json' }); return res.end('{'); }
    if (estado.modo === 'id') return json(200, { ...rpc({ structuredContent: estado.resumen }), id: 999 });
    if (estado.modo === 'error') return json(200, rpc({ isError: true,
      content: [{ type: 'text', text: JSON.stringify({ error: 'fallo fixture-token privado' }) }] }));
    if (estado.modo === 'token') return json(200, rpc({ isError: true,
      content: [{ type: 'text', text: JSON.stringify({ error: 'Token inválido o expirado' }) }] }));
    if (estado.modo === 'rpcerror') return json(200, { jsonrpc: '2.0', id: mensaje.id, error: { code: 401, message: 'privado' } });
    if (estado.modo === 'grande') { res.writeHead(200, { 'Content-Type': 'application/json' }); return res.end(' '.repeat(65537)); }
    if (estado.modo === 'vacio') return json(200, null);
    if (estado.modo === 'sse') {
      res.writeHead(200, { 'Content-Type': 'text/event-stream' });
      const respuesta = rpc({ content: [{ type: 'text', text: JSON.stringify(estado.resumen) }] });
      // Evento auxiliar seguido de data multilínea.
      res.end(`: keepalive\n\ndata: {"jsonrpc":"2.0","method":"notifications/progress"}\n\nevent: message\ndata: ${JSON.stringify(respuesta, null, 2).split('\n').join('\ndata: ')}\n\n`);
      return;
    }
    if (estado.modo === 'texto') return json(200, rpc({ content: [{ type: 'text', text: JSON.stringify(estado.resumen) }] }));
    if (estado.modo === 'envuelto') return json(200, rpc({ structuredContent: { result: estado.resumen } }));
    return json(200, rpc({ structuredContent: estado.resumen }));
  });
  const url = await escuchar(servidor, t);
  return { url, estado };
}

module.exports = { escuchar, backendFixture, resumen };
