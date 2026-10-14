// Modelo académico basado en Patricio-CEDIA/exploraec-app, sesión 06.
class Gasto {
  final int id;
  final String descripcion;
  final double monto;
  final String categoria;
  final String fecha;

  const Gasto({
    required this.id,
    required this.descripcion,
    required this.monto,
    required this.categoria,
    required this.fecha,
  });

  /// Los campos ausentes o incompatibles tienen un valor de reserva.
  factory Gasto.fromJson(Map<String, dynamic> json) => Gasto(
        id: json['id'] is num ? (json['id'] as num).toInt() : 0,
        descripcion: json['descripcion'] is String
            ? json['descripcion'] as String
            : 'Sin descripción',
        monto: json['monto'] is num ? (json['monto'] as num).toDouble() : 0,
        categoria:
            json['categoria'] is String ? json['categoria'] as String : 'otros',
        fecha: json['fecha'] is String ? json['fecha'] as String : '',
      );

  /// Serialización manual para la caché de Hive — Sesión 7. Los 5 campos son
  /// primitivos; no hace falta un `TypeAdapter` generado. Mismos nombres que
  /// el JSON del backend.
  Map<String, dynamic> toMap() => {
        'id': id,
        'descripcion': descripcion,
        'monto': monto,
        'categoria': categoria,
        'fecha': fecha,
      };

  /// Hive devuelve mapas con claves dinámicas; se copian a `Map<String, dynamic>`.
  factory Gasto.fromMap(Map<dynamic, dynamic> mapa) =>
      Gasto.fromJson(Map<String, dynamic>.from(mapa));
}
