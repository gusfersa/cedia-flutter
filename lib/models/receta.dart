class Receta {
  final String id;
  final String titulo;
  final String descripcion;
  final String categoria;
  final int tiempoMinutos;
  final int porciones;
  final String dificultad;
  final int calorias;
  final List<String> ingredientes;
  final List<String> instrucciones;
  final String imageUrl;
  final String autorId;
  final String autorNombre;
  final bool esRemota;
  final String creadoEn;

  Receta({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.categoria,
    required this.tiempoMinutos,
    required this.porciones,
    required this.dificultad,
    required this.calorias,
    required this.ingredientes,
    required this.instrucciones,
    required this.imageUrl,
    required this.autorId,
    required this.autorNombre,
    this.esRemota = true,
    required this.creadoEn,
  });

  factory Receta.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic list) {
      if (list is List) {
        return list.map((item) => item.toString()).toList();
      }
      return [];
    }

    return Receta(
      id: json['id']?.toString() ?? '',
      titulo: json['titulo']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      categoria: json['categoria']?.toString() ?? 'General',
      tiempoMinutos: (json['tiempoMinutos'] is num)
          ? (json['tiempoMinutos'] as num).toInt()
          : int.tryParse(json['tiempoMinutos']?.toString() ?? '20') ?? 20,
      porciones: (json['porciones'] is num)
          ? (json['porciones'] as num).toInt()
          : int.tryParse(json['porciones']?.toString() ?? '2') ?? 2,
      dificultad: json['dificultad']?.toString() ?? 'Fácil',
      calorias: (json['calorias'] is num)
          ? (json['calorias'] as num).toInt()
          : int.tryParse(json['calorias']?.toString() ?? '250') ?? 250,
      ingredientes: parseList(json['ingredientes']),
      instrucciones: parseList(json['instrucciones']),
      imageUrl: json['imageUrl']?.toString() ??
          'https://images.unsplash.com/photo-1495521821757-a1efb6729352?w=600',
      autorId: json['autorId']?.toString() ?? 'sistema',
      autorNombre: json['autorNombre']?.toString() ?? 'Chef',
      esRemota: json['esRemota'] == true || json['esRemota'] == null,
      creadoEn: json['creadoEn']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'categoria': categoria,
      'tiempoMinutos': tiempoMinutos,
      'porciones': porciones,
      'dificultad': dificultad,
      'calorias': calorias,
      'ingredientes': ingredientes,
      'instrucciones': instrucciones,
      'imageUrl': imageUrl,
      'autorId': autorId,
      'autorNombre': autorNombre,
      'esRemota': esRemota,
      'creadoEn': creadoEn,
    };
  }

  // Soporte directo para mapas de almacenamiento en Hive
  Map<String, dynamic> toMap() => toJson();

  factory Receta.fromMap(Map<dynamic, dynamic> map) {
    return Receta.fromJson(Map<String, dynamic>.from(map));
  }

  Receta copyWith({
    String? id,
    String? titulo,
    String? descripcion,
    String? categoria,
    int? tiempoMinutos,
    int? porciones,
    String? dificultad,
    int? calorias,
    List<String>? ingredientes,
    List<String>? instrucciones,
    String? imageUrl,
    String? autorId,
    String? autorNombre,
    bool? esRemota,
    String? creadoEn,
  }) {
    return Receta(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      categoria: categoria ?? this.categoria,
      tiempoMinutos: tiempoMinutos ?? this.tiempoMinutos,
      porciones: porciones ?? this.porciones,
      dificultad: dificultad ?? this.dificultad,
      calorias: calorias ?? this.calorias,
      ingredientes: ingredientes ?? this.ingredientes,
      instrucciones: instrucciones ?? this.instrucciones,
      imageUrl: imageUrl ?? this.imageUrl,
      autorId: autorId ?? this.autorId,
      autorNombre: autorNombre ?? this.autorNombre,
      esRemota: esRemota ?? this.esRemota,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }
}
