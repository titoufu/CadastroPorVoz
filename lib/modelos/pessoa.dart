class Pessoa {
  final int? id;

  // Identificador único compartilhado entre os celulares.
  final String uuid;

  final String nome;
  final String endereco;
  final String telefone;
  final String observacoes;
  final DateTime criadoEm;
  final String criadoPor;
  final DateTime? alteradoEm;
  final String? alteradoPor;

  const Pessoa({
    this.id,
    required this.uuid,
    required this.nome,
    required this.endereco,
    required this.telefone,
    required this.observacoes,
    required this.criadoEm,
    required this.criadoPor,
    this.alteradoEm,
    this.alteradoPor,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'nome': nome,
      'endereco': endereco,
      'telefone': telefone,
      'observacoes': observacoes,
      'criado_em': criadoEm.toIso8601String(),
      'criado_por': criadoPor,
      'alterado_em': alteradoEm?.toIso8601String(),
      'alterado_por': alteradoPor,
    };
  }

  factory Pessoa.fromMap(Map<String, Object?> map) {
    return Pessoa(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      nome: map['nome'] as String,
      endereco: map['endereco'] as String,
      telefone: map['telefone'] as String,
      observacoes: map['observacoes'] as String,
      criadoEm: DateTime.parse(map['criado_em'] as String),
      criadoPor: map['criado_por'] as String,
      alteradoEm: map['alterado_em'] == null
          ? null
          : DateTime.parse(map['alterado_em'] as String),
      alteradoPor: map['alterado_por'] as String?,
    );
  }
}