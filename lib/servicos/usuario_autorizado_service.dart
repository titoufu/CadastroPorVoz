import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../modelos/usuario_autorizado.dart';

class UsuarioAutorizadoService {
  UsuarioAutorizadoService._();

  static final UsuarioAutorizadoService instancia =
      UsuarioAutorizadoService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _colecao {
    return _firestore.collection('usuarios_autorizados');
  }

  String normalizarEmail(String email) {
    return email.trim().toLowerCase();
  }

  Future<UsuarioAutorizado?> buscarPorEmail(String email) async {
    final emailNormalizado = normalizarEmail(email);

    if (emailNormalizado.isEmpty) {
      return null;
    }

    final documento = await _colecao.doc(emailNormalizado).get();

    final dados = documento.data();

    if (!documento.exists || dados == null) {
      return null;
    }

    return UsuarioAutorizado.fromMap(dados, idDocumento: documento.id);
  }

  Future<UsuarioAutorizado?> buscarUsuarioAtual() async {
    final usuarioFirebase = _auth.currentUser;
    final email = usuarioFirebase?.email;

    if (usuarioFirebase == null || email == null || email.trim().isEmpty) {
      return null;
    }

    return buscarPorEmail(email);
  }

  Future<UsuarioAutorizado> validarUsuarioAtual() async {
    final usuarioFirebase = _auth.currentUser;
    final email = usuarioFirebase?.email;

    if (usuarioFirebase == null || email == null || email.trim().isEmpty) {
      throw StateError('Não há usuário autenticado com e-mail.');
    }

    final usuarioAutorizado = await buscarPorEmail(email);

    if (usuarioAutorizado == null) {
      throw StateError(
        'Este e-mail não está autorizado a acessar o aplicativo.',
      );
    }

    if (!usuarioAutorizado.ativo) {
      throw StateError('Este usuário está bloqueado pelo administrador.');
    }

    if (usuarioAutorizado.uid.isNotEmpty &&
        usuarioAutorizado.uid != usuarioFirebase.uid) {
      throw StateError('O e-mail está vinculado a outra conta de usuário.');
    }

    if (usuarioAutorizado.uid.isEmpty) {
      await _colecao.doc(normalizarEmail(email)).update({
        'uid': usuarioFirebase.uid,
      });

      return UsuarioAutorizado(
        email: usuarioAutorizado.email,
        nome: usuarioAutorizado.nome,
        uid: usuarioFirebase.uid,
        ativo: usuarioAutorizado.ativo,
        administrador: usuarioAutorizado.administrador,
        criadoEm: usuarioAutorizado.criadoEm,
      );
    }

    return usuarioAutorizado;
  }

  Stream<List<UsuarioAutorizado>> observarUsuarios() {
    return _colecao.orderBy('nome').snapshots().map((consulta) {
      return consulta.docs.map((documento) {
        return UsuarioAutorizado.fromMap(
          documento.data(),
          idDocumento: documento.id,
        );
      }).toList();
    });
  }

  Future<void> salvarUsuario({
    required String nome,
    required String email,
    required bool administrador,
  }) async {
    final emailNormalizado = normalizarEmail(email);
    final nomeLimpo = nome.trim();

    if (emailNormalizado.isEmpty) {
      throw ArgumentError('Informe o e-mail.');
    }

    if (nomeLimpo.isEmpty) {
      throw ArgumentError('Informe o nome.');
    }

    final referencia = _colecao.doc(emailNormalizado);
    final documentoExistente = await referencia.get();
    final dadosExistentes = documentoExistente.data();

    await referencia.set({
      'email': emailNormalizado,
      'nome': nomeLimpo,
      'uid': dadosExistentes?['uid'] ?? '',
      'ativo': dadosExistentes?['ativo'] ?? true,
      'administrador': administrador,
      'criadoEm': dadosExistentes?['criadoEm'] ?? FieldValue.serverTimestamp(),
    });
  }

  Future<void> alterarStatus({
    required String email,
    required bool ativo,
  }) async {
    final emailNormalizado = normalizarEmail(email);

    await _colecao.doc(emailNormalizado).update({'ativo': ativo});
  }

  Future<void> alterarAdministrador({
    required String email,
    required bool administrador,
  }) async {
    final emailNormalizado = normalizarEmail(email);

    await _colecao.doc(emailNormalizado).update({
      'administrador': administrador,
    });
  }

  Future<void> excluirAutorizacao(String email) async {
    final emailNormalizado = normalizarEmail(email);
    final emailAtual = _auth.currentUser?.email?.trim().toLowerCase() ?? '';

    if (emailNormalizado.isEmpty) {
      throw ArgumentError('E-mail inválido.');
    }

    if (emailNormalizado == emailAtual) {
      throw StateError('Você não pode excluir sua própria autorização.');
    }

    final referencia = _colecao.doc(emailNormalizado);
    final documento = await referencia.get();
    final dados = documento.data();

    if (!documento.exists || dados == null) {
      throw StateError('Usuário autorizado não encontrado.');
    }

    final uid = (dados['uid'] as String? ?? '').trim();

    if (uid.isNotEmpty) {
      throw StateError(
        'Este usuário já realizou acesso. Bloqueie-o em vez de excluir.',
      );
    }

    await referencia.delete();
  }
}
