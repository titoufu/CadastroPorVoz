import 'package:flutter/material.dart';

import 'banco/banco_dados.dart';
import 'modelos/pessoa.dart';
import 'servicos/voz_service.dart';
import 'telas/tela_consulta.dart';
import 'servicos/operador_service.dart';

void main() {
  runApp(const CadastroPorVozApp());
}

class CadastroPorVozApp extends StatelessWidget {
  const CadastroPorVozApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cadastro por Voz',
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
  final OperadorService operadorService = OperadorService.instancia;
  final VozService vozService = VozService.instancia;

  bool vozDisponivel = false;
  String? campoEmEscuta;
  bool salvando = false;

  @override
  void initState() {
    super.initState();
    carregarOperador();
    inicializarVoz();
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
        nome: nome,
        endereco: enderecoController.text.trim(),
        telefone: telefoneController.text.trim(),
        observacoes: observacoesController.text.trim(),
        criadoEm: DateTime.now(),
        criadoPor: cadastradoPor,
      );

      await BancoDados.instancia.inserirPessoa(pessoa);
      await operadorService.salvarNome(cadastradoPor);

      if (!mounted) return;

      // O campo "Cadastrado por" não é apagado,
      // facilitando vários cadastros feitos pela mesma pessoa.
      nomeController.clear();
      enderecoController.clear();
      telefoneController.clear();
      observacoesController.clear();

      mostrarMensagem('Cadastro salvo com sucesso!');
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

  void mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  void dispose() {
    nomeController.dispose();
    enderecoController.dispose();
    telefoneController.dispose();
    observacoesController.dispose();
    cadastradoPorController.dispose();

    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro por Voz'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Ver cadastros',
            icon: const Icon(Icons.list_alt),
            onPressed: () {
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
