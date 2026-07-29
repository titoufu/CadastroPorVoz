import 'package:flutter/material.dart';

import '../banco/banco_dados.dart';
import '../modelos/pessoa.dart';
import '../servicos/operador_service.dart';

class TelaEdicao extends StatefulWidget {
  final Pessoa pessoa;

  const TelaEdicao({super.key, required this.pessoa});

  @override
  State<TelaEdicao> createState() => _TelaEdicaoState();
}

class _TelaEdicaoState extends State<TelaEdicao> {
  late final TextEditingController nomeController;
  late final TextEditingController enderecoController;
  late final TextEditingController telefoneController;
  late final TextEditingController observacoesController;
  final alteradoPorController = TextEditingController();
  final OperadorService operadorService = OperadorService.instancia;

  bool salvando = false;

  @override
  void initState() {
    super.initState();

    nomeController = TextEditingController(text: widget.pessoa.nome);

    enderecoController = TextEditingController(text: widget.pessoa.endereco);

    telefoneController = TextEditingController(text: widget.pessoa.telefone);

    observacoesController = TextEditingController(
      text: widget.pessoa.observacoes,
    );
    carregarOperador();
  }

  Future<void> carregarOperador() async {
    final nomeOperador = await operadorService.carregarNome();

    if (!mounted) return;

    setState(() {
      alteradoPorController.text = nomeOperador;
    });
  }

  @override
  void dispose() {
    nomeController.dispose();
    enderecoController.dispose();
    telefoneController.dispose();
    observacoesController.dispose();
    alteradoPorController.dispose();
    super.dispose();
  }

  Future<void> salvarAlteracoes() async {
    final nome = nomeController.text.trim();
    final alteradoPor = alteradoPorController.text.trim();

    if (nome.isEmpty) {
      mostrarMensagem('Informe o nome da pessoa.');
      return;
    }

    if (alteradoPor.isEmpty) {
      mostrarMensagem('Informe quem está fazendo a alteração.');
      return;
    }

    setState(() {
      salvando = true;
    });

    try {
      final pessoaAtualizada = Pessoa(
        id: widget.pessoa.id,
        uuid: widget.pessoa.uuid,
        nome: nome,
        endereco: enderecoController.text.trim(),
        telefone: telefoneController.text.trim(),
        observacoes: observacoesController.text.trim(),
        criadoEm: widget.pessoa.criadoEm,
        criadoPor: widget.pessoa.criadoPor,
        alteradoEm: DateTime.now(),
        alteradoPor: alteradoPor,
      );

      await BancoDados.instancia.atualizarPessoa(pessoaAtualizada);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastro atualizado com sucesso!')),
      );

      Navigator.of(context).pop(true);
    } catch (erro) {
      if (!mounted) return;

      mostrarMensagem('Não foi possível atualizar o cadastro: $erro');
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

  Future<void> excluirCadastro() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir cadastro'),
          content: Text(
            'Tem certeza de que deseja excluir o cadastro de '
            '${widget.pessoa.nome}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmou != true || widget.pessoa.id == null) {
      return;
    }

    await BancoDados.instancia.excluirPessoa(widget.pessoa.id!);

    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar cadastro'),
        actions: [
          IconButton(
            tooltip: 'Excluir cadastro',
            onPressed: excluirCadastro,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: alteradoPorController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Alterado por',
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
                  onPressed: salvando ? null : salvarAlteracoes,
                  icon: salvando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(salvando ? 'Salvando...' : 'Salvar alterações'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
