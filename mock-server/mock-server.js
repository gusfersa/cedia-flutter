// Adaptado de Patricio-CEDIA/exploraec-app, sesión 09 (paso 8 activo).
// Laboratorio REGLAS: sin proveedor externo. El proxy solo propone acciones.
'use strict';
const http = require('node:http');
const { obtenerResumenPorMcp, ErrorMcp } = require('./mcp-cliente');
const { CATEGORIAS, MAX_BODY, ErrorContrato, validarResumen, validarEntrada,
  validarSalida, autorizacionValida } = require('./validacion');

const ORIGENES = new Set(['http://localhost:8802', 'http://127.0.0.1:8802',
  'http://localhost:8803', 'http://127.0.0.1:8803']);
const normalizar = (t) => t.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
const dinero = (n) => n.toFixed(2);
const categoriaMencionada = (t) => CATEGORIAS.find((c) => new RegExp(`\\b${c}\\b`).test(t));

function responderConReglas(consulta, resumen) {
  const texto = normalizar(consulta);
  const filas = resumen.categorias;
  const registro = texto.match(/^registra(?:r)?\s+(?:(?:un|una)\s+)?(.+?)\s+de\s+(\d+(?:[.,]\d+)?)\s+en\s+(comida|transporte|entretenimiento|otros)[.!?]?$/);
  if (registro) {
    const descripcion = registro[1].trim().replace(/^./, (c) => c.toUpperCase());
    const monto = Number(registro[2].replace(',', '.'));
    return { respuesta: `Puedo registrar «${descripcion}» por ${dinero(monto)} en ${registro[3]}. Confírmalo para guardarlo.`,
      accion: { tipo: 'registrar_gasto', descripcion, monto, categoria: registro[3] } };
  }
  if (texto.includes('queda')) {
    const categoria = categoriaMencionada(texto);
    const fila = filas.find((f) => f.categoria === categoria);
    if (fila) return { respuesta: `Te quedan ${dinero(fila.disponible)} en ${categoria} (límite de 500 por categoría).` };
    return { respuesta: 'El resumen del backend no incluye esa categoría; no puedo calcular cuánto queda.' };
  }
  if (texto.includes('categoria') && (texto.includes('mas') || texto.includes('mayor'))) {
    const conGasto = filas.filter((f) => f.total > 0).sort((a, b) => b.total - a.total);
    return { respuesta: conGasto.length
      ? `Gastas más en ${conGasto[0].categoria}: ${dinero(conGasto[0].total)} en ${conGasto[0].cantidad} gasto(s).`
      : 'Aún no tienes gastos registrados, así que no hay una categoría que destaque.' };
  }
  if (texto.includes('lugar') && texto.includes('barato')) {
    return { respuesta: 'Modo REGLAS: no conozco los lugares de la app. Como orientación genérica, los mercados suelen tener opciones económicas.' };
  }
  return { respuesta: 'En modo REGLAS reconozco: «¿en qué categoría gasto más?», «¿cuánto me queda en <categoría>?» y «registra un <descripción> de <monto> en <categoría>».' };
}

function leerCuerpo(req) {
  return new Promise((resolve, reject) => {
    const trozos = [];
    let bytes = 0;
    let excedido = Number(req.headers['content-length']) > MAX_BODY;
    if (excedido) reject(new ErrorContrato(413, 'El cuerpo supera el máximo de 64 KiB.'));
    req.on('data', (trozo) => {
      bytes += trozo.length;
      if (excedido) return;
      if (bytes > MAX_BODY) {
        excedido = true;
        reject(new ErrorContrato(413, 'El cuerpo supera el máximo de 64 KiB.'));
      } else trozos.push(trozo);
    });
    req.on('end', () => { if (!excedido) resolve({ bruto: Buffer.concat(trozos), bytes }); });
    req.on('error', () => reject(new ErrorContrato(400, 'No se pudo leer el cuerpo de la petición.')));
  });
}

function crearServidor({ obtenerResumen = obtenerResumenPorMcp,
  responder = responderConReglas, log = (linea) => console.log(linea) } = {}) {
  return http.createServer(async (req, res) => {
    const origen = req.headers.origin;
    const cors = origen && ORIGENES.has(origen) ? {
      'Access-Control-Allow-Origin': origen, Vary: 'Origin',
      'Access-Control-Expose-Headers': 'X-Resumen-Origen, X-Asistente-Modo',
    } : {};
    const enviar = (codigo, datos, extra = {}) => {
      res.writeHead(codigo, { 'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff', ...cors, ...extra });
      res.end(datos == null ? undefined : JSON.stringify(datos));
    };
    if (origen && !ORIGENES.has(origen)) return enviar(403, { detail: 'Origen no permitido.' });
    if (req.url !== '/asistente') return enviar(404, { detail: 'Ruta no encontrada. Usa POST /asistente.' });
    if (req.method === 'OPTIONS') {
      const cabeceras = String(req.headers['access-control-request-headers'] || '').toLowerCase()
        .split(',').map((h) => h.trim()).filter(Boolean);
      if (!origen || req.headers['access-control-request-method'] !== 'POST' ||
          cabeceras.some((h) => !['authorization', 'content-type'].includes(h))) {
        return enviar(403, { detail: 'Preflight no permitido.' });
      }
      return enviar(204, null, { 'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Authorization, Content-Type', 'Access-Control-Max-Age': '600' });
    }
    if (req.method !== 'POST') return enviar(405, { detail: 'Usa POST /asistente.' }, { Allow: 'POST, OPTIONS' });
    if (!autorizacionValida(req.headers.authorization)) {
      return enviar(401, { detail: 'Inicia sesión para consultar el asistente.' }, { 'WWW-Authenticate': 'Bearer' });
    }
    if (!/^application\/json(?:\s*;|$)/i.test(req.headers['content-type'] || '')) {
      return enviar(415, { detail: 'El cuerpo debe ser application/json.' });
    }
    try {
      const { bruto, bytes } = await leerCuerpo(req);
      let datos;
      try { datos = JSON.parse(bruto.toString('utf8')); }
      catch { throw new ErrorContrato(400, 'El cuerpo no es un JSON válido.'); }
      const cuerpo = validarEntrada(datos);
      // Paso 8 obligatorio. Nunca usar el resumen del cliente ante un fallo MCP.
      let resumen;
      try { resumen = validarResumen(await obtenerResumen(req.headers.authorization)); }
      catch (e) { throw e instanceof ErrorMcp ? e : new ErrorMcp(); }
      const salida = validarSalida(await responder(cuerpo.consulta, resumen));
      // Nombres constantes: una clave maliciosa tampoco puede filtrarse en logs.
      log(`bytes=${bytes} campos=consulta,resumen categorias=${resumen.categorias.length} origen=mcp`);
      enviar(200, salida, { 'X-Resumen-Origen': 'mcp', 'X-Asistente-Modo': 'REGLAS' });
    } catch (e) {
      const conocido = e instanceof ErrorContrato || e instanceof ErrorMcp;
      const codigo = conocido ? e.statusCode : 500;
      enviar(codigo, { detail: conocido ? e.message : 'Error interno del proxy. Inténtalo de nuevo.' },
        codigo === 401 ? { 'WWW-Authenticate': 'Bearer' } : {});
    }
  });
}

if (require.main === module) {
  const puerto = Number(process.env.PORT || 3801);
  if (!Number.isInteger(puerto) || puerto < 1 || puerto > 65535) {
    console.error('PORT debe ser un puerto válido.');
    process.exitCode = 2;
  } else {
    const servidor = crearServidor();
    servidor.on('error', () => { console.error('No se pudo abrir el puerto del proxy.'); process.exitCode = 1; });
    servidor.listen(puerto, '127.0.0.1', () => {
      console.log(`Proxy modo REGLAS, sin modelo externo, en http://127.0.0.1:${puerto}`);
    });
  }
}

module.exports = { crearServidor, responderConReglas };
