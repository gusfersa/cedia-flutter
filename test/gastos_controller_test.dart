import 'dart:async';

import 'package:exploraec/controllers/gastos_controller.dart';
import 'package:exploraec/controllers/places_controller.dart' show EstadoCarga;
import 'package:exploraec/services/gastos_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _unGasto = '[{"id":1,"descripcion":"Almuerzo en Quito","monto":6.5,'
    '"categoria":"comida","fecha":"2026-10-05"}]';

void main() {
  test('Await encadena registro, login, lista y rechaza una doble entrada',
      () async {
    final registro = Completer<http.Response>();
    final login = Completer<http.Response>();
    final lista = Completer<http.Response>();
    final pasos = <String>[];
    final api = GastosApiService(cliente: MockClient((peticion) {
      pasos.add(peticion.url.path);
      return switch (peticion.url.path) {
        '/usuarios/' => registro.future,
        '/usuarios/token' => login.future,
        _ => lista.future,
      };
    }));
    final controller = GastosController(api: api);
    addTearDown(controller.onClose);
    final entrada = controller.entrar('alumno@example.test', 'clave-prueba');
    await controller.entrar('otra@example.test', 'clave-prueba');
    await Future<void>.delayed(Duration.zero);
    expect(controller.autenticando.value, isTrue);
    expect(pasos, ['/usuarios/']);
    registro.complete(http.Response('{}', 201));
    await Future<void>.delayed(Duration.zero);
    expect(pasos, ['/usuarios/', '/usuarios/token']);
    expect(controller.sesionActiva.value, isFalse);
    login.complete(http.Response('{"access_token":"jwt-sintetico"}', 200));
    await Future<void>.delayed(Duration.zero);
    expect(controller.sesionActiva.value, isTrue);
    expect(controller.estado.value, EstadoCarga.cargando);
    lista.complete(http.Response('[]', 200, headers: {'x-total-count': '0'}));
    await entrada;
    expect(pasos, ['/usuarios/', '/usuarios/token', '/gastos/']);
    expect(controller.estado.value, EstadoCarga.exito);
    expect(controller.gastos, isEmpty);
    expect(controller.totalEnServidor.value, 0);
    expect(controller.autenticando.value, isFalse);
  });

  test('Registro 400 permite login; error de red conserva lista y reintenta',
      () async {
    var desconectado = false;
    final api = GastosApiService(cliente: MockClient((peticion) async {
      if (peticion.url.path == '/usuarios/') {
        return http.Response('{"detail":"Correo ya registrado"}', 400);
      }
      if (peticion.url.path == '/usuarios/token') {
        return http.Response('{"access_token":"jwt-sintetico"}', 200);
      }
      if (desconectado) throw http.ClientException('conexión de prueba');
      return http.Response(_unGasto, 200, headers: {'x-total-count': '1'});
    }));
    final controller = GastosController(api: api);
    addTearDown(controller.onClose);
    await controller.entrar('alumno@example.test', 'clave-prueba');
    expect(controller.sesionActiva.value, isTrue);
    desconectado = true;
    await controller.cargarGastos();
    expect(controller.estado.value, EstadoCarga.error);
    expect(controller.gastos.single.descripcion, 'Almuerzo en Quito');
    expect(controller.totalEnServidor.value, 1);
    expect(controller.mensajeError.value, contains('No hay conexión'));
    desconectado = false;
    await controller.cargarGastos();
    expect(controller.estado.value, EstadoCarga.exito);
    expect(controller.mensajeError.value, isEmpty);
  });

  test('401 vuelve al formulario y elimina el token; 422 no inicia sesión',
      () async {
    var registro422 = false;
    final api = GastosApiService(cliente: MockClient((peticion) async {
      if (peticion.url.path == '/usuarios/') {
        return registro422
            ? http.Response(
                '{"detail":[{"loc":["body","password"],'
                '"msg":"Contraseña demasiado corta"}]}',
                422,
                headers: {'content-type': 'application/json'})
            : http.Response('{}', 201);
      }
      if (peticion.url.path == '/usuarios/token') {
        return http.Response('{"access_token":"jwt-sintetico"}', 200);
      }
      return http.Response('{"detail":"Credenciales rechazadas"}', 401);
    }));
    final controller = GastosController(api: api);
    addTearDown(controller.onClose);
    await controller.entrar('alumno@example.test', 'clave-prueba');
    expect(controller.sesionActiva.value, isFalse);
    expect(controller.mensajeAuth.value, contains('Tu sesión caducó'));
    expect(api.tieneToken, isFalse);
    controller.salir();
    registro422 = true;
    await controller.entrar('nuevo@example.test', 'abc');
    expect(controller.sesionActiva.value, isFalse);
    expect(controller.mensajeAuth.value, contains('contraseña:'));
    expect(controller.autenticando.value, isFalse);
  });

  test('Paginación usa skip acumulado, total remoto y evita doble carga',
      () async {
    final segundaPagina = Completer<http.Response>();
    final saltos = <String>[];
    final api = GastosApiService(cliente: MockClient((peticion) async {
      if (peticion.url.path == '/usuarios/') return http.Response('{}', 201);
      if (peticion.url.path == '/usuarios/token') {
        return http.Response('{"access_token":"jwt-sintetico"}', 200);
      }
      saltos.add(peticion.url.queryParameters['skip']!);
      if (saltos.length > 1) return segundaPagina.future;
      return http.Response(_unGasto, 200, headers: {'x-total-count': '2'});
    }));
    final controller = GastosController(api: api);
    addTearDown(controller.onClose);
    await controller.entrar('alumno@example.test', 'clave-prueba');
    expect(controller.hayMas, isTrue);
    final carga = controller.cargarMas();
    await controller.cargarMas();
    await Future<void>.delayed(Duration.zero);
    expect(saltos, ['0', '1']);
    segundaPagina.complete(http.Response(
        '[{"id":2,"descripcion":"Taxi al terminal","monto":3.25}]', 200,
        headers: {'x-total-count': '2'}));
    await carga;
    expect(controller.gastos.map((gasto) => gasto.id), [1, 2]);
    expect(controller.totalEnServidor.value, 2);
    expect(controller.hayMas, isFalse);
    expect(controller.cargandoMas.value, isFalse);
    await controller.cargarMas();
    expect(saltos, hasLength(2));
  });

  for (final cierre in ['salir', 'onClose']) {
    test('Respuesta tardía tras $cierre no restaura datos ni sesión', () async {
      final lista = Completer<http.Response>();
      final api = GastosApiService(cliente: MockClient((peticion) async {
        if (peticion.url.path == '/usuarios/') return http.Response('{}', 201);
        if (peticion.url.path == '/usuarios/token') {
          return http.Response('{"access_token":"jwt-sintetico"}', 200);
        }
        return lista.future;
      }));
      final controller = GastosController(api: api);
      final entrada = controller.entrar('alumno@example.test', 'clave-prueba');
      await Future<void>.delayed(Duration.zero);
      if (cierre == 'salir') {
        controller.salir();
        addTearDown(controller.onClose);
      } else {
        controller.onClose();
      }
      lista.complete(http.Response(_unGasto, 200));
      await entrada;
      expect(controller.gastos, isEmpty);
      expect(api.tieneToken, isFalse);
      if (cierre == 'salir') expect(controller.sesionActiva.value, isFalse);
    });
  }
}
