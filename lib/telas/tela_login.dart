import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../servicos/autenticacao_service.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  bool carregando = false;
  bool ocultarSenha = true;

  @override
  void dispose() {
    nomeController.dispose();
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  Future<void> entrarComEmail() async {
    final email = emailController.text.trim();
    final senha = senhaController.text;

    if (email.isEmpty || senha.isEmpty) {
      mostrarMensagem('Informe o e-mail e a senha.');
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      await AutenticacaoService.instancia.entrarComEmailSenha(
        email: email,
        senha: senha,
      );
      final usuario = AutenticacaoService.instancia.usuarioAtual;

      final nomeAtual = usuario?.displayName?.trim() ?? '';
      final nomeInformado = nomeController.text.trim();

      if (nomeAtual.isEmpty && nomeInformado.isNotEmpty) {
        await AutenticacaoService.instancia.salvarNomeUsuario(nomeInformado);
      }
    } on FirebaseAuthException catch (erro) {
      mostrarMensagem(traduzirErro(erro.code));
    } catch (_) {
      mostrarMensagem('Não foi possível entrar.');
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  Future<void> criarConta() async {
    final nome = nomeController.text.trim();
    final email = emailController.text.trim();
    final senha = senhaController.text;

    if (nome.isEmpty) {
      mostrarMensagem('Informe o nome completo.');
      return;
    }

    if (email.isEmpty || senha.isEmpty) {
      mostrarMensagem('Informe o e-mail e a senha.');
      return;
    }

    if (senha.length < 6) {
      mostrarMensagem('A senha deve ter pelo menos 6 caracteres.');
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      await AutenticacaoService.instancia.criarContaComEmailSenha(
        email: email,
        senha: senha,
      );

      await AutenticacaoService.instancia.salvarNomeUsuario(nome);

      mostrarMensagem('Conta criada com sucesso.');
    } on FirebaseAuthException catch (erro) {
      mostrarMensagem(traduzirErro(erro.code));
    } catch (_) {
      mostrarMensagem('Não foi possível criar a conta.');
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  Future<void> entrarComGoogle() async {
    setState(() {
      carregando = true;
    });

    try {
      await AutenticacaoService.instancia.entrarComGoogle();
    } on FirebaseAuthException catch (erro) {
      mostrarMensagem(traduzirErro(erro.code));
    } catch (_) {
      mostrarMensagem('Não foi possível entrar com o Google.');
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  Future<void> redefinirSenha() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      mostrarMensagem('Informe primeiro o seu e-mail.');
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      await AutenticacaoService.instancia.enviarRedefinicaoSenha(email);

      mostrarMensagem('Enviamos um link de redefinição para o seu e-mail.');
    } on FirebaseAuthException catch (erro) {
      mostrarMensagem(traduzirErro(erro.code));
    } catch (_) {
      mostrarMensagem('Não foi possível enviar o e-mail de redefinição.');
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  void mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  String traduzirErro(String codigo) {
    switch (codigo) {
      case 'invalid-email':
        return 'O e-mail informado é inválido.';
      case 'user-not-found':
        return 'Usuário não encontrado.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado.';
      case 'weak-password':
        return 'A senha informada é muito fraca.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde e tente novamente.';
      case 'network-request-failed':
        return 'Falha de conexão com a internet.';
      default:
        return 'Erro de autenticação: $codigo';
    }
  }

  @override
  Widget build(BuildContext context) {
    const azulInstitucional = Color(0xFF343795);
    const azulClaro = Color(0xFFEFF5FF);

    return Scaffold(
      backgroundColor: azulClaro,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/imagens/logo_projeto_acolher.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.contain,
                        semanticLabel: 'Logo do Projeto Acolher',
                      ),
                      const SizedBox(width: 12),
                      const Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Projeto Acolher',
                              style: TextStyle(
                                color: azulInstitucional,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Lar Espírita Maria Lobato de Freitas',
                              style: TextStyle(
                                color: Color(0xFF555555),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black26,
                    color: Colors.white,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Acesse sua conta',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: azulInstitucional,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: nomeController,
                            enabled: !carregando,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Nome completo (para criar conta)',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: emailController,
                            enabled: !carregando,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textCapitalization: TextCapitalization.none,
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: senhaController,
                            enabled: !carregando,
                            obscureText: ocultarSenha,
                            onSubmitted: (_) => entrarComEmail(),
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: IconButton(
                                tooltip: ocultarSenha
                                    ? 'Mostrar senha'
                                    : 'Ocultar senha',
                                onPressed: carregando
                                    ? null
                                    : () {
                                        setState(() {
                                          ocultarSenha = !ocultarSenha;
                                        });
                                      },
                                icon: Icon(
                                  ocultarSenha
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              onPressed: carregando ? null : redefinirSenha,
                              child: const Text('Esqueci minha senha'),
                            ),
                          ),
                          SizedBox(
                            height: 44,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: azulInstitucional,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: carregando ? null : entrarComEmail,
                              child: const Text(
                                'Entrar',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: azulInstitucional,
                                side: const BorderSide(
                                  color: azulInstitucional,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: carregando ? null : criarConta,
                              child: const Text('Criar conta'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text('ou'),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black87,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: carregando ? null : entrarComGoogle,
                              icon: const Icon(Icons.login),
                              label: const Text('Entrar com Google'),
                            ),
                          ),
                          if (carregando) ...[
                            const SizedBox(height: 12),
                            const Center(
                              child: SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: azulInstitucional,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Acolhimento, cuidado e organização a serviço do bem.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
