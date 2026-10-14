// Adaptado de Patricio-CEDIA/exploraec-app, referencia académica sesión 09.
// Solo totales por categoría: no serializa filas, correo, fechas ni token.
const categoriasAsistente = <String>[
  'comida',
  'transporte',
  'entretenimiento',
  'otros',
];

/// Cota de transporte, distinta del límite de negocio (500 en el backend).
const double montoMaximoAsistente = 1000000;

double _importe(Object? dato, {double maximo = montoMaximoAsistente}) {
  if (dato is! num || !dato.isFinite || dato < 0 || dato > maximo) {
    throw const FormatException('Importe inválido en el resumen de gastos.');
  }
  return dato.toDouble();
}

class ResumenCategoria {
  final String categoria;
  final double total;
  final int cantidad;
  final double disponible;

  const ResumenCategoria({
    required this.categoria,
    required this.total,
    required this.cantidad,
    required this.disponible,
  });

  factory ResumenCategoria.fromJson(Map<String, dynamic> json) {
    final categoria = json['categoria'];
    final cantidad = json['cantidad'];
    if (!categoriasAsistente.contains(categoria) ||
        cantidad is! int ||
        cantidad < 0 ||
        cantidad > 1000000) {
      throw const FormatException(
          'Categoría o cantidad inválida en el resumen.');
    }
    return ResumenCategoria(
      categoria: categoria as String,
      total: _importe(json['total']),
      cantidad: cantidad,
      disponible: _importe(json['disponible']),
    );
  }

  Map<String, dynamic> toJson() => {
        'categoria': categoria,
        'total': total,
        'cantidad': cantidad,
        'disponible': disponible,
      };
}

class ResumenGastos {
  final List<ResumenCategoria> categorias;
  final double totalGeneral;

  const ResumenGastos({required this.categorias, required this.totalGeneral});

  factory ResumenGastos.fromJson(Map<String, dynamic> json) {
    final filas = json['categorias'];
    if (filas is! List || filas.length > categoriasAsistente.length) {
      throw const FormatException('El resumen no contiene categorías válidas.');
    }
    final categorias = <ResumenCategoria>[];
    final vistas = <String>{};
    for (final fila in filas) {
      if (fila is! Map<String, dynamic>) {
        throw const FormatException('Fila inválida en el resumen de gastos.');
      }
      final categoria = ResumenCategoria.fromJson(fila);
      if (!vistas.add(categoria.categoria)) {
        throw const FormatException('Categoría repetida en el resumen.');
      }
      categorias.add(categoria);
    }
    final total =
        _importe(json['total_general'], maximo: montoMaximoAsistente * 4);
    final suma = categorias.fold<double>(0, (s, c) => s + c.total);
    if ((suma - total).abs() > 0.01) {
      throw const FormatException(
          'El total del resumen no coincide con las categorías.');
    }
    return ResumenGastos(
      categorias: List.unmodifiable(categorias),
      totalGeneral: total,
    );
  }

  Map<String, dynamic> toJson() => {
        'categorias': categorias.map((c) => c.toJson()).toList(),
        'total_general': totalGeneral,
      };
}
