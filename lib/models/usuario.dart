// Modelo de Patricio-CEDIA/exploraec-app, Sesión 8.
import '../services/api_exception.dart';

class Usuario {
  const Usuario({required this.id, required this.email});
  final int id;
  final String email;

  factory Usuario.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! int ||
        (json['id'] as int) <= 0 ||
        json['email'] is! String ||
        (json['email'] as String).isEmpty) {
      throw ApiException(
          'Respuesta inesperada del servidor al leer tu perfil.');
    }
    return Usuario(id: json['id'] as int, email: json['email'] as String);
  }
}
