import 'package:flutter/material.dart';

import '../banco/banco_dados.dart';
import '../modelos/pessoa.dart';
import 'tela_edicao.dart';

class TelaConsulta extends StatefulWidget {
  const TelaConsulta({super.key});

  @override
  State<TelaConsulta> createState() => _TelaConsultaState();
}

class _TelaConsultaState extends State<TelaConsulta> {
  late Future<List<Pessoa>> pessoasFuture;

  @override
  void initState() {
    super.initState();
    pessoasFuture = BancoDados.instancia.listarPessoas();
  }

  void atualizarLista() {
    setState(() {
      pessoasFuture = BancoDados.instancia.listarPessoas();
    });
  }

  String formatarData(DateTime data) {
    String doisDigitos(int valor) => valor.toString().padLeft(2, '0');

    return '${doisDigitos(data.day)}/'
        '${doisDigitos(data.month)}/'
        '${data.year} '
        '${doisDigitos(data.hour)}:'
        '${doisDigitos(data.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastros'),
        actions: [
          IconButton(
            onPressed: atualizarLista,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Pessoa>>(
        future: pessoasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao consultar os cadastros:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final pessoas = snapshot.data ?? [];

          if (pessoas.isEmpty) {
            return const Center(child: Text('Nenhum cadastro encontrado.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: pessoas.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final pessoa = pessoas[index];

              final inicial = pessoa.nome.trim().isEmpty
                  ? '?'
                  : pessoa.nome.trim()[0].toUpperCase();

              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(inicial)),
                  title: Text(
                    pessoa.nome,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Endereço: ${pessoa.endereco}\n'
                    'Telefone: ${pessoa.telefone}\n'
                    'Cadastrado por: ${pessoa.criadoPor}\n'
                    'Data: ${formatarData(pessoa.criadoEm)}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final cadastroAlterado = await Navigator.of(context)
                        .push<bool>(
                          MaterialPageRoute(
                            builder: (context) => TelaEdicao(pessoa: pessoa),
                          ),
                        );

                    if (cadastroAlterado == true) {
                      atualizarLista();
                    }
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
