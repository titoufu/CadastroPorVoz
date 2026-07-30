import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelos/pessoa.dart';

class FirestoreService {
  FirestoreService._();

  static final FirestoreService instancia = FirestoreService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _pessoas {
    return _firestore.collection('pessoas');
  }

  Future<void> excluirPessoa(String uuid) async {
    await _pessoas.doc(uuid).update({
      'excluido': true,
      'alteradoEm': FieldValue.serverTimestamp(),
    });
  }

  Future<void> salvarPessoa(Pessoa pessoa) async {
    await _pessoas.doc(pessoa.uuid).set({
      'uuid': pessoa.uuid,
      'nome': pessoa.nome,
      'endereco': pessoa.endereco,
      'telefone': pessoa.telefone,
      'observacoes': pessoa.observacoes,
      'criadoEm': Timestamp.fromDate(pessoa.criadoEm),
      'criadoPor': pessoa.criadoPor,
      'alteradoEm': pessoa.alteradoEm == null
          ? null
          : Timestamp.fromDate(pessoa.alteradoEm!),
      'alteradoPor': pessoa.alteradoPor,
      'excluido': false,
    });
  }

  Future<List<Pessoa>> listarPessoasAtivas() async {
    final consulta = await _pessoas.where('excluido', isEqualTo: false).get();

    return consulta.docs.map((documento) {
      final dados = documento.data();

      final criadoEm = dados['criadoEm'] as Timestamp;
      final alteradoEm = dados['alteradoEm'] as Timestamp?;

      return Pessoa(
        uuid: documento.id,
        nome: dados['nome'] as String? ?? '',
        endereco: dados['endereco'] as String? ?? '',
        telefone: dados['telefone'] as String? ?? '',
        observacoes: dados['observacoes'] as String? ?? '',
        criadoEm: criadoEm.toDate(),
        criadoPor: dados['criadoPor'] as String? ?? '',
        alteradoEm: alteradoEm?.toDate(),
        alteradoPor: dados['alteradoPor'] as String?,
      );
    }).toList();
  }

  Future<List<String>> listarUuidsExcluidos() async {
    final consulta = await _pessoas.where('excluido', isEqualTo: true).get();

    return consulta.docs.map((documento) => documento.id).toList();
  }
}
