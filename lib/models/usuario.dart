class Usuario {
  final dynamic id;
  final String nombre;
  final String email;
  final String? token;

  const Usuario({
    required this.id,
    this.nombre = '',
    required this.email,
    this.token,
  });

  factory Usuario.fromJson(Map<String, dynamic> json, {String? token}) {
    return Usuario(
      id: json['id'] ?? '',
      nombre: json['nombre']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      token: token ?? json['token']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      if (token != null) 'token': token,
    };
  }

  Usuario copyWith({
    dynamic id,
    String? nombre,
    String? email,
    String? token,
  }) {
    return Usuario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      token: token ?? this.token,
    );
  }
}
