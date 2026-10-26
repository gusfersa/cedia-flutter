'use strict';

const { test, describe, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { crearServidor } = require('../server');

let servidor;
let puerto;
let urlBase;
let tokenValido;
let usuarioValido;

function peticion(metodo, ruta, cuerpo = null, token = null) {
  return new Promise((resolve, reject) => {
    const cabeceras = {
      'Content-Type': 'application/json'
    };
    if (token) {
      cabeceras['Authorization'] = `Bearer ${token}`;
    }

    const payload = cuerpo ? JSON.stringify(cuerpo) : null;
    if (payload) {
      cabeceras['Content-Length'] = Buffer.byteLength(payload);
    }

    const req = http.request(
      `${urlBase}${ruta}`,
      {
        method: metodo,
        headers: cabeceras
      },
      (res) => {
        let datos = '';
        res.on('data', (trozo) => (datos += trozo));
        res.on('end', () => {
          let json = null;
          try {
            if (datos) json = JSON.parse(datos);
          } catch {
            json = datos;
          }
          resolve({ status: res.statusCode, headers: res.headers, body: json });
        });
      }
    );

    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

describe('Suite de Pruebas del Backend ChefCraft', () => {
  before(async () => {
    servidor = crearServidor();
    await new Promise((resolve) => {
      servidor.listen(0, () => {
        puerto = servidor.address().port;
        urlBase = `http://127.0.0.1:${puerto}`;
        resolve();
      });
    });
  });

  after(async () => {
    await new Promise((resolve) => servidor.close(resolve));
  });

  test('GET /health responde 200 con estado de salud y recetas cargadas', async () => {
    const res = await peticion('GET', '/health');
    assert.equal(res.status, 200);
    assert.equal(res.body.estado, 'ok');
    assert.ok(res.body.recetasRegistradas >= 18);
  });

  describe('Autenticación y Control de Acceso', () => {
    test('POST /api/auth/register registra un nuevo usuario correctamente (201)', async () => {
      const res = await peticion('POST', '/api/auth/register', {
        nombre: 'Patricio Estrella',
        email: 'patricio@chefcraft.ec',
        password: 'contrasenaSegura123'
      });
      assert.equal(res.status, 201);
      assert.ok(res.body.token);
      assert.equal(res.body.usuario.email, 'patricio@chefcraft.ec');

      tokenValido = res.body.token;
      usuarioValido = res.body.usuario;
    });

    test('POST /api/auth/register rechaza correo duplicado con 400', async () => {
      const res = await peticion('POST', '/api/auth/register', {
        nombre: 'Patricio Clon',
        email: 'patricio@chefcraft.ec',
        password: 'otraPassword456'
      });
      assert.equal(res.status, 400);
      assert.match(res.body.error, /ya registrado/i);
    });

    test('POST /api/auth/register valida campos inválidos con 422', async () => {
      const resCorto = await peticion('POST', '/api/auth/register', {
        nombre: 'A',
        email: 'correo-invalido',
        password: '123'
      });
      assert.equal(resCorto.status, 422);
    });

    test('POST /api/auth/login inicia sesión exitosamente (200)', async () => {
      const res = await peticion('POST', '/api/auth/login', {
        email: 'patricio@chefcraft.ec',
        password: 'contrasenaSegura123'
      });
      assert.equal(res.status, 200);
      assert.ok(res.body.token);
      assert.equal(res.body.usuario.nombre, 'Patricio Estrella');
    });

    test('POST /api/auth/login rechaza contraseña errónea con 401', async () => {
      const res = await peticion('POST', '/api/auth/login', {
        email: 'patricio@chefcraft.ec',
        password: 'clave_incorrecta'
      });
      assert.equal(res.status, 401);
      assert.match(res.body.error, /inválidas/i);
    });

    test('POST /api/auth/login rechaza petición sin datos con 400', async () => {
      const res = await peticion('POST', '/api/auth/login', {});
      assert.equal(res.status, 400);
    });

    test('GET /api/auth/perfil rechaza sin token con 401', async () => {
      const res = await peticion('GET', '/api/auth/perfil');
      assert.equal(res.status, 401);
    });

    test('GET /api/auth/perfil permite acceso con token válido (200)', async () => {
      const res = await peticion('GET', '/api/auth/perfil', null, tokenValido);
      assert.equal(res.status, 200);
      assert.equal(res.body.email, 'patricio@chefcraft.ec');
    });
  });

  describe('Catálogo y CRUD Remoto de Recetas', () => {
    test('GET /api/recetas devuelve al menos 18 recetas iniciales', async () => {
      const res = await peticion('GET', '/api/recetas');
      assert.equal(res.status, 200);
      assert.ok(res.body.recetas.length >= 18);
      assert.equal(res.body.total, res.body.recetas.length);
    });

    test('GET /api/recetas?categoria=Desayuno filtra por categoría', async () => {
      const res = await peticion('GET', '/api/recetas?categoria=Desayuno');
      assert.equal(res.status, 200);
      assert.ok(res.body.recetas.length > 0);
      res.body.recetas.forEach((r) => assert.equal(r.categoria, 'Desayuno'));
    });

    test('GET /api/recetas?busqueda=camaron busca en título, descripción e ingredientes', async () => {
      const res = await peticion('GET', '/api/recetas?busqueda=camaron');
      assert.equal(res.status, 200);
      assert.ok(res.body.recetas.length >= 1);
      assert.ok(res.body.recetas[0].titulo.includes('Camarón'));
    });

    test('GET /api/recetas/:id devuelve 404 para receta inexistente', async () => {
      const res = await peticion('GET', '/api/recetas/id-inventado-9999');
      assert.equal(res.status, 404);
    });

    let recetaCreadaId;

    test('POST /api/recetas rechaza creación sin autenticación (401)', async () => {
      const res = await peticion('POST', '/api/recetas', {
        titulo: 'Tarta Sin Permiso',
        descripcion: 'Intento sin token',
        categoria: 'Postre'
      });
      assert.equal(res.status, 401);
    });

    test('POST /api/recetas valida datos incompletos con 422', async () => {
      const res = await peticion('POST', '/api/recetas', { titulo: 'Ab' }, tokenValido);
      assert.equal(res.status, 422);
    });

    test('POST /api/recetas crea una nueva receta remota con token (201)', async () => {
      const res = await peticion(
        'POST',
        '/api/recetas',
        {
          titulo: 'Pizza Margarita Artesanal',
          descripcion: 'Masa madre fermentada 24 horas con salsa pomodoro y albahaca fresca.',
          categoria: 'Cena',
          tiempoMinutos: 35,
          porciones: 3,
          dificultad: 'Media',
          calorias: 550,
          ingredientes: ['300g harina de fuerza', '200g mozzarella fresca', 'Hojas de albahaca'],
          instrucciones: ['Estirar masa', 'Colocar ingredientes', 'Hornear a máxima temperatura 10 min']
        },
        tokenValido
      );

      assert.equal(res.status, 201);
      assert.ok(res.body.receta.id);
      assert.equal(res.body.receta.titulo, 'Pizza Margarita Artesanal');
      assert.equal(res.body.receta.autorId, usuarioValido.id);

      recetaCreadaId = res.body.receta.id;
    });

    test('DELETE /api/recetas/:id rechaza eliminación sin token con 401', async () => {
      const res = await peticion('DELETE', `/api/recetas/${recetaCreadaId}`);
      assert.equal(res.status, 401);
    });

    test('DELETE /api/recetas/:id elimina la receta creada con token (200)', async () => {
      const res = await peticion('DELETE', `/api/recetas/${recetaCreadaId}`, null, tokenValido);
      assert.equal(res.status, 200);
      assert.equal(res.body.id, recetaCreadaId);

      // Comprobar que ya no existe
      const resBusqueda = await peticion('GET', `/api/recetas/${recetaCreadaId}`);
      assert.equal(resBusqueda.status, 404);
    });
  });

  describe('Asistente de IA Culinaria (Servidor Propio)', () => {
    test('POST /api/ai/chat rechaza sin token con 401', async () => {
      const res = await peticion('POST', '/api/ai/chat', { mensaje: 'Hola' });
      assert.equal(res.status, 401);
    });

    test('POST /api/ai/chat valida mensaje vacío con 422', async () => {
      const res = await peticion('POST', '/api/ai/chat', { mensaje: '   ' }, tokenValido);
      assert.equal(res.status, 422);
    });

    test('POST /api/ai/chat responde consulta culinaria contextualizada (200)', async () => {
      const res = await peticion(
        'POST',
        '/api/ai/chat',
        { mensaje: '¿Qué puedo cocinar si tengo camarones y cebolla?' },
        tokenValido
      );
      assert.equal(res.status, 200);
      assert.ok(res.body.respuesta);
      assert.match(res.body.respuesta, /Ceviche|camarones/i);
    });

    test('POST /api/ai/chat sugiere desayunos saludables', async () => {
      const res = await peticion(
        'POST',
        '/api/ai/chat',
        { mensaje: 'Recomiéndame un desayuno saludable para mañana' },
        tokenValido
      );
      assert.equal(res.status, 200);
      assert.ok(res.body.respuesta);
      assert.equal(res.body.categoriaDetectada, 'Desayuno');
    });
  });
});
