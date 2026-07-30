import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../modelos/pessoa.dart';

class BancoDados {
  BancoDados._();

  static final BancoDados instancia = BancoDados._();

  static final Uuid _geradorUuid = Uuid();

  static Database? _banco;

  Future<Database> get banco async {
    _banco ??= await _abrirBanco();
    return _banco!;
  }

  Future<Database> _abrirBanco() async {
    final caminhoBanco = join(await getDatabasesPath(), 'cadastro_por_voz.db');

    return openDatabase(
      caminhoBanco,

      // Versão 2: acrescenta o UUID.
      version: 2,

      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pessoas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT NOT NULL,
            nome TEXT NOT NULL,
            endereco TEXT NOT NULL,
            telefone TEXT NOT NULL,
            observacoes TEXT NOT NULL,
            criado_em TEXT NOT NULL,
            criado_por TEXT NOT NULL,
            alterado_em TEXT,
            alterado_por TEXT
          )
        ''');

        await db.execute('''
          CREATE UNIQUE INDEX idx_pessoas_uuid
          ON pessoas(uuid)
        ''');
      },

      onUpgrade: (db, versaoAntiga, versaoNova) async {
        if (versaoAntiga < 2) {
          // Acrescenta a coluna aos bancos já existentes.
          await db.execute('''
            ALTER TABLE pessoas
            ADD COLUMN uuid TEXT NOT NULL DEFAULT ''
          ''');

          // Gera um UUID para cada cadastro antigo.
          final registros = await db.query('pessoas', columns: ['id']);

          for (final registro in registros) {
            final id = registro['id'] as int;

            await db.update(
              'pessoas',
              {'uuid': _geradorUuid.v4()},
              where: 'id = ?',
              whereArgs: [id],
            );
          }

          // Impede dois registros com o mesmo UUID.
          await db.execute('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_pessoas_uuid
            ON pessoas(uuid)
          ''');
        }
      },
    );
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

    final registros = await db.query('pessoas', orderBy: 'nome COLLATE NOCASE');

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

    return db.delete('pessoas', where: 'id = ?', whereArgs: [id]);
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

    return db.delete('pessoas', where: 'uuid = ?', whereArgs: [uuid]);
  }
}
