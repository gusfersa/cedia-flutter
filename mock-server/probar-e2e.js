// Adaptado de Patricio-CEDIA/exploraec-app, sesión 09, paso 8.
// Credenciales desde ENV o archivo privado; jamás argumentos ni salida.
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { listarHerramientas, obtenerResumenPorMcp } = require('./mcp-cliente');
const { validarSalida, autorizacionValida } = require('./validacion');

function leerCredenciales(entorno = process.env) {
  let email = entorno.E2E_EMAIL;
  let password = entorno.E2E_PASSWORD;
  if (entorno.E2E_CREDENTIALS_FILE) {
    const archivo = fs.realpathSync(entorno.E2E_CREDENTIALS_FILE);
    const raiz = path.resolve(__dirname, '..');
    const relativo = path.relative(raiz, archivo);
    if (relativo === '' || (!relativo.startsWith(`..${path.sep}`) && relativo !== '..' && !path.isAbsolute(relativo))) {
      throw new Error('El archivo de credenciales debe estar fuera del proyecto.');
    }
    const stat = fs.statSync(archivo);
    if (!stat.isFile() || stat.size > 8192 || (stat.mode & 0o077) !== 0) {
      throw new Error('El archivo privado debe ser pequeño y tener permisos 600.');
    }
    const datos = JSON.parse(fs.readFileSync(archivo, 'utf8'));
    email = datos.email;
    password = datos.password;
  }
  if (typeof email !== 'string' || !email.trim() || typeof password !== 'string' || !password) {
    throw new Error('Define E2E_EMAIL y E2E_PASSWORD, o E2E_CREDENTIALS_FILE fuera del proyecto.');
  }
  return { email, password };
}

async function ejecutarE2e({ email, password, backendUrl = process.env.BACKEND_URL || 'http://127.0.0.1:8000',
  proxyUrl = process.env.PROXY_URL || 'http://127.0.0.1:3801',
  mcpUrl = process.env.MCP_URL || `${backendUrl.replace(/\/$/, '')}/mcp/`,
  log = (linea) => console.log(linea) }) {
  backendUrl = backendUrl.replace(/\/$/, '');
  proxyUrl = proxyUrl.replace(/\/$/, '');
  let paso = 1;
  try {
    const salud = await fetch(`${backendUrl}/health`, { redirect: 'error', signal: AbortSignal.timeout(5000) });
    const estado = await salud.json();
    if (!salud.ok || estado.status !== 'ok') throw new Error('salud');
    log('OK 1/4: contenido de health válido.');
    paso = 2;
    const login = await fetch(`${backendUrl}/usuarios/token`, {
      method: 'POST', redirect: 'error', signal: AbortSignal.timeout(10000),
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ username: email, password }),
    });
    const datosLogin = await login.json();
    const autorizacion = `Bearer ${datosLogin.access_token || ''}`;
    if (!login.ok || !autorizacionValida(autorizacion)) throw new Error('login');
    log('OK 2/4: login válido; token conservado solo en memoria.');
    paso = 3;
    const nombres = await listarHerramientas(autorizacion, { url: mcpUrl });
    if (!nombres.includes('resumen_gastos')) throw new Error('herramienta');
    const resumen = await obtenerResumenPorMcp(autorizacion, { url: mcpUrl });
    log(`OK 3/4: resumen MCP validado; categorías=${resumen.categorias.length}.`);
    paso = 4;
    const r = await fetch(`${proxyUrl}/asistente`, {
      method: 'POST', redirect: 'error', signal: AbortSignal.timeout(20000),
      headers: { 'Content-Type': 'application/json', Authorization: autorizacion },
      body: JSON.stringify({ consulta: '¿En qué categoría gasto más?', resumen: { categorias: [], total_general: 0 } }),
    });
    const datos = await r.json();
    if (!r.ok || r.headers.get('x-resumen-origen') !== 'mcp' ||
        r.headers.get('x-asistente-modo') !== 'REGLAS' || datos.modo !== 'REGLAS') throw new Error('origen');
    const salida = validarSalida(datos);
    if (salida.accion) throw new Error('consulta produjo acción');
    const mayor = resumen.categorias.reduce((m, fila) => !m || fila.total > m.total ? fila : m, null);
    // Medir los datos, no solo 200/una etiqueta «mcp».
    if (mayor && mayor.total > 0) {
      if (!salida.respuesta.includes(`${mayor.categoria}: ${mayor.total.toFixed(2)}`) ||
          !salida.respuesta.includes(`${mayor.cantidad} gasto(s)`)) throw new Error('datos');
    } else if (!salida.respuesta.includes('Aún no tienes gastos registrados')) throw new Error('datos vacíos');
    log('OK 4/4: REGLAS coincide con los datos MCP aunque el cliente envió un resumen vacío.');
    return 0;
  } catch {
    log(`FALLO ${paso}/4: revisa ${['', 'el backend', 'las credenciales', 'el MCP/autenticación', 'el proxy, su origen MCP y los datos de la respuesta'][paso]}.`);
    return 1;
  }
}

if (require.main === module) {
  if (process.argv.length !== 2) {
    console.error('No se admiten argumentos. Usa ENV o un archivo privado para las credenciales.');
    process.exitCode = 2;
  } else {
    (async () => {
      let credenciales;
      try { credenciales = leerCredenciales(); }
      catch { console.error('Faltan credenciales válidas en ENV o un archivo privado fuera del proyecto (600).'); return 2; }
      return ejecutarE2e(credenciales);
    })().then((codigo) => { process.exitCode = codigo; });
  }
}

module.exports = { leerCredenciales, ejecutarE2e };
