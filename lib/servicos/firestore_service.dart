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
}
