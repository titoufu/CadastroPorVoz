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
    final caminhoBanco = join(await getDatabasesPath(), 'cadastro_por_voz.db');

    return openDatabase(
      caminhoBanco,

      // Versão 3: acrescenta CPF, data de nascimento e exclusão lógica.
      // Como os registros atuais são apenas testes, a atualização recria
      // a tabela em vez de migrar os dados antigos.
      version: 3,

      onCreate: _criarEstrutura,

      onUpgrade: (db, versaoAntiga, versaoNova) async {
        if (versaoAntiga < 3) {
          await db.execute('DROP TABLE IF EXISTS pessoas');
          await _criarEstrutura(db, versaoNova);
        }
      },
    );
  }

  static Future<void> _criarEstrutura(Database db, int version) async {
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
        alterado_em TEXT,
        alterado_por TEXT,
        excluido INTEGER NOT NULL DEFAULT 0
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
  }

  Future<int> inserirPessoa(Pessoa pessoa) async {
    final db = await banco;

    return db.insert(
      'pessoas',
      pessoa.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Pessoa>> listarPessoas() async {
    final db = await banco;

    final registros = await db.query(
      'pessoas',
      where: 'excluido = 0',
      orderBy: 'nome COLLATE NOCASE',
    );

    return registros.map(Pessoa.fromMap).toList();
  }

  Future<List<Pessoa>> listarTodasPessoas() async {
    final db = await banco;

    final registros = await db.query(
      'pessoas',
      orderBy: 'nome COLLATE NOCASE',
    );

    return registros.map(Pessoa.fromMap).toList();
  }

  Future<List<Pessoa>> listarPessoasInativas() async {
    final db = await banco;

    final registros = await db.query(
      'pessoas',
      where: 'excluido = 1',
      orderBy: 'nome COLLATE NOCASE',
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

  Future<int> atualizarPessoa(Pessoa pessoa) async {
    if (pessoa.id == null) {
      throw ArgumentError(
        'A pessoa precisa possuir um ID para ser atualizada.',
      );
    }

    final db = await banco;

    final dados = Map<String, Object?>.from(pessoa.toMap())..remove('id');

    return db.update('pessoas', dados, where: 'id = ?', whereArgs: [pessoa.id]);
  }

  Future<int> excluirPessoa(int id) async {
    final db = await banco;

    return db.update(
      'pessoas',
      {'excluido': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> reativarPessoa(int id) async {
    final db = await banco;

    return db.update(
      'pessoas',
      {'excluido': 0},
      where: 'id = ?',
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

      final dados = Map<String, Object?>.from(pessoa.toMap())..remove('id');

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

  Future<int> excluirPorUuid(String uuid) async {
    final db = await banco;

    return db.update(
      'pessoas',
      {'excluido': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }
}
