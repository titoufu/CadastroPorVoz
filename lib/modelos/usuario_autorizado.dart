import 'package:cloud_firestore/cloud_firestore.dart';

class UsuarioAutorizado {
  final String email;
  final String nome;
  final String uid;
  final bool ativo;
  final bool administrador;
  final DateTime? criadoEm;

  const UsuarioAutorizado({
    required this.email,
    required this.nome,
    required this.uid,
    required this.ativo,
    required this.administrador,
    this.criadoEm,
  });

  factory UsuarioAutorizado.fromMap(
    Map<String, dynamic> mapa, {
    required String idDocumento,
  }) {
    final valorCriadoEm = mapa['criadoEm'];

    DateTime? criadoEm;

    if (valorCriadoEm is Timestamp) {
      criadoEm = valorCriadoEm.toDate();
    } else if (valorCriadoEm is DateTime) {
      criadoEm = valorCriadoEm;
    }

    return UsuarioAutorizado(
      email: (mapa['email'] as String? ?? idDocumento)
          .trim()
          .toLowerCase(),
      nome: (mapa['nome'] as String? ?? '').trim(),
      uid: (mapa['uid'] as String? ?? '').trim(),
      ativo: mapa['ativo'] as bool? ?? false,
      administrador:
          mapa['administrador'] as bool? ?? false,
      criadoEm: criadoEm,
    );
  }

  Map<String, dynamic> toMap() {
    final mapa = <String, dynamic>{
      'email': email.trim().toLowerCase(),
      'nome': nome.trim(),
      'uid': uid.trim(),
      'ativo': ativo,
      'administrador': administrador,
    };

    if (criadoEm != null) {
      mapa['criadoEm'] = Timestamp.fromDate(criadoEm!);
    }

    return mapa;
  }
}