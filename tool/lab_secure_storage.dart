import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:exploraec/controllers/auth_controller.dart';
import 'package:exploraec/services/api_client.dart';
import 'package:exploraec/services/secure_token_storage.dart';

const _canal = MethodChannel('cedia_lab_resultados');
const _baseUrl = String.fromEnvironment('API_BASE_URL');
const _marcadorKey = 'lab_usuario_id';
const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    storageNamespace: 'cedia_s8_lab',
    resetOnError: false,
  ),
);
const _comunes = <String>[
  'memoria_inicial_vacia',
  'usuario_inicial_nulo',
  'me_validado',
  'usuario_presente',
  'autenticado',
  'token_igual_persistido',
  'usuario_id_coincide',
  'generacion_avanza',
];
const _errores = <String>[
  'error_configuracion',
  'error_almacen',
  'error_api',
  'error_timeout',
  'error_interno',
];
Map<String, bool> _medidas = {for (final key in _errores) key: false};
bool _enviado = false;

// Sin runApp, registro GetX ni ciclo onInit/onClose del controlador.
@pragma('vm:entry-point')
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      debugPrint = (String? message, {int? wrapWidth}) {};
      FlutterError.onError = (_) => unawaited(_fallar('error_interno'));
      PlatformDispatcher.instance.onError = (error, stack) {
        unawaited(_fallar(_clasificar(error)));
        return true;
      };
      try {
        final config = await _canal
            .invokeMapMethod<String, dynamic>('configuracion')
            .timeout(const Duration(seconds: 10));
        final fase = config?['fase'];
        if (config?.length != 1 ||
            !const ['guardar', 'restaurar', 'cerrar'].contains(fase)) {
          await _fallar('error_configuracion');
          return;
        }
        await _ejecutar(fase as String);
        await _emitir();
      } catch (error) {
        await _fallar(_clasificar(error));
      }
    },
    (error, stack) => unawaited(_fallar(_clasificar(error))),
    // No deja salir prints del controlador ni mensajes con respuestas HTTP.
    zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) {}),
  );
}

Future<void> _ejecutar(String fase) async {
  final datos = fase == 'guardar'
      ? jsonDecode(await File(
              '${(await getApplicationSupportDirectory()).path}/acceso-lab.json')
          .readAsString()) as Map
      : <String, dynamic>{};
  final username = datos['username'] as String? ?? '';
  final password = datos['password'] as String? ?? '';
  final claves = <String>[
    ..._comunes,
    if (fase == 'guardar') ...[
      'almacen_inicial_vacio',
      'token_no_vacio',
      'marcador_guardado',
    ] else
      'token_previo_no_vacio',
    if (fase == 'cerrar') ...[
      'jwt_memoria_nulo',
      'usuario_nulo',
      'autenticado_falso',
      'secure_token_nulo',
      'generacion_cierre_avanza',
    ],
  ];
  _medidas = {
    for (final key in claves) key: false,
    for (final key in _errores) key: false,
  };
  final uri = Uri.tryParse(_baseUrl);
  // Este arnés solo admite el backend de laboratorio del emulador.
  if (!Platform.isAndroid ||
      uri == null ||
      uri.scheme != 'http' ||
      uri.host != '10.0.2.2' ||
      uri.port != 8000 ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      (fase == 'guardar' && (username.isEmpty || password.isEmpty))) {
    _medidas['error_configuracion'] = true;
    return;
  }

  final dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));
  final api = ApiClient(dio: dio);
  final almacen = SecureTokenStorage(_storage);
  final auth = AuthController(api: api, almacen: almacen);
  final sonda = _SondaMe();
  dio.interceptors.add(sonda); // Observa HTTP real; no sustituye respuestas.
  try {
    final generacionInicial = api.generacionToken;
    _medidas['memoria_inicial_vacia'] = api.token == null;
    _medidas['usuario_inicial_nulo'] = auth.usuario.value == null;
    if (!_medidas['memoria_inicial_vacia']! ||
        !_medidas['usuario_inicial_nulo']!) {
      return;
    }
    final previo = await almacen.leer();
    final marcador = await _storage.read(key: _marcadorKey);
    if (fase == 'guardar') {
      _medidas['almacen_inicial_vacio'] = previo == null && marcador == null;
      if (!_medidas['almacen_inicial_vacio']!) return;
      await auth.iniciarSesion(username, password);
    } else {
      _medidas['token_previo_no_vacio'] = previo?.isNotEmpty == true;
      if (!_medidas['token_previo_no_vacio']! || marcador == null) return;
      await auth.restaurarSesion();
    }

    final persistido = await almacen.leer();
    final usuario = auth.usuario.value;
    final identidad = usuario?.id.toString();
    _medidas['me_validado'] = sonda.validado &&
        sonda.bearer == 'Bearer $persistido' &&
        persistido?.isNotEmpty == true;
    _medidas['usuario_presente'] = usuario != null;
    _medidas['autenticado'] = auth.estaAutenticado;
    _medidas['token_igual_persistido'] = persistido?.isNotEmpty == true &&
        persistido == api.token &&
        (fase == 'guardar' || persistido == previo);
    _medidas['usuario_id_coincide'] = identidad != null &&
        identidad == sonda.identidad &&
        (fase == 'guardar' || identidad == marcador);
    _medidas['generacion_avanza'] = api.generacionToken > generacionInicial;
    if (fase == 'guardar') {
      _medidas['token_no_vacio'] = api.token?.isNotEmpty == true;
    }
    // No guarda marcador ni cierra una sesión cuya restauración no se probó.
    if (!_comunes.every((key) => _medidas[key] == true)) return;
    if (fase == 'guardar') {
      await _storage.write(key: _marcadorKey, value: identidad!);
      _medidas['marcador_guardado'] =
          await _storage.read(key: _marcadorKey) == identidad;
    } else if (fase == 'cerrar') {
      final generacionAntesCierre = api.generacionToken;
      await auth.cerrarSesion();
      _medidas['jwt_memoria_nulo'] = api.token == null;
      _medidas['usuario_nulo'] = auth.usuario.value == null;
      _medidas['autenticado_falso'] = !auth.estaAutenticado;
      _medidas['secure_token_nulo'] = await almacen.leer() == null;
      _medidas['generacion_cierre_avanza'] =
          api.generacionToken > generacionAntesCierre;
      // El marcador permanece: conserva evidencia y bloquea sobrescrituras.
    }
  } finally {
    // Liberar HTTP no llama cerrarSesion ni toca el almacén persistente.
    dio.close(force: true);
  }
}

class _SondaMe extends Interceptor {
  bool validado = false;
  String? identidad;
  String? bearer;

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.method == 'GET' &&
        response.requestOptions.path == '/usuarios/me') {
      final data = response.data;
      final id = data is Map ? data['id'] : null;
      final cabecera = response.requestOptions.headers['Authorization'];
      identidad = id is int || id is String ? id.toString() : null;
      bearer = cabecera is String ? cabecera : null;
      validado = response.statusCode == 200 &&
          identidad?.isNotEmpty == true &&
          bearer?.startsWith('Bearer ') == true;
    }
    handler.next(response);
  }
}

String _clasificar(Object error) {
  if (error is TimeoutException) return 'error_timeout';
  if (error is MissingPluginException || error is PlatformException) {
    return 'error_almacen';
  }
  if (error is DioException || error is ApiException) return 'error_api';
  return 'error_interno';
}

Future<void> _fallar(String categoria) async {
  _medidas[categoria] = true;
  await _emitir();
}

Future<void> _emitir() async {
  if (_enviado) return;
  _enviado = true;
  final comprobaciones =
      _medidas.entries.where((entry) => !_errores.contains(entry.key)).toList();
  final ok = comprobaciones.isNotEmpty &&
      comprobaciones.every((entry) => entry.value) &&
      _errores.every((key) => _medidas[key] == false);
  try {
    await _canal.invokeMethod<void>('resultados', {'ok': ok, ..._medidas});
  } catch (_) {
    // El timeout nativo dará el fallo; nunca imprime mensajes de excepciones.
  }
}
