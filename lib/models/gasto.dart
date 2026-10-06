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
}
