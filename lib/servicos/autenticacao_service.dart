import 'package:firebase_auth/firebase_auth.dart';

class AutenticacaoService {
  AutenticacaoService._();

  static final AutenticacaoService instancia =
      AutenticacaoService._();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  User? get usuarioAtual => _firebaseAuth.currentUser;

  Future<User> garantirAutenticacao() async {
    final usuarioExistente = _firebaseAuth.currentUser;

    if (usuarioExistente != null) {
      return usuarioExistente;
    }

    final credencial =
        await _firebaseAuth.signInAnonymously();

    final usuario = credencial.user;

    if (usuario == null) {
      throw StateError(
        'O Firebase não retornou o usuário autenticado.',
      );
    }

    return usuario;
  }
}