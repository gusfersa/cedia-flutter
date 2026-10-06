import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:exploraec/config/api_config.dart';
import 'package:exploraec/models/gasto.dart';
import 'package:exploraec/services/api_exception.dart';
import 'package:exploraec/services/gastos_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Contrato real: registro JSON, login formulario y lista Bearer paginada',
      () async {
    final peticiones = <http.Request>[];
    final api = GastosApiService(
      baseUrl: 'http://servidor.test:8000/',
      cliente: MockClient((peticion) async {
        peticiones.add(peticion);
        if (peticion.url.path == '/usuarios/') return http.Response('{}', 201);
        if (peticion.url.path == '/usuarios/token') {
          return http.Response('{"access_token":"jwt-sintetico"}', 200);
        }
        return http.Response(
          '[{"id":1,"descripcion":"Almuerzo en Quito","monto":6.5,'
          '"categoria":"comida","fecha":"2026-10-05"}]',
          200,
          headers: {'x-total-count': '23', 'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.dispose);
    expect(api.tieneToken, isFalse);
    expect(api.plazo, const Duration(seconds: 15));
    expect(ApiConfig.timeoutMs, 15000);
    await api.registrar('alumno+prueba@example.test', 'clave de prueba');
    await api.login('alumno+prueba@example.test', 'clave de prueba');
    final resultado = await api.listarGastos(skip: 20, limit: 3);
    expect(peticiones.map((p) => p.url.path),
        ['/usuarios/', '/usuarios/token', '/gastos/']);
    expect(peticiones.map((p) => p.method), ['POST', 'POST', 'GET']);
    expect(peticiones[0].headers['content-type'], 'application/json');
    expect(jsonDecode(peticiones[0].body), {
      'email': 'alumno+prueba@example.test',
      'password': 'clave de prueba',
    });
    expect(peticiones[1].headers['content-type'],
        startsWith('application/x-www-form-urlencoded'));
    expect(Uri.splitQueryString(peticiones[1].body), {
      'username': 'alumno+prueba@example.test',
      'password': 'clave de prueba',
    });
    expect(peticiones[2].headers['Authorization'], 'Bearer jwt-sintetico');
    expect(peticiones[2].url.queryParameters, {'skip': '20', 'limit': '3'});
    expect(resultado.total, 23, reason: 'El total viene de la cabecera');
    expect(resultado.gastos.single.monto, 6.5);
    api.cerrarSesion();
    expect(api.tieneToken, isFalse);
    await expectLater(
        api.listarGastos(),
        throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'código', 401)));
    expect(peticiones, hasLength(3), reason: 'No envía peticiones sin token');
  });

  test('Gasto acepta entero/decimal y campos ausentes o incompatibles', () {
    expect(Gasto.fromJson({'monto': 6}).monto, 6.0);
    expect(Gasto.fromJson({'monto': 6.5}).monto, 6.5);
    final gasto = Gasto.fromJson({
      'id': 'incompatible',
      'descripcion': 4,
      'monto': 'incompatible',
      'categoria': null,
      'fecha': [],
    });
    expect(gasto.id, 0);
    expect(gasto.descripcion, 'Sin descripción');
    expect(gasto.monto, 0);
    expect(gasto.categoria, 'otros');
    expect(gasto.fecha, '');
  });

  for (final codigo in [400, 403, 404]) {
    test('HTTP $codigo conserva el detail legible del servidor', () async {
      final api = GastosApiService(
          cliente: MockClient((_) async => http.Response(
              '{"detail":"Petición de práctica rechazada"}', codigo,
              headers: {'content-type': 'application/json'})));
      addTearDown(api.dispose);
      await expectLater(
          api.registrar('alumno@example.test', 'clave-prueba'),
          throwsA(isA<ApiException>()
              .having((e) => e.statusCode, 'código', codigo)
              .having((e) => e.mensaje, 'mensaje',
                  'Petición de práctica rechazada')));
    });
  }

  test('HTTP 401 y 500 tienen mensajes distintos y legibles', () async {
    var codigo = 401;
    final api = GastosApiService(
        cliente: MockClient(
            (_) async => http.Response('cuerpo técnico omitido', codigo)));
    addTearDown(api.dispose);
    await expectLater(
        api.registrar('alumno@example.test', 'clave-prueba'),
        throwsA(isA<ApiException>()
            .having((e) => e.mensaje, 'sesión', contains('Tu sesión caducó'))));
    codigo = 500;
    await expectLater(
        api.registrar('alumno@example.test', 'clave-prueba'),
        throwsA(isA<ApiException>().having((e) => e.mensaje, 'servidor',
            'El servidor tuvo un problema. Inténtalo más tarde.')));
  });

  test('HTTP 422 señala el campo sin mostrar JSON crudo', () async {
    final api = GastosApiService(
        cliente: MockClient((_) async => http.Response(
            '{"detail":[{"loc":["body","password"],'
            '"msg":"String should have at least 8 characters",'
            '"type":"string_too_short","ctx":{"min_length":8}}]}',
            422,
            headers: {'content-type': 'application/json'})));
    addTearDown(api.dispose);
    await expectLater(
        api.registrar('nuevo@example.test', 'abc'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'código', 422)
            .having((e) => e.mensaje, 'campo',
                'Datos inválidos — contraseña: Debe tener al menos 8 caracteres')));
  });

  test('Validaciones traducen contexto, correo, números y tipos desconocidos',
      () async {
    final casos = [
      (
        {
          'type': 'string_too_long',
          'ctx': {'max_length': 72}
        },
        'contraseña: Debe tener como máximo 72 caracteres',
        'password'
      ),
      ({'type': 'missing'}, 'correo: Este campo es obligatorio', 'email'),
      ({'type': 'value_error'}, 'correo: Ingresa un correo válido', 'email'),
      ({'type': 'float_parsing'}, 'monto: Escribe un número válido', 'monto'),
      (
        {'type': 'tipo_desconocido'},
        'contraseña: Revisa este valor',
        'password'
      ),
    ];
    for (final (error, esperado, campo) in casos) {
      final api = GastosApiService(
          cliente: MockClient((_) async => http.Response(
              jsonEncode({
                'detail': [
                  {
                    ...error,
                    'loc': ['body', campo],
                    'msg': 'Untranslated server message',
                  }
                ]
              }),
              422,
              headers: {'content-type': 'application/json'})));
      try {
        await expectLater(
            api.registrar('alumno@example.test', 'clave-prueba'),
            throwsA(isA<ApiException>()
                .having((e) => e.mensaje, 'validación', contains(esperado))
                .having((e) => e.mensaje, 'sin mensaje crudo',
                    isNot(contains('Untranslated')))));
      } finally {
        api.dispose();
      }
    }
  });

  for (final error in [
    const SocketException('sensor de conexión de prueba'),
    http.ClientException('conexión de prueba'),
  ]) {
    test('${error.runtimeType} se traduce a mensaje de conexión', () async {
      final api =
          GastosApiService(cliente: MockClient((_) async => throw error));
      addTearDown(api.dispose);
      await expectLater(
          api.registrar('alumno@example.test', 'clave-prueba'),
          throwsA(isA<ApiException>().having((e) => e.mensaje, 'conexión',
              startsWith('No hay conexión con el servidor.'))));
    });
  }

  test('Timeout real de 1 ms se traduce y puede restaurarse a 15 s', () async {
    var demora = false;
    final api = GastosApiService(cliente: MockClient((_) async {
      if (demora) await Future<void>.delayed(const Duration(milliseconds: 20));
      return http.Response('{}', 201);
    }));
    addTearDown(api.dispose);
    api.configurarTimeoutParaPruebas(const Duration(milliseconds: 1));
    demora = true;
    await expectLater(
        api.registrar('alumno@example.test', 'clave-prueba'),
        throwsA(isA<ApiException>().having((e) => e.mensaje, 'timeout',
            startsWith('El servidor tardó demasiado'))));
    api.configurarTimeoutParaPruebas(const Duration(seconds: 15));
    expect(api.plazo, const Duration(seconds: 15));
    await api.registrar('alumno@example.test', 'clave-prueba');
    expect(() => api.configurarTimeoutParaPruebas(Duration.zero),
        throwsArgumentError);
  });

  test('Respuestas JSON inválidas o token ausente fallan con mensaje legible',
      () async {
    var cuerpo = 'respuesta sin JSON';
    final api = GastosApiService(
        cliente: MockClient((_) async => http.Response(cuerpo, 200)));
    addTearDown(api.dispose);
    await expectLater(
        api.login('alumno@example.test', 'clave-prueba'),
        throwsA(isA<ApiException>()
            .having((e) => e.mensaje, 'JSON', contains('JSON inválida'))));
    cuerpo = '{}';
    await expectLater(
        api.login('alumno@example.test', 'clave-prueba'),
        throwsA(isA<ApiException>()
            .having((e) => e.mensaje, 'token', contains('al iniciar sesión'))));
    expect(api.tieneToken, isFalse);
  });

  test('Cerrar sesión impide que un login tardío restaure el token', () async {
    final respuesta = Completer<http.Response>();
    final api = GastosApiService(cliente: MockClient((_) => respuesta.future));
    addTearDown(api.dispose);
    final login = api.login('alumno@example.test', 'clave-prueba');
    api.cerrarSesion();
    respuesta.complete(http.Response('{"access_token":"jwt-tardio"}', 200));
    await login;
    expect(api.tieneToken, isFalse);
  });
}
