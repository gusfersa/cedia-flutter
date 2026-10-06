// Configuración del laboratorio CEDIA; cada dispositivo alcanza otro host.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  // 1 ms permite comprobar el timeout; el valor normal de entrega es 15 s.
  static const int timeoutMs = int.fromEnvironment(
    'API_TIMEOUT_MS',
    defaultValue: 15000,
  );

  static const bool labPruebas = bool.fromEnvironment('LAB_PRUEBAS');
}
