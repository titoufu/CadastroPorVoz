import 'package:flutter/material.dart';

import 'banco/banco_dados.dart';
import 'modelos/pessoa.dart';
import 'telas/tela_consulta.dart';

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
  final nomeController = TextEditingController();
  final enderecoController = TextEditingController();
  final telefoneController = TextEditingController();
  final observacoesController = TextEditingController();
  final cadastradoPorController = TextEditingController();

  bool salvando = false;

  @override
  void dispose() {
    nomeController.dispose();
    enderecoController.dispose();
    telefoneController.dispose();
    observacoesController.dispose();
    cadastradoPorController.dispose();
    super.dispose();
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

      if (!mounted) return;

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
                decoration: const InputDecoration(
                  labelText: 'Cadastrado por',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nomeController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: enderecoController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Endereço',
                  prefixIcon: Icon(Icons.home),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: telefoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: observacoesController,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
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
