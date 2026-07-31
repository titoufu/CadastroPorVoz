class Pessoa {
  final int? id;

  // Identificador único compartilhado entre os celulares.
  final String uuid;

  final String nome;
  final String cpf;
  final DateTime? dataNascimento;
  final String endereco;
  final String telefone;
  final String observacoes;
  final DateTime criadoEm;
  final String criadoPor;
  final DateTime? alteradoEm;
  final String? alteradoPor;
  final bool excluido;

  const Pessoa({
    this.id,
    required this.uuid,
    required this.nome,
    this.cpf = '',
    this.dataNascimento,
    required this.endereco,
    required this.telefone,
    required this.observacoes,
    required this.criadoEm,
    required this.criadoPor,
    this.alteradoEm,
    this.alteradoPor,
    this.excluido = false,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'nome': nome,
      'cpf': cpf,
      'data_nascimento': dataNascimento == null
          ? null
          : _formatarDataParaBanco(dataNascimento!),
      'endereco': endereco,
      'telefone': telefone,
      'observacoes': observacoes,
      'criado_em': criadoEm.toIso8601String(),
      'criado_por': criadoPor,
      'alterado_em': alteradoEm?.toIso8601String(),
      'alterado_por': alteradoPor,
      'excluido': excluido ? 1 : 0,
    };
  }

  factory Pessoa.fromMap(Map<String, Object?> map) {
    return Pessoa(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      nome: map['nome'] as String,
      cpf: map['cpf'] as String? ?? '',
      dataNascimento: _dataOpcional(map['data_nascimento']),
      endereco: map['endereco'] as String,
      telefone: map['telefone'] as String,
      observacoes: map['observacoes'] as String,
      criadoEm: DateTime.parse(map['criado_em'] as String),
      criadoPor: map['criado_por'] as String,
      alteradoEm: map['alterado_em'] == null
          ? null
          : DateTime.parse(map['alterado_em'] as String),
      alteradoPor: map['alterado_por'] as String?,
      excluido: (map['excluido'] as int? ?? 0) == 1,
    );
  }

  static String _formatarDataParaBanco(DateTime data) {
    final ano = data.year.toString().padLeft(4, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final dia = data.day.toString().padLeft(2, '0');

    return '$ano-$mes-$dia';
  }

  static DateTime? _dataOpcional(Object? valor) {
    if (valor == null) return null;

    final texto = valor.toString().trim();
    if (texto.isEmpty) return null;

    return DateTime.tryParse(texto);
  }
}
