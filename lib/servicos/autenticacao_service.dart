import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AutenticacaoService {
  AutenticacaoService._();

  static final AutenticacaoService instancia = AutenticacaoService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleInicializado = false;

  User? get usuarioAtual => _auth.currentUser;
  String get uidUsuarioAtual {
    return _auth.currentUser?.uid ?? '';
  }

  String get emailUsuarioAtual {
    return _auth.currentUser?.email?.trim() ?? '';
  }

  String get nomeUsuarioAtual {
    final usuario = _auth.currentUser;

    if (usuario == null) {
      return '';
    }

    final nome = usuario.displayName?.trim();

    if (nome != null && nome.isNotEmpty) {
      return nome;
    }

    for (final provedor in usuario.providerData) {
      final nomeProvedor = provedor.displayName?.trim();

      if (nomeProvedor != null && nomeProvedor.isNotEmpty) {
        return nomeProvedor;
      }
    }

    final email = usuario.email?.trim();

    if (email != null && email.isNotEmpty) {
      return email;
    }

    return usuario.uid;
  }

  Future<void> salvarNomeUsuario(String nome) async {
    final usuario = _auth.currentUser;
    final nomeLimpo = nome.trim();

    if (usuario == null) {
      throw StateError('Não há usuário autenticado.');
    }

    if (nomeLimpo.isEmpty) {
      throw ArgumentError('O nome não pode ficar vazio.');
    }

    await usuario.updateDisplayName(nomeLimpo);
    await usuario.reload();
  }

  Stream<User?> get mudancasDeAutenticacao => _auth.authStateChanges();

  Future<void> _inicializarGoogle() async {
    if (_googleInicializado) return;

    await _googleSignIn.initialize();
    _googleInicializado = true;
  }

  Future<UserCredential> entrarComEmailSenha({
    required String email,
    required String senha,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: senha,
    );
  }

  Future<UserCredential> criarContaComEmailSenha({
    required String email,
    required String senha,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: senha,
    );
  }

  Future<UserCredential> entrarComGoogle() async {
    await _inicializarGoogle();

    final contaGoogle = await _googleSignIn.authenticate();
    final autenticacaoGoogle = contaGoogle.authentication;

    final credencial = GoogleAuthProvider.credential(
      idToken: autenticacaoGoogle.idToken,
    );

    return _auth.signInWithCredential(credencial);
  }

  Future<void> enviarRedefinicaoSenha(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sair() async {
    await _auth.signOut();

    await _inicializarGoogle();

    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Não havia sessão do Google ativa.
    }
  }
}
