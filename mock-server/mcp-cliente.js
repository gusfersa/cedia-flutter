// Cliente MCP mínimo adaptado de Patricio-CEDIA/exploraec-app, sesión 09.
// JSON-RPC Streamable HTTP: initialize -> initialized -> tools/call.
// Solo lectura, sin dependencias ni registros de contenido/autorización.
'use strict';
const { MAX_BODY, validarResumen, autorizacionValida } = require('./validacion');

const MCP_URL = process.env.MCP_URL || 'http://127.0.0.1:8000/mcp/';
const VERSION_PROTOCOLO = '2025-06-18';

class ErrorMcp extends Error {
  constructor(statusCode = 503) {
    super(statusCode === 401 ? 'Tu sesión caducó, inicia sesión de nuevo.' :
      'No se pudo obtener tu resumen por MCP. Revisa el backend e inténtalo de nuevo.');
    this.statusCode = statusCode;
  }
}

function errorAutenticacion(valor) {
  if (!valor) return false;
  const codigo = valor.statusCode ?? valor.status_code ?? valor.code;
  if (codigo === 401 || codigo === 403) return true;
  const texto = typeof valor === 'string' ? valor : valor.error ?? valor.message ?? '';
  return typeof texto === 'string' &&
    /no autenticad|no autorizad|unauthori[sz]ed|token.*(inv[aá]lid|caduc|expir)|invalid.*token/i.test(texto);
}

async function leerAcotado(respuesta) {
  if (Number(respuesta.headers.get('content-length')) > MAX_BODY) throw new ErrorMcp();
  if (!respuesta.body) return '';
  const lector = respuesta.body.getReader();
  const trozos = [];
  let bytes = 0;
  try {
    for (;;) {
      const { value, done } = await lector.read();
      if (done) break;
      bytes += value.byteLength;
      if (bytes > MAX_BODY) {
        await lector.cancel();
        throw new ErrorMcp();
      }
      trozos.push(Buffer.from(value));
    }
    return Buffer.concat(trozos).toString('utf8');
  } finally {
    lector.releaseLock();
  }
}

function decodificar(texto, tipo, id) {
  const candidatos = tipo.includes('text/event-stream')
    ? texto.split(/\r?\n\r?\n/).map((evento) => evento.split(/\r?\n/)
      .filter((linea) => linea.startsWith('data:'))
      .map((linea) => linea.slice(5).trimStart()).join('\n')).filter(Boolean)
    : [texto];
  for (const candidato of candidatos) {
    const datos = JSON.parse(candidato);
    if (datos && datos.jsonrpc === '2.0' && datos.id === id) {
      if (datos.error) throw new ErrorMcp(errorAutenticacion(datos.error) ? 401 : 503);
      if (!datos.result || typeof datos.result !== 'object') throw new ErrorMcp();
      return datos;
    }
  }
  throw new ErrorMcp();
}

async function enviar(mensaje, autorizacion, sesion, contexto) {
  const r = await contexto.fetch(contexto.url, {
    method: 'POST', redirect: 'error', signal: contexto.signal,
    headers: {
      'Content-Type': 'application/json', Accept: 'application/json, text/event-stream',
      Authorization: autorizacion, 'MCP-Protocol-Version': contexto.version,
      ...(sesion ? { 'Mcp-Session-Id': sesion } : {}),
    },
    body: JSON.stringify(mensaje),
  });
  if (r.status === 401 || r.status === 403) throw new ErrorMcp(401);
  if (!r.ok) throw new ErrorMcp();
  const nuevaSesion = r.headers.get('mcp-session-id') || sesion;
  if (nuevaSesion && (!/^[\x21-\x7e]{1,256}$/.test(nuevaSesion))) throw new ErrorMcp();
  const texto = await leerAcotado(r);
  if (mensaje.id == null) return { sesion: nuevaSesion, datos: null };
  if (!texto.trim()) throw new ErrorMcp();
  return { sesion: nuevaSesion, datos: decodificar(texto, r.headers.get('content-type') || '', mensaje.id) };
}

async function abrirSesion(autorizacion, contexto) {
  if (!autorizacionValida(autorizacion)) throw new ErrorMcp(401);
  const inicio = await enviar({ jsonrpc: '2.0', id: 1, method: 'initialize',
    params: { protocolVersion: VERSION_PROTOCOLO, capabilities: {},
      clientInfo: { name: 'proxy-exploraec', version: '1.0' } } }, autorizacion, null, contexto);
  const version = inicio.datos.result.protocolVersion;
  if (!['2025-06-18', '2025-03-26', '2024-11-05'].includes(version)) throw new ErrorMcp();
  contexto.version = version;
  await enviar({ jsonrpc: '2.0', method: 'notifications/initialized' }, autorizacion, inicio.sesion, contexto);
  return inicio.sesion;
}

function extraerResultado(respuesta) {
  const r = respuesta.result;
  let valor = r.structuredContent;
  if (!valor) {
    const texto = Array.isArray(r.content)
      ? r.content.filter((c) => c.type === 'text' && typeof c.text === 'string').map((c) => c.text).join('') : '';
    try { valor = JSON.parse(texto); } catch { throw new ErrorMcp(r.isError && errorAutenticacion(texto) ? 401 : 503); }
  }
  if (r.isError || (valor && valor.error)) throw new ErrorMcp(errorAutenticacion(valor) ? 401 : 503);
  if (valor && valor.result && !valor.categorias) valor = valor.result;
  if (valor && valor.error) throw new ErrorMcp(errorAutenticacion(valor) ? 401 : 503);
  return valor;
}

function contextoOpciones(opciones) {
  const url = new URL(opciones.url || MCP_URL);
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) throw new ErrorMcp();
  return { url: url.href, fetch: opciones.fetch || fetch,
    signal: AbortSignal.timeout(opciones.timeoutMs || 10000), version: VERSION_PROTOCOLO };
}

async function llamarHerramienta(nombre, argumentos, autorizacion, opciones = {}) {
  // No es un agente: ni consulta ni proveedor pueden elegir herramientas de escritura.
  if (nombre !== 'resumen_gastos' || !argumentos || Object.keys(argumentos).length !== 0) throw new ErrorMcp();
  try {
    const contexto = contextoOpciones(opciones);
    const sesion = await abrirSesion(autorizacion, contexto);
    const r = await enviar({ jsonrpc: '2.0', id: 2, method: 'tools/call',
      params: { name: nombre, arguments: {} } }, autorizacion, sesion, contexto);
    return validarResumen(extraerResultado(r.datos));
  } catch (e) {
    throw e instanceof ErrorMcp ? e : new ErrorMcp();
  }
}

async function listarHerramientas(autorizacion, opciones = {}) {
  try {
    const contexto = contextoOpciones(opciones);
    const sesion = await abrirSesion(autorizacion, contexto);
    const r = await enviar({ jsonrpc: '2.0', id: 2, method: 'tools/list' }, autorizacion, sesion, contexto);
    const lista = r.datos.result.tools;
    if (!Array.isArray(lista) || lista.some((h) => !h || typeof h.name !== 'string')) throw new ErrorMcp();
    return lista.map((h) => h.name);
  } catch (e) {
    throw e instanceof ErrorMcp ? e : new ErrorMcp();
  }
}

const obtenerResumenPorMcp = (autorizacion, opciones = {}) =>
  llamarHerramienta('resumen_gastos', {}, autorizacion, opciones);

module.exports = { MCP_URL, ErrorMcp, obtenerResumenPorMcp, llamarHerramienta, listarHerramientas };
