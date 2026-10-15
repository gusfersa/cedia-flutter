// Transporte falso del contrato S8/S9; los controladores y Hive son reales.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exploraec/controllers/auth_controller.dart';
import 'package:exploraec/controllers/gastos_controller.dart';
import 'package:exploraec/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

Map<String, dynamic> gastoS10(int id, String categoria, {double monto = 5}) => {
      'id': id,
      'descripcion': 'Gasto fixture $id',
      'categoria': categoria,
      'monto': monto,
      'fecha': '2026-10-15',
    };

class ServidorSesion10 implements HttpClientAdapter {
  final porUsuario = <int, List<Map<String, dynamic>>>{
    1: [gastoS10(1, 'comida', monto: 6), gastoS10(2, 'transporte', monto: 3)],
    2: [gastoS10(90, 'otros', monto: 12)],
  };
  final consultas = <({int usuario, int skip, int limit})>[];
  final _cuentas = <String, int>{
    'uno@example.test': 1,
    'dos@example.test': 2,
  };
  bool sinRed = false;
  int codigoLista = 200;
  int codigoGuardar = 201;
  int? limitePagina;
  int _siguienteId = 1000;

  ResponseBody _json(Object? datos, int codigo,
          [Map<String, List<String>> headers = const {}]) =>
      ResponseBody.fromString(datos == null ? '' : jsonEncode(datos), codigo,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
            ...headers,
          });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? cuerpo,
      Future<void>? cancelar) async {
    final texto = cuerpo == null
        ? ''
        : utf8.decode((await cuerpo.toList()).expand((x) => x).toList());
    if (o.path == '/usuarios/token' && o.method == 'POST') {
      final campos = Uri.splitQueryString(texto);
      final id = _cuentas[campos['username']];
      if (id == null || campos['password'] != 'clave-fixture') {
        return _json({'detail': 'Credenciales de prueba incorrectas'}, 401);
      }
      return _json({'access_token': 'sesion10-fixture-$id'}, 200);
    }
    final cabecera = o.headers['Authorization'];
    final id = switch (cabecera) {
      'Bearer sesion10-fixture-1' => 1,
      'Bearer sesion10-fixture-2' => 2,
      _ => null,
    };
    if (id == null) return _json({'detail': 'Sesión de prueba inválida'}, 401);
    if (o.path == '/usuarios/me') {
      return _json({
        'id': id,
        'email': _cuentas.entries.singleWhere((e) => e.value == id).key,
      }, 200);
    }
    if (o.path == '/gastos/categorias') {
      return _json({
        'categorias': ['comida', 'transporte', 'entretenimiento', 'otros'],
        'limite_por_categoria': 500,
      }, 200);
    }
    final propios = porUsuario[id]!;
    if (o.path == '/gastos/' && o.method == 'GET') {
      if (sinRed) {
        throw DioException.connectionError(
            requestOptions: o, reason: 'Red fixture desconectada');
      }
      if (codigoLista != 200) {
        return _json({'detail': 'Fallo de lista de prueba'}, codigoLista);
      }
      final skip = int.parse('${o.queryParameters['skip']}');
      final limit = int.parse('${o.queryParameters['limit']}');
      consultas.add((usuario: id, skip: skip, limit: limit));
      final efectivos =
          limitePagina == null || limitePagina! > limit ? limit : limitePagina!;
      return _json(propios.skip(skip).take(efectivos).toList(), 200, {
        'x-total-count': ['${propios.length}'],
      });
    }
    if (o.path == '/gastos/' && o.method == 'POST') {
      if (codigoGuardar != 201) {
        return _json(
            {'detail': 'El gasto supera el límite de prueba'}, codigoGuardar);
      }
      final nuevo = {
        ...gastoS10(_siguienteId++, 'otros'),
        ...jsonDecode(texto) as Map<String, dynamic>,
      };
      propios.add(nuevo);
      return _json(nuevo, 201);
    }
    final coincidencia = RegExp(r'^/gastos/(\d+)$').firstMatch(o.path);
    if (coincidencia != null) {
      final gastoId = int.parse(coincidencia.group(1)!);
      final indice = propios.indexWhere((g) => g['id'] == gastoId);
      if (indice == -1) return _json({'detail': 'Gasto no encontrado'}, 404);
      if (o.method == 'PATCH') {
        propios[indice] = {
          ...propios[indice],
          ...jsonDecode(texto) as Map<String, dynamic>,
        };
        return _json(propios[indice], 200);
      }
      if (o.method == 'DELETE') {
        propios.removeAt(indice);
        return _json(null, 204);
      }
    }
    return _json({'detail': 'Ruta no implementada en el fixture'}, 404);
  }

  @override
  void close({bool force = false}) {}
}

class EntornoSesion10 {
  EntornoSesion10._(this.servidor, this.api, this.auth, this.gastos);

  final ServidorSesion10 servidor;
  final ApiClient api;
  final AuthController auth;
  final GastosController gastos;

  static Future<EntornoSesion10> crear({ServidorSesion10? servidor}) async {
    Get.reset();
    Get.testMode = true;
    // Solo almacenamiento seguro simulado y datos sintéticos; no usa llavero.
    FlutterSecureStorage.setMockInitialValues({});
    Hive.init(Directory.systemTemp.createTempSync('exploraec_s10_').path);
    final backend = servidor ?? ServidorSesion10();
    final api = Get.put(ApiClient(
        dio: Dio(BaseOptions(baseUrl: 'http://fixture.invalid'))
          ..httpClientAdapter = backend));
    final auth = Get.put(AuthController(api: api));
    await auth.restauracion;
    final gastos = Get.put(GastosController(auth: auth));
    return EntornoSesion10._(backend, api, auth, gastos);
  }

  Future<void> entrar([String correo = 'uno@example.test']) async {
    await auth.iniciarSesion(correo, 'clave-fixture');
    await gastos.inicioPendiente;
  }

  List<Object?> get idsCache =>
      (Hive.box<dynamic>('gastos_${auth.usuario.value!.id}').get('gastos')
              as List)
          .map((g) => (g as Map)['id'])
          .toList();

  Future<void> cerrar() async {
    gastos.onClose();
    await gastos.cierrePendiente;
    auth.onClose();
    await auth.cierrePendiente;
    api.dispose();
    Get.reset();
    await Hive.close();
    // Se conservan los directorios temporales: no se borran archivos.
  }
}
