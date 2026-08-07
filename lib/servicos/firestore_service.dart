import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelos/pessoa.dart';

class FirestoreService {
  FirestoreService._();

  static final FirestoreService instancia = FirestoreService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _pessoas {
    return _firestore.collection('pessoas');
  }

  /// Marca um cadastro existente como excluído.
  ///
  /// A exclusão exige conexão com o Firestore. O método retorna a data
  /// registrada pelo servidor para que o SQLite utilize a mesma data.
  Future<DateTime> excluirPessoa(String uuid) async {
    final referencia = _pessoas.doc(uuid);

    await _firestore.runTransaction((transacao) async {
      final documento = await transacao.get(referencia);

      if (!documento.exists) {
        throw StateError(
          'O cadastro não foi encontrado no servidor.',
        );
      }

      final dados = documento.data();
      final jaExcluido = dados?['excluido'] as bool? ?? false;

      if (jaExcluido) {
        return;
      }

      transacao.update(referencia, {
        'ativo': false,
        'excluido': true,
        'excluidoEm': FieldValue.serverTimestamp(),
        'alteradoEm': FieldValue.serverTimestamp(),
      });
    });

    // A leitura direta do servidor garante que recebemos o timestamp
    // já resolvido, e não o valor local provisório.
    final documentoAtualizado = await referencia.get(
      const GetOptions(source: Source.server),
    );

    final dadosAtualizados = documentoAtualizado.data();
    final excluidoEm = dadosAtualizados?['excluidoEm'];

    if (excluidoEm is! Timestamp) {
      throw StateError(
        'A exclusão foi registrada, mas a data não pôde ser confirmada.',
      );
    }

    return excluidoEm.toDate();
  }

  /// Salva uma pessoa ativa ou inativa.
  ///
  /// Cadastros excluídos devem ser tratados somente por excluirPessoa().
  Future<void> salvarPessoa(Pessoa pessoa) async {
    if (pessoa.excluido) {
      throw ArgumentError(
        'Use excluirPessoa() para excluir um cadastro.',
      );
    }

    if (pessoa.criadoPorUid.trim().isEmpty) {
      throw ArgumentError(
        'O UID do criador do cadastro não foi informado.',
      );
    }

    final referencia = _pessoas.doc(pessoa.uuid);

    await _firestore.runTransaction((transacao) async {
      final documentoAtual = await transacao.get(referencia);

      if (documentoAtual.exists) {
        final dadosAtuais = documentoAtual.data();

        final excluidoNoServidor =
            dadosAtuais?['excluido'] as bool? ?? false;

        if (excluidoNoServidor) {
          throw StateError(
            'Este cadastro foi excluído e não pode mais ser alterado.',
          );
        }

        final criadoPorUidNoServidor =
            (dadosAtuais?['criadoPorUid'] as String? ?? '').trim();

        if (criadoPorUidNoServidor.isNotEmpty &&
            criadoPorUidNoServidor != pessoa.criadoPorUid) {
          throw StateError(
            'O responsável original pelo cadastro não pode ser alterado.',
          );
        }
      }

      transacao.set(referencia, {
        'uuid': pessoa.uuid,
        'nome': pessoa.nome,
        'cpf': pessoa.cpf,
        'dataNascimento': pessoa.dataNascimento == null
            ? null
            : _formatarData(pessoa.dataNascimento!),
        'endereco': pessoa.endereco,
        'telefone': pessoa.telefone,
        'observacoes': pessoa.observacoes,
        'criadoEm': Timestamp.fromDate(pessoa.criadoEm),
        'criadoPor': pessoa.criadoPor,
        'criadoPorUid': pessoa.criadoPorUid,
        'alteradoEm': pessoa.alteradoEm == null
            ? null
            : Timestamp.fromDate(pessoa.alteradoEm!),
        'alteradoPor': pessoa.alteradoPor,
        'ativo': pessoa.ativo,
        'excluido': false,
        'excluidoEm': null,
      });
    });
  }

  /// Retorna todos os cadastros não excluídos.
  ///
  /// Este é o método mais adequado para sincronizar o Firestore com
  /// o SQLite, pois inclui tanto ativos quanto inativos.
  Future<List<Pessoa>> listarPessoasNaoExcluidas() async {
    final consulta = await _pessoas
        .where('excluido', isEqualTo: false)
        .get();

    return consulta.docs.map(_pessoaDoDocumento).toList();
  }

  Future<List<Pessoa>> listarPessoasAtivas() async {
    final consulta = await _pessoas
        .where('ativo', isEqualTo: true)
        .where('excluido', isEqualTo: false)
        .get();

    return consulta.docs.map(_pessoaDoDocumento).toList();
  }

  Future<List<Pessoa>> listarPessoasInativas() async {
    final consulta = await _pessoas
        .where('ativo', isEqualTo: false)
        .where('excluido', isEqualTo: false)
        .get();

    return consulta.docs.map(_pessoaDoDocumento).toList();
  }

  /// Retorna ativos, inativos e excluídos.
  ///
  /// Deve ser usado apenas quando for realmente necessário analisar
  /// todos os documentos.
  Future<List<Pessoa>> listarTodasPessoas() async {
    final consulta = await _pessoas.get();

    return consulta.docs.map(_pessoaDoDocumento).toList();
  }

  /// Retorna os tombstones de exclusão, incluindo a data original.
  Future<List<Pessoa>> listarPessoasExcluidas() async {
    final consulta = await _pessoas
        .where('excluido', isEqualTo: true)
        .get();

    return consulta.docs.map(_pessoaDoDocumento).toList();
  }

  Pessoa _pessoaDoDocumento(
    DocumentSnapshot<Map<String, dynamic>> documento,
  ) {
    final dados = documento.data();

    if (dados == null) {
      throw StateError(
        'O documento ${documento.id} não possui dados.',
      );
    }

    final criadoEm = _lerTimestamp(dados['criadoEm']);
    final alteradoEm = _lerTimestamp(dados['alteradoEm']);
    final excluidoEm = _lerTimestamp(dados['excluidoEm']);

    return Pessoa(
      uuid: documento.id,
      nome: dados['nome'] as String? ?? '',
      cpf: dados['cpf'] as String? ?? '',
      dataNascimento: _lerDataNascimento(
        dados['dataNascimento'],
      ),
      endereco: dados['endereco'] as String? ?? '',
      telefone: dados['telefone'] as String? ?? '',
      observacoes: dados['observacoes'] as String? ?? '',
      criadoEm: criadoEm ?? DateTime.now(),
      criadoPor: dados['criadoPor'] as String? ?? '',
      criadoPorUid: dados['criadoPorUid'] as String? ?? '',
      alteradoEm: alteradoEm,
      alteradoPor: dados['alteradoPor'] as String?,
      ativo: dados['ativo'] as bool? ?? true,
      excluido: dados['excluido'] as bool? ?? false,
      excluidoEm: excluidoEm,
    );
  }

  static DateTime? _lerTimestamp(Object? valor) {
    if (valor is Timestamp) {
      return valor.toDate();
    }

    if (valor is DateTime) {
      return valor;
    }

    if (valor == null) {
      return null;
    }

    return DateTime.tryParse(valor.toString());
  }

  static String _formatarData(DateTime data) {
    final ano = data.year.toString().padLeft(4, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final dia = data.day.toString().padLeft(2, '0');

    return '$ano-$mes-$dia';
  }

  static DateTime? _lerDataNascimento(Object? valor) {
    if (valor == null) {
      return null;
    }

    if (valor is Timestamp) {
      final data = valor.toDate();

      return DateTime(
        data.year,
        data.month,
        data.day,
      );
    }

    return DateTime.tryParse(valor.toString());
  }
}