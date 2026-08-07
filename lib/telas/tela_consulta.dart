import 'package:flutter/material.dart';

import '../banco/banco_dados.dart';
import '../modelos/pessoa.dart';
import '../modelos/usuario_autorizado.dart';
import '../servicos/exportacao_service.dart';
import 'tela_edicao.dart';

enum _FiltroCadastros { ativos, inativos }

class TelaConsulta extends StatefulWidget {
  final UsuarioAutorizado usuarioAutorizado;

  const TelaConsulta({
    super.key,
    required this.usuarioAutorizado,
  });

  @override
  State<TelaConsulta> createState() => _TelaConsultaState();
}

class _TelaConsultaState extends State<TelaConsulta> {
  static const azulInstitucional = Color(0xFF343795);
  static const azulClaro = Color(0xFFEFF5FF);

  late Future<List<Pessoa>> pessoasFuture;
  _FiltroCadastros filtroSelecionado = _FiltroCadastros.ativos;

  @override
  void initState() {
    super.initState();
    pessoasFuture = carregarPessoas();
  }

  Future<List<Pessoa>> carregarPessoas() {
    return filtroSelecionado == _FiltroCadastros.ativos
        ? BancoDados.instancia.listarPessoas()
        : BancoDados.instancia.listarPessoasInativas();
  }

  void atualizarLista() {
    setState(() {
      pessoasFuture = carregarPessoas();
    });
  }

  void selecionarFiltro(Set<_FiltroCadastros> selecao) {
    if (selecao.isEmpty || selecao.first == filtroSelecionado) return;

    setState(() {
      filtroSelecionado = selecao.first;
      pessoasFuture = carregarPessoas();
    });
  }

  Future<void> exportarCadastros() async {
    final pessoas = await BancoDados.instancia.listarPessoas();

    if (!mounted) return;

    if (pessoas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há cadastros para exportar.')),
      );
      return;
    }

    await ExportacaoService.exportarCsv(pessoas);
  }

  String formatarData(DateTime data) {
    String doisDigitos(int valor) => valor.toString().padLeft(2, '0');

    return '${doisDigitos(data.day)}/'
        '${doisDigitos(data.month)}/'
        '${data.year} às '
        '${doisDigitos(data.hour)}:'
        '${doisDigitos(data.minute)}';
  }

  Widget cabecalhoInstitucional() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/imagens/logo_projeto_acolher.png',
          width: 64,
          height: 64,
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
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Lar Espírita Maria Lobato de Freitas',
                style: TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget mensagemCentral({
    required IconData icone,
    required String titulo,
    String? descricao,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: azulClaro,
              child: Icon(icone, size: 30, color: azulInstitucional),
            ),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: azulInstitucional,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (descricao != null) ...[
              const SizedBox(height: 5),
              Text(
                descricao,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF666666)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget linhaInformacao({
    required IconData icone,
    required String texto,
  }) {
    final conteudo = texto.trim().isEmpty ? 'Não informado' : texto.trim();

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 17, color: const Color(0xFF666666)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              conteudo,
              style: TextStyle(
                color: texto.trim().isEmpty
                    ? const Color(0xFF888888)
                    : const Color(0xFF444444),
                fontSize: 13,
                fontStyle: texto.trim().isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget registroResponsabilidade({
    required IconData icone,
    required String rotulo,
    required String responsavel,
    required DateTime data,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 16, color: azulInstitucional),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 11.5,
                height: 1.25,
              ),
              children: [
                TextSpan(
                  text: '$rotulo: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: '$responsavel\n${formatarData(data)}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget cartaoPessoa(Pessoa pessoa) {
    final nome = pessoa.nome.trim();
    final inicial = nome.isEmpty ? '?' : nome[0].toUpperCase();

    return Card(
      elevation: 1.5,
      shadowColor: Colors.black26,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final cadastroAlterado = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (context) => TelaEdicao(
                pessoa: pessoa,
                usuarioAutorizado: widget.usuarioAutorizado,
              ),
            ),
          );

          if (cadastroAlterado == true) {
            atualizarLista();
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: azulClaro,
                foregroundColor: azulInstitucional,
                child: Text(
                  inicial,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            nome.isEmpty ? 'Nome não informado' : nome,
                            style: const TextStyle(
                              color: azulInstitucional,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!pessoa.ativo) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE9E7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFD45B52),
                              ),
                            ),
                            child: const Text(
                              'INATIVO',
                              style: TextStyle(
                                color: Color(0xFFA1352F),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    linhaInformacao(
                      icone: Icons.home_outlined,
                      texto: pessoa.endereco,
                    ),
                    linhaInformacao(
                      icone: Icons.phone_outlined,
                      texto: pessoa.telefone,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                    registroResponsabilidade(
                      icone: Icons.person_add_alt_outlined,
                      rotulo: 'Cadastrado por',
                      responsavel: pessoa.criadoPor,
                      data: pessoa.criadoEm,
                    ),
                    if (pessoa.alteradoPor != null &&
                        pessoa.alteradoEm != null) ...[
                      const SizedBox(height: 7),
                      registroResponsabilidade(
                        icone: Icons.manage_accounts_outlined,
                        rotulo: 'Alterado por',
                        responsavel: pessoa.alteradoPor!,
                        data: pessoa.alteradoEm!,
                      ),
                    ],
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Icon(
                  Icons.chevron_right,
                  color: azulInstitucional,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: azulClaro,
      appBar: AppBar(
        backgroundColor: azulInstitucional,
        foregroundColor: Colors.white,
        title: const Text(
          'Cadastros',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Exportar para Excel',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: exportarCadastros,
          ),
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: atualizarLista,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: cabecalhoInstitucional(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<_FiltroCadastros>(
                      segments: const [
                        ButtonSegment<_FiltroCadastros>(
                          value: _FiltroCadastros.ativos,
                          icon: Icon(Icons.person_outline),
                          label: Text('Ativos'),
                        ),
                        ButtonSegment<_FiltroCadastros>(
                          value: _FiltroCadastros.inativos,
                          icon: Icon(Icons.person_off_outlined),
                          label: Text('Inativos'),
                        ),
                      ],
                      selected: {filtroSelecionado},
                      onSelectionChanged: selecionarFiltro,
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (estados) => estados.contains(WidgetState.selected)
                              ? Colors.white
                              : azulInstitucional,
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (estados) => estados.contains(WidgetState.selected)
                              ? azulInstitucional
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Pessoa>>(
                    future: pessoasFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: azulInstitucional,
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return mensagemCentral(
                          icone: Icons.error_outline,
                          titulo: 'Não foi possível consultar os cadastros',
                          descricao: '${snapshot.error}',
                        );
                      }

                      final pessoas = snapshot.data ?? [];

                      if (pessoas.isEmpty) {
                        final mostrandoInativos =
                            filtroSelecionado == _FiltroCadastros.inativos;

                        return mensagemCentral(
                          icone: mostrandoInativos
                              ? Icons.person_off_outlined
                              : Icons.person_search_outlined,
                          titulo: mostrandoInativos
                              ? 'Nenhum cadastro inativo'
                              : 'Nenhum cadastro ativo',
                          descricao: mostrandoInativos
                              ? 'Os cadastros inativados aparecerão nesta tela.'
                              : 'Os novos cadastros aparecerão nesta tela.',
                        );
                      }

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.people_alt_outlined,
                                  size: 18,
                                  color: azulInstitucional,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  '${pessoas.length} '
                                  '${pessoas.length == 1 ? 'cadastro' : 'cadastros'} '
                                  '${filtroSelecionado == _FiltroCadastros.ativos ? 'ativo${pessoas.length == 1 ? '' : 's'}' : 'inativo${pessoas.length == 1 ? '' : 's'}'}',
                                  style: const TextStyle(
                                    color: azulInstitucional,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  filtroSelecionado == _FiltroCadastros.ativos
                                      ? 'Toque para editar'
                                      : 'Toque para reativar',
                                  style: const TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: RefreshIndicator(
                              color: azulInstitucional,
                              onRefresh: () async {
                                atualizarLista();
                                await pessoasFuture;
                              },
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                                itemCount: pessoas.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) =>
                                    cartaoPessoa(pessoas[index]),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
