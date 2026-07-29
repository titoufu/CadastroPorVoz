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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pessoas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
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
      },
    );
  }

  Future<int> inserirPessoa(Pessoa pessoa) async {
    final db = await banco;

    return db.insert(
      'pessoas',
      pessoa.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Pessoa>> listarPessoas() async {
    final db = await banco;

    final registros = await db.query(
      'pessoas',
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
      throw ArgumentError('A pessoa precisa possuir um ID para ser atualizada.');
    }

    final db = await banco;
    final dados = Map<String, Object?>.from(pessoa.toMap())
      ..remove('id');

    return db.update(
      'pessoas',
      dados,
      where: 'id = ?',
      whereArgs: [pessoa.id],
    );
  }

  Future<int> excluirPessoa(int id) async {
    final db = await banco;

    return db.delete(
      'pessoas',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}