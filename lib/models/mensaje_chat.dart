class MensajeChat {
  final String id;
  final String texto;
  final bool esUsuario;
  final DateTime timestamp;
  final List<String> sugerencias;

  MensajeChat({
    required this.id,
    required this.texto,
    required this.esUsuario,
    required this.timestamp,
    this.sugerencias = const [],
  });

  factory MensajeChat.delUsuario(String texto) {
    return MensajeChat(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      texto: texto,
      esUsuario: true,
      timestamp: DateTime.now(),
    );
  }

  factory MensajeChat.delAsistente(String texto, {List<String> sugerencias = const []}) {
    return MensajeChat(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      texto: texto,
      esUsuario: false,
      timestamp: DateTime.now(),
      sugerencias: sugerencias,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'texto': texto,
      'esUsuario': esUsuario,
      'timestamp': timestamp.toIso8601String(),
      'sugerencias': sugerencias,
    };
  }

  factory MensajeChat.fromJson(Map<String, dynamic> json) {
    return MensajeChat(
      id: json['id']?.toString() ?? '',
      texto: json['texto']?.toString() ?? '',
      esUsuario: json['esUsuario'] == true,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sugerencias: json['sugerencias'] is List
          ? (json['sugerencias'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }
}
