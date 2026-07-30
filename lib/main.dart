import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'banco/banco_dados.dart';
import 'firebase_options.dart';
import 'modelos/pessoa.dart';
import 'servicos/autenticacao_service.dart';
import 'servicos/firestore_service.dart';
import 'servicos/operador_service.dart';
import 'servicos/voz_service.dart';
import 'telas/tela_consulta.dart';
import 'telas/tela_sobre.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await AutenticacaoService.instancia.garantirAutenticacao();

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
      home: const TelaCadastro(),
    );
  }
}

class TelaCadastro extends StatefulWidget {
  const TelaCadastro({super.key});

  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  final cadastradoPorController = TextEditingController();
  final nomeController = TextEditingController();
  final enderecoController = TextEditingController();
  final telefoneController = TextEditingController();
  final observacoesController = TextEditingController();

  final VozService vozService = VozService.instancia;
  final OperadorService operadorService = OperadorService.instancia;
  final FirestoreService firestoreService = FirestoreService.instancia;
  final Uuid geradorUuid = const Uuid();

  bool vozDisponivel = false;
  String? campoEmEscuta;

  bool salvando = false;
  bool sincronizando = false;

  String statusSincronizacao = 'Aguardando';

  @override
  void initState() {
    super.initState();

    carregarOperador();
    inicializarVoz();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      sincronizarCadastros();
    });
  }

  Future<void> carregarOperador() async {
    final nomeOperador = await operadorService.carregarNome();

    if (!mounted) return;

    setState(() {
      cadastradoPorController.text = nomeOperador;
    });
  }

  Future<void> inicializarVoz() async {
    final disponivel = await vozService.inicializar(
      aoMudarStatus: (status) {
        if (!mounted) return;

        setState(() {
          if (status != 'listening') {
            campoEmEscuta = null;
          }
        });
      },
      aoOcorrerErro: (mensagem) {
        if (!mounted) return;

        setState(() {
          campoEmEscuta = null;
        });

        mostrarMensagem('Erro no reconhecimento de voz: $mensagem');
      },
    );

    if (!mounted) return;

    setState(() {
      vozDisponivel = disponivel;
    });

    if (!disponivel) {
      mostrarMensagem('O reconhecimento de voz não está disponível.');
    }
  }

  Future<void> alternarEscuta({
    required String campo,
    required TextEditingController controller,
  }) async {
    if (!vozDisponivel) {
      await inicializarVoz();

      if (!vozDisponivel) {
        return;
      }
    }

    if (vozService.estaOuvindo) {
      await vozService.pararEscuta();

      if (mounted) {
        setState(() {
          campoEmEscuta = null;
        });
      }

      return;
    }

    setState(() {
      campoEmEscuta = campo;
    });

    await vozService.iniciarEscuta(
      aoReconhecer: (texto) {
        if (!mounted || campoEmEscuta != campo) {
          return;
        }

        setState(() {
          controller.text = texto;
          controller.selection = TextSelection.collapsed(
            offset: controller.text.length,
          );
        });
      },
    );
  }

  Future<void> salvarCadastro() async {
    final nome = nomeController.text.trim();
    final cadastradoPor = cadastradoPorController.text.trim();

    if (nome.isEmpty) {
      mostrarMensagem('Informe o nome da pessoa.');
      return;
    }

    if (cadastradoPor.isEmpty) {
      mostrarMensagem('Informe quem está realizando o cadastro.');
      return;
    }

    setState(() {
      salvando = true;
    });

    try {
      final pessoa = Pessoa(
        uuid: geradorUuid.v4(),
        nome: nome,
        endereco: enderecoController.text.trim(),
        telefone: telefoneController.text.trim(),
        observacoes: observacoesController.text.trim(),
        criadoEm: DateTime.now(),
        criadoPor: cadastradoPor,
      );

      await BancoDados.instancia.inserirPessoa(pessoa);
      await firestoreService.salvarPessoa(pessoa);
      await operadorService.salvarNome(cadastradoPor);
      await sincronizarCadastros();

      if (!mounted) return;

      nomeController.clear();
      enderecoController.clear();
      telefoneController.clear();
      observacoesController.clear();

      mostrarMensagem('Cadastro salvo no celular e sincronizado com a nuvem.');
    } catch (erro) {
      if (!mounted) return;

      mostrarMensagem('Não foi possível salvar o cadastro: $erro');
    } finally {
      if (mounted) {
        setState(() {
          salvando = false;
        });
      }
    }
  }

  Future<void> sincronizarCadastros() async {
    if (sincronizando) return;

    setState(() {
      sincronizando = true;
      statusSincronizacao = 'Sincronizando...';
    });

    try {
      final pessoas = await firestoreService.listarPessoasAtivas();

      final uuidsExcluidos = await firestoreService.listarUuidsExcluidos();

      for (final pessoa in pessoas) {
        await BancoDados.instancia.salvarOuAtualizarPorUuid(pessoa);
      }

      for (final uuid in uuidsExcluidos) {
        await BancoDados.instancia.excluirPorUuid(uuid);
      }

      if (!mounted) return;

      setState(() {
        statusSincronizacao = 'Sincronizado';
      });

      mostrarMensagem(
        '${pessoas.length} cadastro(s) sincronizado(s) e '
        '${uuidsExcluidos.length} exclusão(ões) aplicada(s).',
      );
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        statusSincronizacao = 'Erro ao sincronizar';
      });

      mostrarMensagem('Não foi possível sincronizar: $erro');
    } finally {
      if (mounted) {
        setState(() {
          sincronizando = false;
        });
      }
    }
  }

  void mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Widget botaoMicrofone({
    required String campo,
    required TextEditingController controller,
  }) {
    final estaOuvindo = campoEmEscuta == campo;

    return IconButton(
      tooltip: estaOuvindo ? 'Parar de ouvir' : 'Ditar $campo',
      onPressed: () {
        alternarEscuta(campo: campo, controller: controller);
      },
      icon: Icon(
        estaOuvindo ? Icons.mic : Icons.mic_none,
        color: estaOuvindo ? Colors.red : null,
      ),
    );
  }

  Widget indicadorSincronizacao() {
    Color corFundo;
    IconData icone;

    if (sincronizando) {
      corFundo = Colors.orange.shade100;
      icone = Icons.sync;
    } else if (statusSincronizacao == 'Sincronizado') {
      corFundo = Colors.green.shade100;
      icone = Icons.cloud_done;
    } else if (statusSincronizacao == 'Erro ao sincronizar') {
      corFundo = Colors.red.shade100;
      icone = Icons.cloud_off;
    } else {
      corFundo = Colors.grey.shade200;
      icone = Icons.cloud_queue;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icone),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              statusSincronizacao,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cadastradoPorController.dispose();
    nomeController.dispose();
    enderecoController.dispose();
    telefoneController.dispose();
    observacoesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro Assistido'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Sobre',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const TelaSobre()),
              );
            },
          ),
          IconButton(
            tooltip: 'Sincronizar cadastros',
            onPressed: sincronizando ? null : sincronizarCadastros,
            icon: sincronizando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Ver cadastros',
            icon: const Icon(Icons.list_alt),
            onPressed: () async {
              await sincronizarCadastros();

              if (!context.mounted) return;

              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const TelaConsulta()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              indicadorSincronizacao(),

              TextField(
                controller: cadastradoPorController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Cadastrado por',
                  prefixIcon: const Icon(Icons.badge),
                  border: const OutlineInputBorder(),
                  suffixIcon: botaoMicrofone(
                    campo: 'cadastrado por',
                    controller: cadastradoPorController,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: nomeController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: const Icon(Icons.person),
                  border: const OutlineInputBorder(),
                  suffixIcon: botaoMicrofone(
                    campo: 'nome',
                    controller: nomeController,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: enderecoController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Endereço',
                  prefixIcon: const Icon(Icons.home),
                  border: const OutlineInputBorder(),
                  suffixIcon: botaoMicrofone(
                    campo: 'endereço',
                    controller: enderecoController,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: telefoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Telefone',
                  prefixIcon: const Icon(Icons.phone),
                  border: const OutlineInputBorder(),
                  suffixIcon: botaoMicrofone(
                    campo: 'telefone',
                    controller: telefoneController,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: observacoesController,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Observações',
                  prefixIcon: const Icon(Icons.notes),
                  border: const OutlineInputBorder(),
                  suffixIcon: botaoMicrofone(
                    campo: 'observações',
                    controller: observacoesController,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: salvando ? null : salvarCadastro,
                  icon: salvando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(salvando ? 'Salvando...' : 'Salvar cadastro'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
