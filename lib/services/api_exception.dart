/// Un error de red o HTTP traducido para la interfaz.
class ApiException implements Exception {
  final String mensaje;
  final int? statusCode;

  ApiException(this.mensaje, {this.statusCode});

  @override
  String toString() => mensaje;
}
