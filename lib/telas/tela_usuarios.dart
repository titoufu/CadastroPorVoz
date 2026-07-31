import 'package:flutter/material.dart';

import '../modelos/usuario_autorizado.dart';
import '../servicos/autenticacao_service.dart';
import '../servicos/usuario_autorizado_service.dart';

class TelaUsuarios extends StatefulWidget {
  const TelaUsuarios({super.key});

  @override
  State<TelaUsuarios> createState() => _TelaUsuariosState();
}

class _TelaUsuariosState extends State<TelaUsuarios> {
  final UsuarioAutorizadoService usuarioService =
      UsuarioAutorizadoService.instancia;

  String get emailUsuarioAtual {
    return AutenticacaoService.instancia.emailUsuarioAtual.toLowerCase();
  }

  Future<void> alterarStatus(UsuarioAutorizado usuario, bool ativo) async {
    try {
      await usuarioService.alterarStatus(email: usuario.email, ativo: ativo);
    } catch (erro) {
      mostrarMensagem('Não foi possível alterar o status: $erro');
    }
  }

  Future<void> abrirCadastroUsuario() async {
    String nome = '';
    String email = '';

    bool administrador = false;
    bool salvando = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, atualizarDialog) {
            Future<void> salvar() async {
              final nomeLimpo = nome.trim();
              final emailNormalizado = email.trim().toLowerCase();

              if (nomeLimpo.isEmpty) {
                mostrarMensagem('Informe o nome do usuário.');
                return;
              }

              if (emailNormalizado.isEmpty || !emailNormalizado.contains('@')) {
                mostrarMensagem('Informe um e-mail válido.');
                return;
              }

              atualizarDialog(() {
                salvando = true;
              });

              try {
                await usuarioService.salvarUsuario(
                  nome: nomeLimpo,
                  email: emailNormalizado,
                  administrador: administrador,
                );

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop();

                if (!mounted) return;

                mostrarMensagem('Usuário autorizado com sucesso.');
              } catch (erro) {
                if (dialogContext.mounted) {
                  atualizarDialog(() {
                    salvando = false;
                  });
                }

                if (!mounted) return;

                mostrarMensagem('Não foi possível cadastrar o usuário: $erro');
              }
            }

            return AlertDialog(
              title: const Text('Autorizar usuário'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      enabled: !salvando,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (valor) {
                        nome = valor;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Nome completo',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      enabled: !salvando,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      onChanged: (valor) {
                        email = valor;
                      },
                      decoration: const InputDecoration(
                        labelText: 'E-mail autorizado',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Administrador'),
                      subtitle: const Text(
                        'Pode cadastrar e bloquear outros usuários.',
                      ),
                      value: administrador,
                      onChanged: salvando
                          ? null
                          : (valor) {
                              atualizarDialog(() {
                                administrador = valor;
                              });
                            },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: salvando
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: salvando ? null : salvar,
                  icon: salvando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1),
                  label: Text(salvando ? 'Salvando...' : 'Autorizar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> alterarAdministrador(
    UsuarioAutorizado usuario,
    bool administrador,
  ) async {
    try {
      await usuarioService.alterarAdministrador(
        email: usuario.email,
        administrador: administrador,
      );
    } catch (erro) {
      mostrarMensagem('Não foi possível alterar a permissão: $erro');
    }
  }

  Future<void> excluirAutorizacao(UsuarioAutorizado usuario) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir autorização'),
          content: Text('Excluir a autorização de ${usuario.email}?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmou != true) return;

    try {
      await usuarioService.excluirAutorizacao(usuario.email);

      mostrarMensagem('Autorização excluída com sucesso.');
    } catch (erro) {
      mostrarMensagem('Não foi possível excluir a autorização: $erro');
    }
  }

  void mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuários autorizados')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: abrirCadastroUsuario,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Autorizar'),
      ),
      body: StreamBuilder<List<UsuarioAutorizado>>(
        stream: usuarioService.observarUsuarios(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar os usuários:\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final usuarios = snapshot.data ?? [];

          if (usuarios.isEmpty) {
            return const Center(child: Text('Nenhum usuário autorizado.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: usuarios.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, indice) {
              final usuario = usuarios[indice];

              final ehUsuarioAtual =
                  usuario.email.toLowerCase() == emailUsuarioAtual;

              return ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    usuario.administrador
                        ? Icons.admin_panel_settings_outlined
                        : Icons.person_outline,
                  ),
                ),
                title: Text(
                  usuario.nome.isEmpty ? usuario.email : usuario.nome,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(usuario.email),
                    Text(usuario.ativo ? 'Usuário ativo' : 'Usuário bloqueado'),
                    if (usuario.uid.isEmpty)
                      const Text('Ainda não realizou o primeiro acesso'),
                  ],
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  tooltip: 'Opções do usuário',
                  onSelected: (opcao) async {
                    if (opcao == 'status') {
                      await alterarStatus(usuario, !usuario.ativo);
                    }

                    if (opcao == 'administrador') {
                      await alterarAdministrador(
                        usuario,
                        !usuario.administrador,
                      );
                    }
                    if (opcao == 'excluir') {
                      await excluirAutorizacao(usuario);
                    }
                  },
                  itemBuilder: (context) {
                    return [
                      PopupMenuItem(
                        value: 'status',
                        enabled: !ehUsuarioAtual,
                        child: Text(
                          usuario.ativo ? 'Bloquear usuário' : 'Ativar usuário',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'administrador',
                        enabled: !ehUsuarioAtual,
                        child: Text(
                          usuario.administrador
                              ? 'Remover administrador'
                              : 'Tornar administrador',
                        ),
                      ),
                      if (usuario.uid.isEmpty && !ehUsuarioAtual)
                        const PopupMenuItem(
                          value: 'excluir',
                          child: Text('Excluir autorização'),
                        ),
                    ];
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
