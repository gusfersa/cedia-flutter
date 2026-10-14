// Adaptación académica de Patricio-CEDIA/exploraec-app, sesión 09.
'use strict';

const CATEGORIAS = Object.freeze(['comida', 'transporte', 'entretenimiento', 'otros']);
const MAX_MONTO = 1000000; // Cota técnica; el límite 500 lo decide el backend.
const MAX_BODY = 64 * 1024;
const objeto = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
const numero = (v, max = MAX_MONTO) => typeof v === 'number' && Number.isFinite(v) && v >= 0 && v <= max;

class ErrorContrato extends Error {
  constructor(statusCode, mensaje) {
    super(mensaje);
    this.statusCode = statusCode;
  }
}

function validarResumen(valor) {
  const invalido = () => { throw new ErrorContrato(422, 'El resumen de gastos no tiene el formato esperado.'); };
  if (!objeto(valor) || !Array.isArray(valor.categorias) || valor.categorias.length > 4 ||
      !numero(valor.total_general, MAX_MONTO * 4)) invalido();
  const vistas = new Set();
  const categorias = valor.categorias.map((f) => {
    if (!objeto(f) || !CATEGORIAS.includes(f.categoria) || vistas.has(f.categoria) ||
        !numero(f.total) || !numero(f.disponible) || !Number.isSafeInteger(f.cantidad) ||
        f.cantidad < 0 || f.cantidad > 1000000) invalido();
    vistas.add(f.categoria);
    return { categoria: f.categoria, total: f.total, cantidad: f.cantidad, disponible: f.disponible };
  });
  if (Math.abs(categorias.reduce((s, f) => s + f.total, 0) - valor.total_general) > 0.01) invalido();
  return { categorias, total_general: valor.total_general };
}

function validarEntrada(valor) {
  if (!objeto(valor) || Object.keys(valor).some((k) => !['consulta', 'resumen'].includes(k)) ||
      typeof valor.consulta !== 'string' || !valor.consulta.trim() || valor.consulta.length > 500) {
    throw new ErrorContrato(422, 'Envía consulta (1 a 500 caracteres) y resumen por categoría.');
  }
  return { consulta: valor.consulta.trim(), resumen: validarResumen(valor.resumen) };
}

function validarSalida(valor) {
  const invalido = () => { throw new ErrorContrato(502, 'El asistente devolvió una respuesta inválida.'); };
  if (!objeto(valor) || typeof valor.respuesta !== 'string' || !valor.respuesta.trim() ||
      valor.respuesta.length > 2000) invalido();
  const salida = { respuesta: valor.respuesta.trim(), modo: 'REGLAS' };
  const a = valor.accion;
  if (a != null) {
    if (!objeto(a) || a.tipo !== 'registrar_gasto' || typeof a.descripcion !== 'string' ||
        !a.descripcion.trim() || a.descripcion.length > 200 || !numero(a.monto) ||
        a.monto <= 0 || !CATEGORIAS.includes(a.categoria)) invalido();
    salida.accion = { tipo: a.tipo, descripcion: a.descripcion.trim(), monto: a.monto, categoria: a.categoria };
  }
  return salida;
}

function autorizacionValida(valor) {
  return typeof valor === 'string' && valor.length <= 8192 && /^Bearer [A-Za-z0-9._~+\/-]+=*$/.test(valor);
}

module.exports = { CATEGORIAS, MAX_MONTO, MAX_BODY, ErrorContrato, validarResumen,
  validarEntrada, validarSalida, autorizacionValida };
