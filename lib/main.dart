import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'modelos/usuario_autorizado.dart';
import 'servicos/autenticacao_service.dart';
import 'servicos/usuario_autorizado_service.dart';
import 'telas/tela_cadastro.dart';
import 'telas/tela_login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final usuarioAtual = FirebaseAuth.instance.currentUser;

  if (usuarioAtual?.isAnonymous == true) {
    await FirebaseAuth.instance.signOut();
  }

  runApp(const CadastroPorVozApp());
}

class CadastroPorVozApp extends StatelessWidget {
  const CadastroPorVozApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cadastro Assistido',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ControleAutenticacao(),
    );
  }
}

class ControleAutenticacao extends StatelessWidget {
  const ControleAutenticacao({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AutenticacaoService.instancia.mudancasDeAutenticacao,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final usuario = snapshot.data;

        if (usuario == null || usuario.isAnonymous) {
          return const TelaLogin();
        }

        return FutureBuilder<UsuarioAutorizado>(
          future: UsuarioAutorizadoService.instancia.validarUsuarioAtual(),
          builder: (context, autorizacaoSnapshot) {
            if (autorizacaoSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Verificando autorização...'),
                    ],
                  ),
                ),
              );
            }

            if (autorizacaoSnapshot.hasError) {
              var mensagem = autorizacaoSnapshot.error.toString();

              mensagem = mensagem
                  .replaceFirst('Bad state: ', '')
                  .replaceFirst('Invalid argument(s): ', '');

              return Scaffold(
                appBar: AppBar(title: const Text('Acesso não autorizado')),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline, size: 72),
                        const SizedBox(height: 20),
                        Text(
                          mensagem,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () async {
                            await AutenticacaoService.instancia.sair();
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Sair'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final usuarioAutorizado = autorizacaoSnapshot.data;

            if (usuarioAutorizado == null) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Não foi possível carregar a autorização do usuário.',
                  ),
                ),
              );
            }

            return TelaCadastro(usuarioAutorizado: usuarioAutorizado);
          },
        );
      },
    );
  }
}
