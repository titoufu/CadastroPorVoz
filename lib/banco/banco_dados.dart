import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../modelos/pessoa.dart';

class BancoDados {
  BancoDados._();

  static final BancoDados instancia = BancoDados._();

  static Database? _banco;

  Future<Database> get banco async {
    _banco ??= await _abrirBanco();
    return _banco!;
  }

  Future<Database> _abrirBanco() async {
    final caminhoBanco = join(
      await getDatabasesPath(),
      'cadastro_por_voz.db',
    );

    return openDatabase(
      caminhoBanco,

      // Versão 5:
      // - acrescenta o estado ativo/inativo;
      // - mantém a exclusão lógica separada;
      // - registra a data da exclusão;
      // - mantém o UID do criador.
      //
      // Como o banco está vazio, a atualização recria a tabela
      // em vez de migrar registros anteriores.
      version: 5,

      onCreate: _criarEstrutura,

      onUpgrade: (db, versaoAntiga, versaoNova) async {
        if (versaoAntiga < 5) {
          await db.execute('DROP TABLE IF EXISTS pessoas');
          await _criarEstrutura(db, versaoNova);
        }
      },
    );
  }

  static Future<void> _criarEstrutura(
    Database db,
    int version,
  ) async {
    await db.execute('''
      CREATE TABLE pessoas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL,
        nome TEXT NOT NULL,
        cpf TEXT NOT NULL DEFAULT '',
        data_nascimento TEXT,
        endereco TEXT NOT NULL,
        telefone TEXT NOT NULL,
        observacoes TEXT NOT NULL,
        criado_em TEXT NOT NULL,
        criado_por TEXT NOT NULL,
        criado_por_uid TEXT NOT NULL,
        alterado_em TEXT,
        alterado_por TEXT,
        ativo INTEGER NOT NULL DEFAULT 1,
        excluido INTEGER NOT NULL DEFAULT 0,
        excluido_em TEXT
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX idx_pessoas_uuid
      ON pessoas(uuid)
    ''');

    await db.execute('''
      CREATE INDEX idx_pessoas_cpf
      ON pessoas(cpf)
    ''');

    await db.execute('''
      CREATE INDEX idx_pessoas_nome_nascimento
      ON pessoas(nome COLLATE NOCASE, data_nascimento)
    ''');

    await db.execute('''
      CREATE INDEX idx_pessoas_situacao
      ON pessoas(ativo, excluido)
    ''');

    await db.execute('''
      CREATE INDEX idx_pessoas_excluido_em
      ON pessoas(excluido_em)
    ''');
  }

  Future<int> inserirPessoa(Pessoa pessoa) async {
    final db = await banco;

    return db.insert(
      'pessoas',
      pessoa.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Retorna somente cadastros ativos e não excluídos.
  Future<List<Pessoa>> listarPessoas() async {
    final db = await banco;

    final registros = await db.query(
      'pessoas',
      where: 'ativo = 1 AND excluido = 0',
      orderBy: 'nome COLLATE NOCASE',
    );

    return registros.map(Pessoa.fromMap).toList();
  }

  /// Retorna somente cadastros inativos e não excluídos.
  Future<List<Pessoa>> listarPessoasInativas() async {
    final db = await banco;

    final registros = await db.query(
      'pessoas',
      where: 'ativo = 0 AND excluido = 0',
      orderBy: 'nome COLLATE NOCASE',
    );

    return registros.map(Pessoa.fromMap).toList();
  }

  /// Retorna todos os registros, inclusive os excluídos.
  ///
  /// É usado por rotinas de sincronização e verificação interna.
  Future<List<Pessoa>> listarTodasPessoas() async {
    final db = await banco;

    final registros = await db.query(
      'pessoas',
      orderBy: 'nome COLLATE NOCASE',
    );

    return registros.map(Pessoa.fromMap).toList();
  }

  /// Retorna somente os registros marcados como excluídos.
  Future<List<Pessoa>> listarPessoasExcluidas() async {
    final db = await banco;

    final registros = await db.query(
      'pessoas',
      where: 'excluido = 1',
      orderBy: 'excluido_em',
    );

    return registros.map(Pessoa.fromMap).toList();
  }

  Future<Pessoa?> buscarPessoa(int id) async {
    final db = await banco;

    final registros = await db.query(
      'pessoas',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (registros.isEmpty) {
      return null;
    }

    return Pessoa.fromMap(registros.first);
  }

  Future<Pessoa?> buscarPessoaPorUuid(String uuid) async {
    final db = await banco;

    final registros = await db.query(
      'pessoas',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );

    if (registros.isEmpty) {
      return null;
    }

    return Pessoa.fromMap(registros.first);
  }

  Future<int> atualizarPessoa(Pessoa pessoa) async {
    if (pessoa.id == null) {
      throw ArgumentError(
        'A pessoa precisa possuir um ID para ser atualizada.',
      );
    }

    final db = await banco;

    final dados = Map<String, Object?>.from(
      pessoa.toMap(),
    )..remove('id');

    return db.update(
      'pessoas',
      dados,
      where: 'id = ?',
      whereArgs: [pessoa.id],
    );
  }

  /// Encerra a demanda atual sem excluir o cadastro.
  Future<int> inativarPessoa(int id) async {
    final db = await banco;

    return db.update(
      'pessoas',
      {'ativo': 0},
      where: 'id = ? AND excluido = 0',
      whereArgs: [id],
    );
  }

  /// Reabre o cadastro para uma nova demanda.
  Future<int> reativarPessoa(int id) async {
    final db = await banco;

    return db.update(
      'pessoas',
      {'ativo': 1},
      where: 'id = ? AND excluido = 0',
      whereArgs: [id],
    );
  }

  /// Marca o cadastro como excluído.
  ///
  /// Registros excluídos não podem ser reativados.
  Future<int> excluirPessoa(
    int id, {
    required DateTime excluidoEm,
  }) async {
    final db = await banco;

    return db.update(
      'pessoas',
      {
        'ativo': 0,
        'excluido': 1,
        'excluido_em': excluidoEm.toIso8601String(),
      },
      where: 'id = ? AND excluido = 0',
      whereArgs: [id],
    );
  }

  Future<void> salvarOuAtualizarPorUuid(Pessoa pessoa) async {
    final db = await banco;

    await db.transaction((transacao) async {
      final registros = await transacao.query(
        'pessoas',
        columns: ['id'],
        where: 'uuid = ?',
        whereArgs: [pessoa.uuid],
        limit: 1,
      );

      final dados = Map<String, Object?>.from(
        pessoa.toMap(),
      )..remove('id');

      if (registros.isEmpty) {
        await transacao.insert(
          'pessoas',
          dados,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      } else {
        await transacao.update(
          'pessoas',
          dados,
          where: 'uuid = ?',
          whereArgs: [pessoa.uuid],
        );
      }
    });
  }

  /// Aplica localmente uma exclusão recebida do Firestore.
  Future<int> excluirPorUuid(
    String uuid, {
    required DateTime excluidoEm,
  }) async {
    final db = await banco;

    return db.update(
      'pessoas',
      {
        'ativo': 0,
        'excluido': 1,
        'excluido_em': excluidoEm.toIso8601String(),
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Remove fisicamente do SQLite registros excluídos há mais de 30 dias.
  ///
  /// Este método deverá ser executado somente depois que a rotina de
  /// sincronização confirmar a limpeza correspondente no Firestore.
  Future<int> removerExcluidosAnterioresA(DateTime limite) async {
    final db = await banco;

    return db.delete(
      'pessoas',
      where: '''
        excluido = 1
        AND excluido_em IS NOT NULL
        AND excluido_em <= ?
      ''',
      whereArgs: [limite.toIso8601String()],
    );
  }
}