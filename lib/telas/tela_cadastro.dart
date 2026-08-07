import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../banco/banco_dados.dart';
import '../modelos/pessoa.dart';
import '../modelos/usuario_autorizado.dart';
import '../servicos/autenticacao_service.dart';
import '../servicos/firestore_service.dart';
import '../servicos/voz_service.dart';
import '../util/conversores_voz.dart';
import 'tela_consulta.dart';
import 'tela_sobre.dart';
import 'tela_usuarios.dart';

class TelaCadastro extends StatefulWidget {
  final UsuarioAutorizado usuarioAutorizado;

  const TelaCadastro({super.key, required this.usuarioAutorizado});

  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  final cadastradoPorController = TextEditingController();
  final nomeController = TextEditingController();
  final cpfController = TextEditingController();
  final dataNascimentoController = TextEditingController();
  final enderecoController = TextEditingController();
  final telefoneController = TextEditingController();
  final observacoesController = TextEditingController();

  final VozService vozService = VozService.instancia;
  final FirestoreService firestoreService = FirestoreService.instancia;
  final Uuid geradorUuid = const Uuid();

  bool vozDisponivel = false;
  String? campoEmEscuta;

  bool salvando = false;
  bool sincronizando = false;

  DateTime? dataNascimentoSelecionada;

  String statusSincronizacao = 'Aguardando';

  @override
  void initState() {
    super.initState();

    carregarUsuarioLogado();
    inicializarVoz();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      sincronizarCadastros();
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
    ValueChanged<String>? aoReconhecerTexto,
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

        if (aoReconhecerTexto != null) {
          aoReconhecerTexto(texto);
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
    final cpf = somenteDigitos(cpfController.text);

    final usuarioLogado = widget.usuarioAutorizado.nome.trim();

    if (nome.isEmpty) {
      mostrarMensagem('Informe o nome da pessoa.');
      return;
    }

    if (usuarioLogado.isEmpty) {
      mostrarMensagem('Não foi possível identificar o usuário conectado.');
      return;
    }

    if (cpf.isNotEmpty && !cpfValido(cpf)) {
      mostrarMensagem('Informe um CPF válido ou deixe o campo vazio.');
      return;
    }

    setState(() {
      salvando = true;
    });

    try {
      final podeCadastrar = await verificarPossivelDuplicidade(
        nome: nome,
        cpf: cpf,
        dataNascimento: dataNascimentoSelecionada,
        usuarioLogado: usuarioLogado,
      );

      if (!podeCadastrar) {
        return;
      }

      final criadoEm = DateTime.now();

      final pessoa = Pessoa(
        uuid: geradorUuid.v4(),
        nome: nome,
        cpf: cpf,
        dataNascimento: dataNascimentoSelecionada,
        endereco: enderecoController.text.trim(),
        telefone: telefoneController.text.trim(),
        observacoes: montarObservacaoInicial(
          texto: observacoesController.text,
          data: criadoEm,
          autor: usuarioLogado,
        ),
        criadoEm: criadoEm,
        criadoPor: usuarioLogado,
        criadoPorUid: widget.usuarioAutorizado.uid,
        ativo: true,
        excluido: false,
        excluidoEm: null,
      );

      await BancoDados.instancia.inserirPessoa(pessoa);
      await firestoreService.salvarPessoa(pessoa);
      await sincronizarCadastros();

      if (!mounted) return;

      nomeController.clear();
      cpfController.clear();
      dataNascimentoController.clear();
      enderecoController.clear();
      telefoneController.clear();
      observacoesController.clear();

      setState(() {
        dataNascimentoSelecionada = null;
      });

      cadastradoPorController.text = usuarioLogado;

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

  Future<bool> verificarPossivelDuplicidade({
    required String nome,
    required String cpf,
    required DateTime? dataNascimento,
    required String usuarioLogado,
  }) async {
    final locais = await BancoDados.instancia.listarTodasPessoas();
    final nuvem = await firestoreService.listarTodasPessoas();

    final pessoasPorUuid = <String, Pessoa>{};

    for (final pessoa in locais) {
      pessoasPorUuid[pessoa.uuid] = pessoa;
    }

    for (final pessoa in nuvem) {
      pessoasPorUuid[pessoa.uuid] = pessoa;
    }

    // Registros excluídos não participam da verificação de duplicidade.
    final pessoasValidas = pessoasPorUuid.values
        .where((pessoa) => !pessoa.excluido)
        .toList();

    if (cpf.isNotEmpty) {
      final mesmoCpf = pessoasValidas.where((pessoa) {
        return somenteDigitos(pessoa.cpf) == cpf;
      }).toList();

      if (mesmoCpf.isNotEmpty) {
        final existente = mesmoCpf.first;

        if (existente.ativo) {
          await mostrarDialogoCpfAtivo(existente);
        } else {
          final reativar = await mostrarDialogoCpfInativo(existente);

          if (reativar == true) {
            await reativarCadastro(existente, usuarioLogado);
          }
        }

        return false;
      }
    }

    if (dataNascimento != null) {
      final nomeNormalizado = normalizarTexto(nome);

      final mesmoNomeENascimento = pessoasValidas.where((pessoa) {
        return normalizarTexto(pessoa.nome) == nomeNormalizado &&
            mesmaData(pessoa.dataNascimento, dataNascimento);
      }).toList();

      if (mesmoNomeENascimento.isNotEmpty) {
        return await confirmarMesmoNomeENascimento(
              mesmoNomeENascimento.first,
            ) ??
            false;
      }
    }

    return true;
  }

  Future<void> mostrarDialogoCpfAtivo(Pessoa pessoa) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.content_copy_outlined),
          title: const Text('CPF já cadastrado'),
          content: Text(
            'Já existe um cadastro ativo com este CPF:\n\n'
            '${resumoPessoa(pessoa)}\n\n'
            'O novo cadastro não foi criado.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendi'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> mostrarDialogoCpfInativo(Pessoa pessoa) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.person_off_outlined),
          title: const Text('Cadastro inativo encontrado'),
          content: Text(
            'Existe um cadastro inativo com este CPF:\n\n'
            '${resumoPessoa(pessoa)}\n\n'
            'Deseja reativar o cadastro existente? O histórico será preservado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.restore_outlined),
              label: const Text('Reativar'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> confirmarMesmoNomeENascimento(Pessoa pessoa) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final situacao = pessoa.ativo ? 'ativo' : 'inativo';

        return AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: const Text('Possível cadastro duplicado'),
          content: Text(
            'Foi encontrado um cadastro $situacao com o mesmo nome e a '
            'mesma data de nascimento:\n\n${resumoPessoa(pessoa)}\n\n'
            'Confira os dados antes de continuar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Não cadastrar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cadastrar mesmo assim'),
            ),
          ],
        );
      },
    );
  }

  Future<void> reativarCadastro(
    Pessoa pessoa,
    String usuarioLogado,
  ) async {
    final pessoaReativada = pessoa.copyWith(
      ativo: true,
      alteradoEm: DateTime.now(),
      alteradoPor: usuarioLogado,
    );

    await firestoreService.salvarPessoa(pessoaReativada);
    await BancoDados.instancia.salvarOuAtualizarPorUuid(pessoaReativada);

    if (!mounted) return;

    limparFormulario();
    mostrarMensagem(
      'Cadastro reativado com sucesso. O histórico foi preservado.',
    );
  }

  void limparFormulario() {
    nomeController.clear();
    cpfController.clear();
    dataNascimentoController.clear();
    enderecoController.clear();
    telefoneController.clear();
    observacoesController.clear();

    if (mounted) {
      setState(() {
        dataNascimentoSelecionada = null;
      });
    }
  }

  Future<void> selecionarDataNascimento() async {
    final hoje = DateTime.now();
    final dataInicial = dataNascimentoSelecionada ??
        DateTime(hoje.year - 30, hoje.month, hoje.day);

    final data = await showDatePicker(
      context: context,
      initialDate: dataInicial,
      firstDate: DateTime(1900),
      lastDate: DateTime(hoje.year, hoje.month, hoje.day),
      helpText: 'Selecione a data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      fieldLabelText: 'Data de nascimento',
    );

    if (!mounted || data == null) return;

    setState(() {
      dataNascimentoSelecionada = DateTime(data.year, data.month, data.day);
      dataNascimentoController.text = formatarData(data);
    });
  }

  void limparDataNascimento() {
    setState(() {
      dataNascimentoSelecionada = null;
      dataNascimentoController.clear();
    });
  }

  void atualizarCpfPorVoz(String texto) {
    final digitos = somenteDigitos(texto);

    if (digitos.isEmpty) return;

    final valorFormatado = const _CpfInputFormatter().formatEditUpdate(
      cpfController.value,
      TextEditingValue(text: digitos),
    );

    setState(() {
      cpfController.value = valorFormatado;
    });
  }

  void atualizarTelefonePorVoz(String texto) {
    final digitos = ConversoresVoz.extrairDigitosFalados(texto);

    if (digitos.isEmpty) return;

    final telefoneFormatado = ConversoresVoz.formatarTelefone(digitos);

    setState(() {
      telefoneController.value = TextEditingValue(
        text: telefoneFormatado,
        selection: TextSelection.collapsed(offset: telefoneFormatado.length),
      );
    });
  }

  void atualizarDataNascimentoPorVoz(String texto) {
    final data = interpretarDataNascimento(texto);

    if (data == null) return;

    setState(() {
      dataNascimentoSelecionada = data;
      dataNascimentoController.text = formatarData(data);
      dataNascimentoController.selection = TextSelection.collapsed(
        offset: dataNascimentoController.text.length,
      );
    });
  }

  DateTime? interpretarDataNascimento(String texto) {
    final hoje = DateTime.now();
    final textoNormalizado = normalizarTexto(texto);
    final numeros = RegExp(
      r'\d+',
    ).allMatches(textoNormalizado).map((item) => item.group(0)!).toList();

    int? dia;
    int? mes;
    int? ano;

    if (numeros.length >= 3) {
      dia = int.tryParse(numeros[0]);
      mes = int.tryParse(numeros[1]);
      ano = int.tryParse(numeros[2]);
    } else {
      const meses = <String, int>{
        'janeiro': 1,
        'fevereiro': 2,
        'marco': 3,
        'abril': 4,
        'maio': 5,
        'junho': 6,
        'julho': 7,
        'agosto': 8,
        'setembro': 9,
        'outubro': 10,
        'novembro': 11,
        'dezembro': 12,
      };

      for (final item in meses.entries) {
        if (textoNormalizado.contains(item.key)) {
          mes = item.value;
          break;
        }
      }

      if (mes != null && numeros.length >= 2) {
        dia = int.tryParse(numeros.first);
        ano = int.tryParse(numeros.last);
      }
    }

    if (dia == null || mes == null || ano == null) return null;

    if (ano < 100) {
      ano += ano <= hoje.year % 100 ? 2000 : 1900;
    }

    if (ano < 1900 || ano > hoje.year || mes < 1 || mes > 12 || dia < 1) {
      return null;
    }

    final data = DateTime(ano, mes, dia);
    final dataValida = data.year == ano && data.month == mes && data.day == dia;
    final naoEstaNoFuturo = !data.isAfter(
      DateTime(hoje.year, hoje.month, hoje.day),
    );

    return dataValida && naoEstaNoFuturo ? data : null;
  }

  String montarObservacaoInicial({
    required String texto,
    required DateTime data,
    required String autor,
  }) {
    final observacao = texto.trim();
    if (observacao.isEmpty) return '';

    return '[${formatarDataHora(data)}] $autor: $observacao';
  }

  String resumoPessoa(Pessoa pessoa) {
    final nascimento = pessoa.dataNascimento == null
        ? 'não informado'
        : formatarData(pessoa.dataNascimento!);
    final situacao = pessoa.excluido
        ? 'Excluído'
        : pessoa.ativo
            ? 'Ativo'
            : 'Inativo';

    return '${pessoa.nome}\n'
        'Nascimento: $nascimento\n'
        'Situação: $situacao';
  }

  String somenteDigitos(String texto) {
    return texto.replaceAll(RegExp(r'\D'), '');
  }

  bool cpfValido(String cpf) {
    final numeros = somenteDigitos(cpf);

    if (numeros.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(numeros)) {
      return false;
    }

    int calcularDigito(String base) {
      var soma = 0;
      var peso = base.length + 1;

      for (final caractere in base.split('')) {
        soma += int.parse(caractere) * peso;
        peso--;
      }

      final resto = soma % 11;
      return resto < 2 ? 0 : 11 - resto;
    }

    final primeiro = calcularDigito(numeros.substring(0, 9));
    final segundo = calcularDigito('${numeros.substring(0, 9)}$primeiro');

    return numeros.endsWith('$primeiro$segundo');
  }

  bool mesmaData(DateTime? primeira, DateTime segunda) {
    return primeira != null &&
        primeira.year == segunda.year &&
        primeira.month == segunda.month &&
        primeira.day == segunda.day;
  }

  String normalizarTexto(String texto) {
    const comAcentos = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const semAcentos = 'aaaaaeeeeiiiiooooouuuucn';
    var resultado = texto.toLowerCase().trim();

    for (var i = 0; i < comAcentos.length; i++) {
      resultado = resultado.replaceAll(comAcentos[i], semAcentos[i]);
    }

    return resultado.replaceAll(RegExp(r'\s+'), ' ');
  }

  String formatarData(DateTime data) {
    String doisDigitos(int valor) => valor.toString().padLeft(2, '0');

    return '${doisDigitos(data.day)}/'
        '${doisDigitos(data.month)}/'
        '${data.year}';
  }

  String formatarDataHora(DateTime data) {
    String doisDigitos(int valor) => valor.toString().padLeft(2, '0');

    return '${formatarData(data)} '
        '${doisDigitos(data.hour)}:'
        '${doisDigitos(data.minute)}';
  }

  Future<void> sincronizarCadastros() async {
    if (sincronizando) return;

    setState(() {
      sincronizando = true;
      statusSincronizacao = 'Sincronizando...';
    });

    try {
      final pessoasNaoExcluidas =
          await firestoreService.listarPessoasNaoExcluidas();
      final pessoasExcluidas =
          await firestoreService.listarPessoasExcluidas();

      for (final pessoa in pessoasNaoExcluidas) {
        await BancoDados.instancia.salvarOuAtualizarPorUuid(pessoa);
      }

      for (final pessoa in pessoasExcluidas) {
        final excluidoEm =
            pessoa.excluidoEm ?? pessoa.alteradoEm ?? DateTime.now();

        await BancoDados.instancia.excluirPorUuid(
          pessoa.uuid,
          excluidoEm: excluidoEm,
        );
      }

      if (!mounted) return;

      setState(() {
        statusSincronizacao = 'Sincronizado';
      });

      mostrarMensagem(
        '${pessoasNaoExcluidas.length} cadastro(s) sincronizado(s) e '
        '${pessoasExcluidas.length} exclusão(ões) aplicada(s).',
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
    ValueChanged<String>? aoReconhecerTexto,
  }) {
    final estaOuvindo = campoEmEscuta == campo;

    return IconButton(
      tooltip: estaOuvindo ? 'Parar de ouvir' : 'Ditar $campo',
      onPressed: () {
        alternarEscuta(
          campo: campo,
          controller: controller,
          aoReconhecerTexto: aoReconhecerTexto,
        );
      },
      icon: Icon(
        estaOuvindo ? Icons.mic : Icons.mic_none,
        color: estaOuvindo ? Colors.red : const Color(0xFF343795),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 17),
          const SizedBox(width: 6),
          Text(
            statusSincronizacao,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
    cpfController.dispose();
    dataNascimentoController.dispose();
    enderecoController.dispose();
    telefoneController.dispose();
    observacoesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const azulInstitucional = Color(0xFF343795);
    const azulClaro = Color(0xFFEFF5FF);

    return Scaffold(
      backgroundColor: azulClaro,
      appBar: AppBar(
        backgroundColor: azulInstitucional,
        foregroundColor: Colors.white,
        title: const Text(
          'Cadastro',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
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
            icon: const Icon(Icons.manage_search_outlined),
            onPressed: () async {
              await sincronizarCadastros();

              if (!context.mounted) return;

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TelaConsulta(
                    usuarioAutorizado: widget.usuarioAutorizado,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            onSelected: (opcao) async {
              if (opcao == 'usuarios') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const TelaUsuarios()),
                );
              } else if (opcao == 'sobre') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const TelaSobre()),
                );
              } else if (opcao == 'sair') {
                await AutenticacaoService.instancia.sair();
              }
            },
            itemBuilder: (context) => [
              if (widget.usuarioAutorizado.administrador)
                const PopupMenuItem(
                  value: 'usuarios',
                  child: ListTile(
                    leading: Icon(Icons.admin_panel_settings_outlined),
                    title: Text('Usuários autorizados'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem(
                value: 'sobre',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Sobre'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'sair',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sair'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
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
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: azulClaro,
                            child: Icon(
                              Icons.person_add_alt_1_outlined,
                              color: azulInstitucional,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Novo cadastro',
                                  style: TextStyle(
                                    color: azulInstitucional,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'Preencha ou dite os dados do assistido.',
                                  style: TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          indicadorSincronizacao(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: cadastradoPorController,
                        readOnly: true,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Cadastrado por',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Color(0xFFF5F5F5),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: nomeController,
                        enabled: !salvando,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Nome',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: botaoMicrofone(
                            campo: 'nome',
                            controller: nomeController,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: cpfController,
                        enabled: !salvando,
                        keyboardType: TextInputType.number,
                        inputFormatters: const [_CpfInputFormatter()],
                        decoration: InputDecoration(
                          labelText: 'CPF (opcional)',
                          hintText: '000.000.000-00',
                          prefixIcon: const Icon(Icons.credit_card_outlined),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: botaoMicrofone(
                            campo: 'CPF',
                            controller: cpfController,
                            aoReconhecerTexto: atualizarCpfPorVoz,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: dataNascimentoController,
                        enabled: !salvando,
                        readOnly: true,
                        onTap: salvando ? null : selecionarDataNascimento,
                        decoration: InputDecoration(
                          labelText: 'Data de nascimento (opcional)',
                          hintText: 'DD/MM/AAAA',
                          prefixIcon: const Icon(Icons.cake_outlined),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (dataNascimentoSelecionada != null)
                                IconButton(
                                  tooltip: 'Limpar data',
                                  onPressed: limparDataNascimento,
                                  icon: const Icon(Icons.clear),
                                ),
                              botaoMicrofone(
                                campo: 'data de nascimento',
                                controller: dataNascimentoController,
                                aoReconhecerTexto:
                                    atualizarDataNascimentoPorVoz,
                              ),
                              IconButton(
                                tooltip: 'Selecionar data',
                                onPressed: selecionarDataNascimento,
                                icon: const Icon(Icons.calendar_month_outlined),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: enderecoController,
                        enabled: !salvando,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Endereço',
                          prefixIcon: const Icon(Icons.home_outlined),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: botaoMicrofone(
                            campo: 'endereço',
                            controller: enderecoController,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: telefoneController,
                        enabled: !salvando,
                        keyboardType: TextInputType.phone,
                        inputFormatters: const [TelefoneInputFormatter()],
                        decoration: InputDecoration(
                          labelText: 'Telefone',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: botaoMicrofone(
                            campo: 'telefone',
                            controller: telefoneController,
                            aoReconhecerTexto: atualizarTelefonePorVoz,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: observacoesController,
                        enabled: !salvando,
                        minLines: 2,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Observações',
                          prefixIcon: const Icon(Icons.notes_outlined),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          alignLabelWithHint: true,
                          suffixIcon: botaoMicrofone(
                            campo: 'observações',
                            controller: observacoesController,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 46,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: azulInstitucional,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: salvando ? null : salvarCadastro,
                          icon: salvando
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            salvando ? 'Salvando...' : 'Salvar cadastro',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                        ],
                      ),
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

  void carregarUsuarioLogado() {
    cadastradoPorController.text = widget.usuarioAutorizado.nome;
  }
}

class _CpfInputFormatter extends TextInputFormatter {
  const _CpfInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digitos = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digitos.length > 11) {
      digitos = digitos.substring(0, 11);
    }

    final texto = StringBuffer();

    for (var i = 0; i < digitos.length; i++) {
      if (i == 3 || i == 6) {
        texto.write('.');
      } else if (i == 9) {
        texto.write('-');
      }

      texto.write(digitos[i]);
    }

    final formatado = texto.toString();

    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  }
}
