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
  final String criadoPorUid;

  final DateTime? alteradoEm;
  final String? alteradoPor;

  // Indica se há uma demanda atual em acompanhamento.
  final bool ativo;

  // Indica que o registro é inválido e foi excluído do sistema.
  final bool excluido;

  // Necessário para a remoção física após 30 dias.
  final DateTime? excluidoEm;

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
    required this.criadoPorUid,
    this.alteradoEm,
    this.alteradoPor,
    this.ativo = true,
    this.excluido = false,
    this.excluidoEm,
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
      'criado_por_uid': criadoPorUid,
      'alterado_em': alteradoEm?.toIso8601String(),
      'alterado_por': alteradoPor,
      'ativo': ativo ? 1 : 0,
      'excluido': excluido ? 1 : 0,
      'excluido_em': excluidoEm?.toIso8601String(),
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
      criadoPorUid: map['criado_por_uid'] as String,
      alteradoEm: _dataOpcional(map['alterado_em']),
      alteradoPor: map['alterado_por'] as String?,
      ativo: (map['ativo'] as int? ?? 1) == 1,
      excluido: (map['excluido'] as int? ?? 0) == 1,
      excluidoEm: _dataOpcional(map['excluido_em']),
    );
  }

  Pessoa copyWith({
    int? id,
    String? uuid,
    String? nome,
    String? cpf,
    DateTime? dataNascimento,
    String? endereco,
    String? telefone,
    String? observacoes,
    DateTime? criadoEm,
    String? criadoPor,
    String? criadoPorUid,
    DateTime? alteradoEm,
    String? alteradoPor,
    bool? ativo,
    bool? excluido,
    DateTime? excluidoEm,
  }) {
    return Pessoa(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      nome: nome ?? this.nome,
      cpf: cpf ?? this.cpf,
      dataNascimento: dataNascimento ?? this.dataNascimento,
      endereco: endereco ?? this.endereco,
      telefone: telefone ?? this.telefone,
      observacoes: observacoes ?? this.observacoes,
      criadoEm: criadoEm ?? this.criadoEm,
      criadoPor: criadoPor ?? this.criadoPor,
      criadoPorUid: criadoPorUid ?? this.criadoPorUid,
      alteradoEm: alteradoEm ?? this.alteradoEm,
      alteradoPor: alteradoPor ?? this.alteradoPor,
      ativo: ativo ?? this.ativo,
      excluido: excluido ?? this.excluido,
      excluidoEm: excluidoEm ?? this.excluidoEm,
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

    if (texto.isEmpty) {
      return null;
    }

    return DateTime.tryParse(texto);
  }
}