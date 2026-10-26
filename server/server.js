'use strict';

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const {
  hashPassword,
  verifyPassword,
  createToken,
  verifyToken,
  extractBearerToken
} = require('./auth');
const { procesarConsultaCulinaria } = require('./ai');

const PUERTO = process.env.PORT || 8000;
const ARCHIVO_RECETAS = path.join(__dirname, 'data', 'recetas.json');

// Cargar catálogo inicial de recetas
let recetas = [];
try {
  recetas = JSON.parse(fs.readFileSync(ARCHIVO_RECETAS, 'utf8'));
} catch (e) {
  console.warn('Advertencia: no se pudo leer recetas.json, iniciando catálogo vacío:', e.message);
  recetas = [];
}

// Almacén de usuarios en memoria (con un usuario demo inicial)
const usuarios = new Map();
// Usuario inicial para pruebas directas
const passDemo = hashPassword('segura123');
usuarios.set('demo@chefcraft.ec', {
  id: 'usr-demo-01',
  nombre: 'Chef Demostración',
  email: 'demo@chefcraft.ec',
  passwordHash: passDemo
});

function enviarRespuesta(res, codigo, datos, extraHeaders = {}) {
  const payload = datos !== null && datos !== undefined ? JSON.stringify(datos) : '';
  res.writeHead(codigo, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type, Accept',
    'Access-Control-Max-Age': '86400',
    'Cache-Control': 'no-store',
    ...extraHeaders
  });
  res.end(payload);
}

function leerCuerpoJson(req) {
  return new Promise((resolve, reject) => {
    let datos = '';
    req.on('data', (chunk) => {
      datos += chunk;
      if (datos.length > 2 * 1024 * 1024) {
        reject({ codigo: 413, mensaje: 'Carga demasiado pesada (máx 2MB)' });
      }
    });
    req.on('end', () => {
      if (!datos.trim()) return resolve({});
      try {
        resolve(JSON.parse(datos));
      } catch {
        reject({ codigo: 400, mensaje: 'El cuerpo de la solicitud no es un JSON válido' });
      }
    });
    req.on('error', () => {
      reject({ codigo: 500, mensaje: 'Error al leer el flujo de datos' });
    });
  });
}

function requerirAutenticacion(req, res) {
  const token = extractBearerToken(req.headers.authorization);
  if (!token) {
    enviarRespuesta(res, 401, {
      error: 'No autorizado',
      detail: 'Se requiere token de autenticación Bearer válido para acceder a este recurso.'
    });
    return null;
  }
  const payload = verifyToken(token);
  if (!payload) {
    enviarRespuesta(res, 401, {
      error: 'Token inválido o expirado',
      detail: 'El token proporcionado no es válido o ha expirado. Inicia sesión nuevamente.'
    });
    return null;
  }
  return payload;
}

function crearServidor() {
  return http.createServer(async (req, res) => {
    const parsedUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    const pathname = parsedUrl.pathname;
    const metodo = req.method;

    // Manejo de Preflight CORS
    if (metodo === 'OPTIONS') {
      return enviarRespuesta(res, 204, null);
    }

    // Ruta de estado de salud
    if (pathname === '/health' || pathname === '/api/health') {
      return enviarRespuesta(res, 200, {
        estado: 'ok',
        servicio: 'ChefCraft Backend API',
        recetasRegistradas: recetas.length,
        version: '1.0.0'
      });
    }

    // ==========================================================
    // RUTAS DE AUTENTICACIÓN
    // ==========================================================

    // POST /api/auth/register
    if (pathname === '/api/auth/register' && metodo === 'POST') {
      try {
        const cuerpo = await leerCuerpoJson(req);
        const { nombre, email, password } = cuerpo;

        if (!nombre || typeof nombre !== 'string' || nombre.trim().length < 2) {
          return enviarRespuesta(res, 422, {
            error: 'Validación fallida',
            detail: 'El nombre es obligatorio y debe tener al menos 2 caracteres.'
          });
        }
        if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
          return enviarRespuesta(res, 422, {
            error: 'Validación fallida',
            detail: 'El correo electrónico no es válido.'
          });
        }
        if (!password || typeof password !== 'string' || password.length < 6) {
          return enviarRespuesta(res, 422, {
            error: 'Validación fallida',
            detail: 'La contraseña debe tener un mínimo de 6 caracteres.'
          });
        }

        const correoNormalizado = email.toLowerCase().trim();
        if (usuarios.has(correoNormalizado)) {
          return enviarRespuesta(res, 400, {
            error: 'Correo ya registrado',
            detail: 'Ya existe una cuenta creada con este correo electrónico.'
          });
        }

        const nuevoUsuario = {
          id: `usr-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
          nombre: nombre.trim(),
          email: correoNormalizado,
          passwordHash: hashPassword(password)
        };
        usuarios.set(correoNormalizado, nuevoUsuario);

        const token = createToken({
          id: nuevoUsuario.id,
          nombre: nuevoUsuario.nombre,
          email: nuevoUsuario.email
        });

        return enviarRespuesta(res, 201, {
          mensaje: 'Usuario registrado exitosamente',
          token,
          usuario: {
            id: nuevoUsuario.id,
            nombre: nuevoUsuario.nombre,
            email: nuevoUsuario.email
          }
        });
      } catch (err) {
        return enviarRespuesta(res, err.codigo || 500, {
          error: 'Error en registro',
          detail: err.mensaje || 'Error interno del servidor'
        });
      }
    }

    // POST /api/auth/login
    if (pathname === '/api/auth/login' && metodo === 'POST') {
      try {
        const cuerpo = await leerCuerpoJson(req);
        const { email, password } = cuerpo;

        if (!email || !password) {
          return enviarRespuesta(res, 400, {
            error: 'Solicitud incompleta',
            detail: 'Debe ingresar correo y contraseña.'
          });
        }

        const usuario = usuarios.get(email.toLowerCase().trim());
        if (!usuario || !verifyPassword(password, usuario.passwordHash)) {
          return enviarRespuesta(res, 401, {
            error: 'Credenciales inválidas',
            detail: 'El correo o la contraseña son incorrectos.'
          });
        }

        const token = createToken({
          id: usuario.id,
          nombre: usuario.nombre,
          email: usuario.email
        });

        return enviarRespuesta(res, 200, {
          mensaje: 'Inicio de sesión exitoso',
          token,
          usuario: {
            id: usuario.id,
            nombre: usuario.nombre,
            email: usuario.email
          }
        });
      } catch (err) {
        return enviarRespuesta(res, err.codigo || 500, {
          error: 'Error al iniciar sesión',
          detail: err.mensaje || 'Error interno del servidor'
        });
      }
    }

    // GET /api/auth/perfil
    if (pathname === '/api/auth/perfil' && metodo === 'GET') {
      const usuarioAuth = requerirAutenticacion(req, res);
      if (!usuarioAuth) return;
      return enviarRespuesta(res, 200, {
        id: usuarioAuth.id,
        nombre: usuarioAuth.nombre,
        email: usuarioAuth.email
      });
    }

    // ==========================================================
    // RUTAS DE RECETAS (CRUD REMOTO)
    // ==========================================================

    // GET /api/recetas
    if (pathname === '/api/recetas' && metodo === 'GET') {
      const categoria = parsedUrl.searchParams.get('categoria');
      const busqueda = parsedUrl.searchParams.get('busqueda');

      let resultado = [...recetas];
      if (categoria && categoria !== 'Todas') {
        resultado = resultado.filter(
          (r) => r.categoria && r.categoria.toLowerCase() === categoria.toLowerCase()
        );
      }
      if (busqueda && busqueda.trim().length > 0) {
        const q = busqueda.toLowerCase().trim();
        resultado = resultado.filter(
          (r) =>
            r.titulo.toLowerCase().includes(q) ||
            r.descripcion.toLowerCase().includes(q) ||
            (r.ingredientes && r.ingredientes.some((i) => i.toLowerCase().includes(q)))
        );
      }

      return enviarRespuesta(res, 200, {
        total: resultado.length,
        recetas: resultado
      });
    }

    // GET /api/recetas/:id
    const matchGetId = pathname.match(/^\/api\/recetas\/([a-zA-Z0-9_-]+)$/);
    if (matchGetId && metodo === 'GET') {
      const id = matchGetId[1];
      const receta = recetas.find((r) => r.id === id);
      if (!receta) {
        return enviarRespuesta(res, 404, {
          error: 'Receta no encontrada',
          detail: `No existe ninguna receta con el identificador ${id}.`
        });
      }
      return enviarRespuesta(res, 200, receta);
    }

    // POST /api/recetas (Crear receta remota - protegido)
    if (pathname === '/api/recetas' && metodo === 'POST') {
      const usuarioAuth = requerirAutenticacion(req, res);
      if (!usuarioAuth) return;

      try {
        const cuerpo = await leerCuerpoJson(req);
        const {
          titulo,
          descripcion,
          categoria,
          tiempoMinutos,
          porciones,
          dificultad,
          calorias,
          ingredientes,
          instrucciones,
          imageUrl
        } = cuerpo;

        if (!titulo || typeof titulo !== 'string' || titulo.trim().length < 3) {
          return enviarRespuesta(res, 422, {
            error: 'Validación fallida',
            detail: 'El título de la receta debe tener al menos 3 caracteres.'
          });
        }
        if (!descripcion || typeof descripcion !== 'string' || descripcion.trim().length < 5) {
          return enviarRespuesta(res, 422, {
            error: 'Validación fallida',
            detail: 'La descripción es obligatoria y debe ser descriptiva.'
          });
        }
        if (!categoria || typeof categoria !== 'string') {
          return enviarRespuesta(res, 422, {
            error: 'Validación fallida',
            detail: 'La categoría es obligatoria.'
          });
        }

        const nuevaReceta = {
          id: `receta-${Date.now()}`,
          titulo: titulo.trim(),
          descripcion: descripcion.trim(),
          categoria: categoria.trim(),
          tiempoMinutos: Number(tiempoMinutos) || 20,
          porciones: Number(porciones) || 2,
          dificultad: dificultad || 'Fácil',
          calorias: Number(calorias) || 300,
          ingredientes: Array.isArray(ingredientes) && ingredientes.length > 0
            ? ingredientes.map((i) => String(i).trim())
            : ['Ingredientes frescos al gusto'],
          instrucciones: Array.isArray(instrucciones) && instrucciones.length > 0
            ? instrucciones.map((i) => String(i).trim())
            : ['Preparar y disfrutar caliente.'],
          imageUrl: imageUrl && typeof imageUrl === 'string' && imageUrl.startsWith('http')
            ? imageUrl
            : 'https://images.unsplash.com/photo-1495521821757-a1efb6729352?w=600',
          autorId: usuarioAuth.id,
          autorNombre: usuarioAuth.nombre,
          esRemota: true,
          creadoEn: new Date().toISOString()
        };

        // Agregar al inicio del catálogo
        recetas.unshift(nuevaReceta);

        return enviarRespuesta(res, 201, {
          mensaje: 'Receta creada exitosamente',
          receta: nuevaReceta
        });
      } catch (err) {
        return enviarRespuesta(res, err.codigo || 500, {
          error: 'Error al crear receta',
          detail: err.mensaje || 'Error interno del servidor'
        });
      }
    }

    // DELETE /api/recetas/:id (Eliminar receta - protegido)
    const matchDeleteId = pathname.match(/^\/api\/recetas\/([a-zA-Z0-9_-]+)$/);
    if (matchDeleteId && metodo === 'DELETE') {
      const usuarioAuth = requerirAutenticacion(req, res);
      if (!usuarioAuth) return;

      const id = matchDeleteId[1];
      const indice = recetas.findIndex((r) => r.id === id);
      if (indice === -1) {
        return enviarRespuesta(res, 404, {
          error: 'Receta no encontrada',
          detail: `No se encontró la receta ${id} para eliminar.`
        });
      }

      const eliminada = recetas.splice(indice, 1)[0];
      return enviarRespuesta(res, 200, {
        mensaje: 'Receta eliminada exitosamente del backend remoto',
        id: eliminada.id,
        titulo: eliminada.titulo
      });
    }

    // ==========================================================
    // RUTA DEL ASISTENTE DE IA CULINARIA
    // ==========================================================

    // POST /api/ai/chat
    if (pathname === '/api/ai/chat' && metodo === 'POST') {
      const usuarioAuth = requerirAutenticacion(req, res);
      if (!usuarioAuth) return;

      try {
        const cuerpo = await leerCuerpoJson(req);
        const { mensaje } = cuerpo;

        if (!mensaje || typeof mensaje !== 'string' || mensaje.trim().length === 0) {
          return enviarRespuesta(res, 422, {
            error: 'Validación fallida',
            detail: 'El mensaje para el asistente de IA no puede estar vacío.'
          });
        }

        const resultadoAi = procesarConsultaCulinaria(mensaje, recetas);

        return enviarRespuesta(res, 200, {
          respuesta: resultadoAi.respuesta,
          categoriaDetectada: resultadoAi.categoriaDetectada,
          sugerencias: resultadoAi.sugerencias || [],
          timestamp: new Date().toISOString()
        });
      } catch (err) {
        return enviarRespuesta(res, err.codigo || 500, {
          error: 'Error al consultar asistente',
          detail: err.mensaje || 'Error interno del servidor'
        });
      }
    }

    // Ruta no encontrada
    return enviarRespuesta(res, 404, {
      error: 'Ruta no encontrada',
      detail: `El endpoint ${metodo} ${pathname} no existe en este servidor.`
    });
  });
}

if (require.main === module) {
  const server = crearServidor();
  server.listen(PUERTO, () => {
    console.log(`👨‍🍳 Servidor ChefCraft iniciado exitosamente en http://localhost:${PUERTO}`);
    console.log(`Catálogo inicial: ${recetas.length} recetas disponibles`);
  });
}

module.exports = {
  crearServidor,
  recetas,
  usuarios
};
