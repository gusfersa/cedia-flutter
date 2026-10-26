import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'package:exploraec/controllers/asistente_controller.dart';
import 'package:exploraec/controllers/auth_controller.dart';
import 'package:exploraec/controllers/favoritos_controller.dart';
import 'package:exploraec/controllers/recetas_controller.dart';
import 'package:exploraec/models/mensaje_chat.dart';
import 'package:exploraec/models/receta.dart';
import 'package:exploraec/models/usuario.dart';
import 'package:exploraec/services/ai_assistant_service.dart';
import 'package:exploraec/services/api_client.dart';
import 'package:exploraec/services/auth_service.dart';
import 'package:exploraec/services/recetas_service.dart';
import 'package:exploraec/widgets/empty_view.dart';
import 'package:exploraec/widgets/error_view.dart';
import 'package:exploraec/widgets/loading_view.dart';
import 'package:exploraec/widgets/receta_card.dart';

// Fakes y Mocks para pruebas sin red externa
class FakeBox implements Box {
  final Map<dynamic, dynamic> _datos = {};

  @override
  bool get isOpen => true;

  @override
  int get length => _datos.length;

  @override
  dynamic get(key, {defaultValue}) => _datos[key] ?? defaultValue;

  @override
  dynamic getAt(int index) => _datos.values.elementAt(index);

  @override
  Future<void> put(key, value) async => _datos[key] = value;

  @override
  Future<void> delete(key) async => _datos.remove(key);

  @override
  Future<int> clear() async {
    final c = _datos.length;
    _datos.clear();
    return c;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRecetasService extends RecetasService {
  final List<Receta> recetasSimuladas;
  bool debeFallar = false;
  int codigoFallo = 500;

  FakeRecetasService(this.recetasSimuladas);

  @override
  Future<List<Receta>> getRecetas({String? categoria, String? busqueda}) async {
    if (debeFallar) {
      throw ApiException('Fallo simulado en servidor', statusCode: codigoFallo);
    }
    var res = [...recetasSimuladas];
    if (categoria != null && categoria != 'Todas') {
      res = res.where((r) => r.categoria == categoria).toList();
    }
    if (busqueda != null && busqueda.isNotEmpty) {
      final q = busqueda.toLowerCase();
      res = res.where((r) => r.titulo.toLowerCase().contains(q)).toList();
    }
    return res;
  }

  @override
  Future<Receta> crearReceta(Receta receta) async {
    if (debeFallar) {
      throw ApiException('Error de validación', statusCode: 422);
    }
    final nueva = receta.copyWith(id: 'receta-sim-${DateTime.now().millisecondsSinceEpoch}');
    recetasSimuladas.insert(0, nueva);
    return nueva;
  }

  @override
  Future<void> eliminarReceta(String id) async {
    if (debeFallar) {
      throw ApiException('No autorizado', statusCode: 401);
    }
    recetasSimuladas.removeWhere((r) => r.id == id);
  }
}

class FakeAuthService extends AuthService {
  Usuario? usuarioActual;
  bool debeFallar = false;

  @override
  Future<Usuario> login({required String email, required String password}) async {
    if (debeFallar || password != 'segura123') {
      throw ApiException('Credenciales inválidas', statusCode: 401);
    }
    usuarioActual = Usuario(id: 'usr-1', nombre: 'Test Chef', email: email, token: 'fake-jwt');
    return usuarioActual!;
  }

  @override
  Future<Usuario> register({required String nombre, required String email, required String password}) async {
    if (debeFallar) {
      throw ApiException('El correo ya existe', statusCode: 400);
    }
    usuarioActual = Usuario(id: 'usr-2', nombre: nombre, email: email, token: 'fake-jwt-reg');
    return usuarioActual!;
  }

  @override
  Future<Usuario?> getPerfil() async => usuarioActual;

  @override
  Future<void> logout() async => usuarioActual = null;
}

class FakeAiService extends AiAssistantService {
  @override
  Future<Map<String, dynamic>> consultarAsistente(String mensaje) async {
    return {
      'respuesta': 'Te recomiendo preparar un ceviche con camarones frescos.',
      'sugerencias': ['¿Cuánto tiempo toma?', '¿Qué acompañamiento uso?'],
      'categoriaDetectada': 'ingredientes',
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Modelos de Datos ChefCraft', () {
    test('Receta serializa y deserializa en JSON correctamente', () {
      final r = Receta(
        id: 'r-1',
        titulo: 'Ceviche de Camarón',
        descripcion: 'Fresco y delicioso',
        categoria: 'Almuerzo',
        tiempoMinutos: 25,
        porciones: 4,
        dificultad: 'Fácil',
        calorias: 280,
        ingredientes: ['Camarones', 'Limón', 'Cebolla'],
        instrucciones: ['Cocinar camarones', 'Encurtir cebolla'],
        imageUrl: 'https://ejemplo.com/ceviche.jpg',
        autorId: 'usr-01',
        autorNombre: 'Chef Juan',
        creadoEn: '2026-10-26T00:00:00Z',
      );

      final json = r.toJson();
      final reconstruida = Receta.fromJson(json);

      expect(reconstruida.id, 'r-1');
      expect(reconstruida.titulo, 'Ceviche de Camarón');
      expect(reconstruida.ingredientes.length, 3);
      expect(reconstruida.instrucciones.length, 2);
      expect(reconstruida.esRemota, true);
    });

    test('Usuario serializa y deserializa correctamente', () {
      final u = Usuario(id: 'u-1', nombre: 'Chef María', email: 'maria@chef.ec', token: 'jwt-123');
      final json = u.toJson();
      final u2 = Usuario.fromJson(json);

      expect(u2.id, 'u-1');
      expect(u2.nombre, 'Chef María');
      expect(u2.email, 'maria@chef.ec');
      expect(u2.token, 'jwt-123');
    });

    test('MensajeChat crea mensajes de usuario y asistente', () {
      final mUser = MensajeChat.delUsuario('¿Qué cocino hoy?');
      expect(mUser.esUsuario, true);
      expect(mUser.texto, '¿Qué cocino hoy?');

      final mAi = MensajeChat.delAsistente('Prepara un risotto', sugerencias: ['Ver receta']);
      expect(mAi.esUsuario, false);
      expect(mAi.sugerencias.length, 1);
    });
  });

  group('Controlador GetX: RecetasController', () {
    late FakeRecetasService fakeService;
    late RecetasController controller;

    setUp(() {
      Get.reset();
      fakeService = FakeRecetasService([
        Receta(
          id: '1',
          titulo: 'Bolón de Verde',
          descripcion: 'Tradicional',
          categoria: 'Desayuno',
          tiempoMinutos: 20,
          porciones: 2,
          dificultad: 'Fácil',
          calorias: 400,
          ingredientes: ['Verde', 'Queso'],
          instrucciones: ['Freír y majar'],
          imageUrl: 'url',
          autorId: 'admin',
          autorNombre: 'Admin',
          creadoEn: 'hoy',
        ),
        Receta(
          id: '2',
          titulo: 'Seco de Pollo',
          descripcion: 'Con cerveza',
          categoria: 'Almuerzo',
          tiempoMinutos: 45,
          porciones: 4,
          dificultad: 'Media',
          calorias: 500,
          ingredientes: ['Pollo', 'Cerveza'],
          instrucciones: ['Guisar'],
          imageUrl: 'url',
          autorId: 'admin',
          autorNombre: 'Admin',
          creadoEn: 'hoy',
        ),
      ]);
      controller = RecetasController(recetasService: fakeService);
    });

    test('Carga inicial trae las recetas remotas', () async {
      await controller.cargarRecetas();
      expect(controller.recetas.length, 2);
      expect(controller.isLoading.value, false);
      expect(controller.hasError.value, false);
    });

    test('Filtra recetas por categoría reactivamente', () async {
      await controller.cargarRecetas();
      controller.cambiarCategoria('Desayuno');
      await Future.delayed(Duration.zero);

      expect(controller.recetas.length, 1);
      expect(controller.recetas.first.titulo, 'Bolón de Verde');
    });

    test('Busca recetas por coincidencia de texto', () async {
      await controller.cargarRecetas();
      controller.buscar('Pollo');
      await Future.delayed(Duration.zero);

      expect(controller.recetas.length, 1);
      expect(controller.recetas.first.titulo, 'Seco de Pollo');
    });

    test('Manejo de errores explícito registra statusCode', () async {
      fakeService.debeFallar = true;
      fakeService.codigoFallo = 401;

      await controller.cargarRecetas();
      expect(controller.hasError.value, true);
      expect(controller.statusCodeError.value, 401);
      expect(controller.errorMessage.value, contains('Fallo simulado'));
    });

    test('Creación y eliminación remota de receta', () async {
      fakeService.debeFallar = false;
      await controller.cargarRecetas();

      final exito = await controller.crearReceta(
        Receta(
          id: '',
          titulo: 'Pancake Saludable',
          descripcion: 'Con avena',
          categoria: 'Desayuno',
          tiempoMinutos: 10,
          porciones: 1,
          dificultad: 'Fácil',
          calorias: 200,
          ingredientes: ['Avena'],
          instrucciones: ['Cocinar'],
          imageUrl: 'url',
          autorId: 'yo',
          autorNombre: 'Yo',
          creadoEn: 'hoy',
        ),
      );

      expect(exito, true);
      expect(controller.recetas.length, 3);
      expect(controller.recetas.first.titulo, 'Pancake Saludable');

      final idEliminar = controller.recetas.first.id;
      final exitoEliminar = await controller.eliminarReceta(idEliminar);
      expect(exitoEliminar, true);
      expect(controller.recetas.length, 2);
    });
  });

  group('Controlador GetX: FavoritosController (Hive)', () {
    late FakeBox fakeBox;
    late FavoritosController favController;

    setUp(() {
      Get.reset();
      fakeBox = FakeBox();
      favController = FavoritosController(box: fakeBox);
    });

    test('Toggle agrega y quita de favoritos en la caja Hive', () async {
      final r = Receta(
        id: 'fav-1',
        titulo: 'Sopa de Calabaza',
        descripcion: 'Cremosa',
        categoria: 'Cena',
        tiempoMinutos: 30,
        porciones: 4,
        dificultad: 'Fácil',
        calorias: 220,
        ingredientes: ['Calabaza'],
        instrucciones: ['Hervir'],
        imageUrl: 'url',
        autorId: 'a',
        autorNombre: 'Chef',
        creadoEn: 'hoy',
      );

      expect(favController.esFavorito('fav-1'), false);

      await favController.toggleFavorito(r);
      expect(favController.esFavorito('fav-1'), true);
      expect(favController.favoritos.length, 1);
      expect(fakeBox.length, 1);

      // Segundo toggle lo quita
      await favController.toggleFavorito(r);
      expect(favController.esFavorito('fav-1'), false);
      expect(favController.favoritos.isEmpty, true);
      expect(fakeBox.length, 0);
    });
  });

  group('Controlador GetX: AuthController', () {
    late FakeAuthService fakeAuth;
    late AuthController authController;

    setUp(() {
      Get.reset();
      fakeAuth = FakeAuthService();
      authController = AuthController(authService: fakeAuth);
    });

    test('Inicio de sesión exitoso guarda usuario en estado reactivo', () async {
      expect(authController.isAuthenticated, false);

      final ok = await authController.login('test@chefcraft.ec', 'segura123');
      expect(ok, true);
      expect(authController.isAuthenticated, true);
      expect(authController.usuario.value?.email, 'test@chefcraft.ec');

      await authController.logout();
      expect(authController.isAuthenticated, false);
      expect(authController.usuario.value, null);
    });

    test('Inicio de sesión fallido almacena mensaje de error', () async {
      final ok = await authController.login('test@chefcraft.ec', 'clave_erronea');
      expect(ok, false);
      expect(authController.isAuthenticated, false);
      expect(authController.errorMessage.value, contains('inválidas'));
    });
  });

  group('Controlador GetX: AsistenteController', () {
    test('Envía consulta y añade respuesta del Chef IA', () async {
      Get.reset();
      final controller = AsistenteController(aiService: FakeAiService());

      expect(controller.mensajes.length, 1); // Mensaje de bienvenida
      await controller.enviarMensaje('¿Qué hago con camarones?');

      expect(controller.mensajes.length, 3); // Bienvenida + Usuario + Chef IA
      expect(controller.mensajes[1].esUsuario, true);
      expect(controller.mensajes[2].esUsuario, false);
      expect(controller.mensajes[2].texto, contains('ceviche'));
      expect(controller.isThinking.value, false);
    });
  });

  group('Widgets de Experiencia de Usuario (Carga, Vacío, Error)', () {
    testWidgets('LoadingView renderiza spinner y mensaje', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingView(mensaje: 'Buscando recetas...'))),
      );

      expect(find.text('Buscando recetas...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('EmptyView renderiza título, mensaje y botón', (tester) async {
      var pulsado = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyView(
              titulo: 'Sin recetas',
              mensaje: 'Intenta con otro filtro',
              textoBoton: 'Reiniciar',
              onAccion: () => pulsado = true,
            ),
          ),
        ),
      );

      expect(find.text('Sin recetas'), findsOneWidget);
      expect(find.text('Intenta con otro filtro'), findsOneWidget);
      expect(find.text('Reiniciar'), findsOneWidget);

      await tester.tap(find.text('Reiniciar'));
      expect(pulsado, true);
    });

    testWidgets('ErrorView muestra código HTTP 401 y botón de reintentar', (tester) async {
      var reintentado = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              statusCode: 401,
              mensaje: 'Sesión caducada',
              onReintentar: () => reintentado = true,
            ),
          ),
        ),
      );

      expect(find.text('Código HTTP: 401'), findsOneWidget);
      expect(find.text('Sesión no autorizada o caducada'), findsOneWidget);
      expect(find.text('Sesión caducada'), findsOneWidget);

      await tester.tap(find.text('Reintentar conexión'));
      expect(reintentado, true);
    });

    testWidgets('RecetaCard muestra título, tiempo, calorías y categoría', (tester) async {
      Get.reset();
      Get.put<FavoritosController>(FavoritosController(box: FakeBox()));

      final recetaPrueba = Receta(
        id: 'test-card-1',
        titulo: 'Tacos de Salmón',
        descripcion: 'Deliciosos tacos crujientes',
        categoria: 'Cena',
        tiempoMinutos: 15,
        porciones: 2,
        dificultad: 'Fácil',
        calorias: 320,
        ingredientes: ['Salmón', 'Tortillas'],
        instrucciones: ['Asar salmón'],
        imageUrl: 'https://ejemplo.com/taco.jpg',
        autorId: 'chef',
        autorNombre: 'Chef',
        creadoEn: 'hoy',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RecetaCard(receta: recetaPrueba)),
        ),
      );

      expect(find.text('Tacos de Salmón'), findsOneWidget);
      expect(find.text('Cena'), findsOneWidget);
      expect(find.text('15 min'), findsOneWidget);
      expect(find.text('320 kcal'), findsOneWidget);
      expect(find.text('Fácil'), findsOneWidget);
    });
  });
}
