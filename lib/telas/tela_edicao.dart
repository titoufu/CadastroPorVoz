import 'dart:async';

import 'package:flutter/material.dart';
import '../banco/banco_dados.dart';
import '../modelos/pessoa.dart';
import '../servicos/autenticacao_service.dart';
import '../servicos/controlador_voz.dart';
import '../servicos/firestore_service.dart';
import '../util/conversores_voz.dart';
import '../widgets/botao_microfone_voz.dart';

class TelaEdicao extends StatefulWidget {
  final Pessoa pessoa;

  const TelaEdicao({super.key, required this.pessoa});

  bool get estaInativo => pessoa.excluido;

  @override
  State<TelaEdicao> createState() => _TelaEdicaoState();
}

class _TelaEdicaoState extends State<TelaEdicao> {
  late final TextEditingController cadastradoPorController;
  late final TextEditingController alteradoPorController;
  late final TextEditingController nomeController;
  late final TextEditingController cpfController;
  late final TextEditingController dataNascimentoController;
  late final TextEditingController enderecoController;
  late final TextEditingController telefoneController;
  late final TextEditingController historicoObservacoesController;
  late final TextEditingController novaObservacaoController;

  final FirestoreService firestoreService = FirestoreService.instancia;
  final ControladorVoz controladorVoz = ControladorVoz.instancia;

  bool salvando = false;
  DateTime? dataNascimentoSelecionada;

  @override
  void initState() {
    super.initState();

    cadastradoPorController = TextEditingController(
      text: widget.pessoa.criadoPor,
    );

    alteradoPorController = TextEditingController(
      text: widget.pessoa.alteradoPor ?? '',
    );

    nomeController = TextEditingController(text: widget.pessoa.nome);

    cpfController = TextEditingController(
      text: formatarCpf(widget.pessoa.cpf),
    );

    dataNascimentoSelecionada = widget.pessoa.dataNascimento;
    dataNascimentoController = TextEditingController(
      text: widget.pessoa.dataNascimento == null
          ? ''
          : formatarData(widget.pessoa.dataNascimento!),
    );

    enderecoController = TextEditingController(text: widget.pessoa.endereco);

    telefoneController = TextEditingController(text: widget.pessoa.telefone);

    historicoObservacoesController = TextEditingController(
      text: normalizarHistoricoExistente(),
    );

    novaObservacaoController = TextEditingController();

    unawaited(
      controladorVoz.preparar(
        aoErro: mostrarMensagem,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(controladorVoz.parar(canceladaPeloUsuario: true));
    cadastradoPorController.dispose();
    alteradoPorController.dispose();
    nomeController.dispose();
    cpfController.dispose();
    dataNascimentoController.dispose();
    enderecoController.dispose();
    telefoneController.dispose();
    historicoObservacoesController.dispose();
    novaObservacaoController.dispose();
    super.dispose();
  }

  String formatarDataHora(DateTime data) {
    String doisDigitos(int valor) => valor.toString().padLeft(2, '0');

    return '${doisDigitos(data.day)}/'
        '${doisDigitos(data.month)}/'
        '${data.year} '
        '${doisDigitos(data.hour)}:'
        '${doisDigitos(data.minute)}';
  }

  String formatarData(DateTime data) {
    return ConversoresVoz.formatarData(data);
  }

  String formatarCpf(String cpf) {
    return ConversoresVoz.formatarCpf(cpf);
  }

  String normalizarHistoricoExistente() {
    final historico = widget.pessoa.observacoes.trim();

    if (historico.isEmpty) {
      return '';
    }

    final jaPossuiTimestamp = RegExp(
      r'^\[\d{2}/\d{2}/\d{4} \d{2}:\d{2}\]',
    ).hasMatch(historico);

    if (jaPossuiTimestamp) {
      return historico;
    }

    return '[${formatarDataHora(widget.pessoa.criadoEm)}] '
        '${widget.pessoa.criadoPor}: $historico';
  }

  String montarHistoricoAtualizado({
    required DateTime data,
    required String autor,
  }) {
    final historico = historicoObservacoesController.text.trim();
    final novaObservacao = novaObservacaoController.text.trim();

    if (novaObservacao.isEmpty) {
      return historico;
    }

    final novaEntrada = '[${formatarDataHora(data)}] $autor: $novaObservacao';

    if (historico.isEmpty) {
      return novaEntrada;
    }

    return '$historico\n\n$novaEntrada';
  }

  Future<void> salvarAlteracoes() async {
    final nome = nomeController.text.trim();
    final cpf = somenteDigitos(cpfController.text);

    final alteradoPor = AutenticacaoService.instancia.nomeUsuarioAtual.trim();

    if (nome.isEmpty) {
      mostrarMensagem('Informe o nome da pessoa.');
      return;
    }

    if (alteradoPor.isEmpty) {
      mostrarMensagem('Não foi possível identificar o usuário conectado.');
      return;
    }

    if (cpf.isNotEmpty && !cpfValido(cpf)) {
      mostrarMensagem('Informe um CPF válido ou deixe o campo vazio.');
      return;
    }

    if (controladorVoz.estaOuvindo) {
      await controladorVoz.parar(canceladaPeloUsuario: true);
    }

    setState(() {
      salvando = true;
    });

    try {
      final podeSalvar = await verificarPossivelDuplicidade(
        nome: nome,
        cpf: cpf,
        dataNascimento: dataNascimentoSelecionada,
      );

      if (!podeSalvar) return;

      final alteradoEm = DateTime.now();
      final historicoAtualizado = montarHistoricoAtualizado(
        data: alteradoEm,
        autor: alteradoPor,
      );

      final pessoaAtualizada = Pessoa(
        id: widget.pessoa.id,
        uuid: widget.pessoa.uuid,
        nome: nome,
        cpf: cpf,
        dataNascimento: dataNascimentoSelecionada,
        endereco: enderecoController.text.trim(),
        telefone: telefoneController.text.trim(),
        observacoes: historicoAtualizado,
        criadoEm: widget.pessoa.criadoEm,
        criadoPor: widget.pessoa.criadoPor,
        alteradoEm: alteradoEm,
        alteradoPor: alteradoPor,
        excluido: widget.estaInativo,
      );

      await BancoDados.instancia.atualizarPessoa(pessoaAtualizada);

      await firestoreService.salvarPessoa(pessoaAtualizada);

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

  Future<void> inativarCadastro() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Inativar cadastro'),
          content: Text(
            'Tem certeza de que deseja inativar o cadastro de '
            '${widget.pessoa.nome}?\n\n'
            'Ele deixará de aparecer na consulta normal, mas os dados e o '
            'histórico serão preservados.',
          ),
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
              child: const Text('Inativar'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (confirmou != true || widget.pessoa.id == null) {
      return;
    }

    try {
      final alteradoPor =
          AutenticacaoService.instancia.nomeUsuarioAtual.trim();

      if (alteradoPor.isEmpty) {
        mostrarMensagem('Não foi possível identificar o usuário conectado.');
        return;
      }

      setState(() {
        salvando = true;
      });

      final pessoaInativada = Pessoa(
        id: widget.pessoa.id,
        uuid: widget.pessoa.uuid,
        nome: widget.pessoa.nome,
        cpf: widget.pessoa.cpf,
        dataNascimento: widget.pessoa.dataNascimento,
        endereco: widget.pessoa.endereco,
        telefone: widget.pessoa.telefone,
        observacoes: widget.pessoa.observacoes,
        criadoEm: widget.pessoa.criadoEm,
        criadoPor: widget.pessoa.criadoPor,
        alteradoEm: DateTime.now(),
        alteradoPor: alteradoPor,
        excluido: true,
      );

      await BancoDados.instancia.atualizarPessoa(pessoaInativada);

      await firestoreService.salvarPessoa(pessoaInativada);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastro inativado com sucesso.')),
      );

      Navigator.of(context).pop(true);
    } catch (erro) {
      if (!mounted) return;

      mostrarMensagem('Não foi possível inativar o cadastro: $erro');
    } finally {
      if (mounted) {
        setState(() {
          salvando = false;
        });
      }
    }
  }

  Future<void> reativarCadastro() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.person_add_alt_1_outlined),
          title: const Text('Reativar cadastro'),
          content: Text(
            'Deseja reativar o cadastro de ${widget.pessoa.nome}?\n\n'
            'Ele voltará a aparecer na consulta de cadastros ativos. Os dados '
            'e todo o histórico serão preservados.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Reativar'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmou != true || widget.pessoa.id == null) {
      return;
    }

    final alteradoPor =
        AutenticacaoService.instancia.nomeUsuarioAtual.trim();

    if (alteradoPor.isEmpty) {
      mostrarMensagem('Não foi possível identificar o usuário conectado.');
      return;
    }

    setState(() {
      salvando = true;
    });

    try {
      final pessoaReativada = Pessoa(
        id: widget.pessoa.id,
        uuid: widget.pessoa.uuid,
        nome: widget.pessoa.nome,
        cpf: widget.pessoa.cpf,
        dataNascimento: widget.pessoa.dataNascimento,
        endereco: widget.pessoa.endereco,
        telefone: widget.pessoa.telefone,
        observacoes: widget.pessoa.observacoes,
        criadoEm: widget.pessoa.criadoEm,
        criadoPor: widget.pessoa.criadoPor,
        alteradoEm: DateTime.now(),
        alteradoPor: alteradoPor,
        excluido: false,
      );

      await BancoDados.instancia.atualizarPessoa(pessoaReativada);
      await firestoreService.salvarPessoa(pessoaReativada);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastro reativado com sucesso.')),
      );

      Navigator.of(context).pop(true);
    } catch (erro) {
      if (!mounted) return;

      mostrarMensagem('Não foi possível reativar o cadastro: $erro');
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
  }) async {
    final locais = await BancoDados.instancia.listarTodasPessoas();
    final nuvem = await firestoreService.listarTodasPessoas();

    final pessoasPorUuid = <String, Pessoa>{};

    for (final pessoa in locais) {
      if (pessoa.uuid != widget.pessoa.uuid) {
        pessoasPorUuid[pessoa.uuid] = pessoa;
      }
    }

    for (final pessoa in nuvem) {
      if (pessoa.uuid != widget.pessoa.uuid) {
        pessoasPorUuid[pessoa.uuid] = pessoa;
      }
    }

    final outrasPessoas = pessoasPorUuid.values.toList();

    if (cpf.isNotEmpty) {
      final mesmoCpf = outrasPessoas.where((pessoa) {
        return somenteDigitos(pessoa.cpf) == cpf;
      }).toList();

      if (mesmoCpf.isNotEmpty) {
        if (!mounted) return false;

        await mostrarDialogoCpfJaUtilizado(mesmoCpf.first);
        return false;
      }
    }

    if (dataNascimento != null) {
      final nomeNormalizado = normalizarTexto(nome);

      final mesmoNomeENascimento = outrasPessoas.where((pessoa) {
        return normalizarTexto(pessoa.nome) == nomeNormalizado &&
            mesmaData(pessoa.dataNascimento, dataNascimento);
      }).toList();

      if (mesmoNomeENascimento.isNotEmpty) {
        if (!mounted) return false;

        return await confirmarMesmoNomeENascimento(
              mesmoNomeENascimento.first,
            ) ??
            false;
      }
    }

    return true;
  }

  Future<void> mostrarDialogoCpfJaUtilizado(Pessoa pessoa) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final situacao = pessoa.excluido ? 'inativo' : 'ativo';

        return AlertDialog(
          icon: const Icon(Icons.content_copy_outlined),
          title: const Text('CPF já utilizado'),
          content: Text(
            'Este CPF pertence a outro cadastro $situacao:\n\n'
            '${resumoPessoa(pessoa)}\n\n'
            'A alteração não foi salva.',
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

  Future<bool?> confirmarMesmoNomeENascimento(Pessoa pessoa) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final situacao = pessoa.excluido ? 'inativo' : 'ativo';

        return AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: const Text('Possível cadastro duplicado'),
          content: Text(
            'Foi encontrado outro cadastro $situacao com o mesmo nome e a '
            'mesma data de nascimento:\n\n${resumoPessoa(pessoa)}\n\n'
            'Confira os dados antes de continuar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar alteração'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Salvar mesmo assim'),
            ),
          ],
        );
      },
    );
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

  bool atualizarTextoPorVoz(
    TextEditingController controller,
    String texto, {
    String Function(String texto)? converter,
  }) {
    if (!mounted) return false;

    final valor = (converter ?? ConversoresVoz.textoNatural)(texto);
    if (valor.isEmpty) return false;

    controller.value = TextEditingValue(
      text: valor,
      selection: TextSelection.collapsed(offset: valor.length),
    );
    return true;
  }

  bool atualizarCpfPorVoz(String texto) {
    final digitos = ConversoresVoz.extrairDigitosFalados(texto);
    if (digitos.isEmpty) return false;

    final formatado = ConversoresVoz.formatarCpf(digitos);
    cpfController.value = TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
    return digitos.length >= 11;
  }

  bool atualizarTelefonePorVoz(String texto) {
    final digitos = ConversoresVoz.extrairDigitosFalados(texto);
    if (digitos.isEmpty) return false;

    final formatado = ConversoresVoz.formatarTelefone(digitos);
    telefoneController.value = TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
    return digitos.length == 10 || digitos.length == 11;
  }

  bool atualizarDataNascimentoPorVoz(String texto) {
    if (!mounted) return false;

    final data = ConversoresVoz.interpretarDataNascimento(texto);
    if (data == null) return false;

    setState(() {
      dataNascimentoSelecionada = data;
      dataNascimentoController.text = formatarData(data);
      dataNascimentoController.selection = TextSelection.collapsed(
        offset: dataNascimentoController.text.length,
      );
    });
    return true;
  }

  String resumoPessoa(Pessoa pessoa) {
    final nascimento = pessoa.dataNascimento == null
        ? 'não informado'
        : formatarData(pessoa.dataNascimento!);
    final situacao = pessoa.excluido ? 'Inativo' : 'Ativo';

    return '${pessoa.nome}\n'
        'Nascimento: $nascimento\n'
        'Situação: $situacao';
  }

  String somenteDigitos(String texto) {
    return ConversoresVoz.somenteDigitos(texto);
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
    return ConversoresVoz.normalizarTexto(texto);
  }

  void mostrarMensagem(String mensagem) {
    if (!mounted) return;

    final mensageiro = ScaffoldMessenger.of(context);
    mensageiro.clearSnackBars();
    mensageiro.showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Widget construirHistoricoObservacoes() {
    final historico = historicoObservacoesController.text.trim();

    final entradas = historico.isEmpty
        ? <String>[]
        : historico.split(
            RegExp(r'\n\s*\n(?=\[\d{2}/\d{2}/\d{4} \d{2}:\d{2}\])'),
          );

    return InputDecorator(
      isEmpty: historico.isEmpty,
      decoration: const InputDecoration(
        labelText: 'Histórico de observações',
        prefixIcon: Icon(Icons.history_outlined),
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Color(0xFFF5F5F5),
        isDense: true,
        alignLabelWithHint: true,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, maxHeight: 180),
        child: historico.isEmpty
            ? const Text(
                'Ainda não há observações registradas.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  decoration: TextDecoration.none,
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entradas.map((entrada) {
                    final resultado = RegExp(
                      r'^\[([^\]]+)\]\s+([^:]+):\s*(.*)$',
                      dotAll: true,
                    ).firstMatch(entrada.trim());

                    if (resultado == null) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          entrada,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      );
                    }

                    final timestamp = resultado.group(1) ?? '';
                    final autor = resultado.group(2) ?? '';
                    final observacao = resultado.group(3) ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.black87,
                            decoration: TextDecoration.none,
                            decorationColor: Colors.transparent,
                          ),
                          children: [
                            TextSpan(
                              text: '[$timestamp] ',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF424242),
                                decoration: TextDecoration.none,
                                decorationColor: Colors.transparent,
                              ),
                            ),
                            TextSpan(
                              text: '$autor: ',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF303030),
                                decoration: TextDecoration.none,
                                decorationColor: Colors.transparent,
                              ),
                            ),
                            TextSpan(
                              text: observacao,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Colors.black87,
                                height: 1.25,
                                decoration: TextDecoration.none,
                                decorationColor: Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
      ),
    );
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
        title: Text(
          widget.estaInativo ? 'Cadastro inativo' : 'Editar cadastro',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: widget.estaInativo
                ? 'Reativar cadastro'
                : 'Inativar cadastro',
            onPressed: salvando
                ? null
                : widget.estaInativo
                    ? reativarCadastro
                    : inativarCadastro,
            icon: Icon(
              widget.estaInativo
                  ? Icons.person_add_alt_1_outlined
                  : Icons.person_off_outlined,
            ),
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
                  if (widget.estaInativo) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD45B52)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.person_off_outlined,
                            color: Color(0xFFA1352F),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Este cadastro está inativo. Use o botão no topo '
                              'da tela para reativá-lo.',
                              style: TextStyle(
                                color: Color(0xFF7D2D28),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
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
                          const Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: azulClaro,
                                child: Icon(
                                  Icons.edit_note_outlined,
                                  color: azulInstitucional,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dados do assistido',
                                      style: TextStyle(
                                        color: azulInstitucional,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 1),
                                    Text(
                                      'Revise as informações antes de salvar.',
                                      style: TextStyle(
                                        color: Color(0xFF666666),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: nomeController,
                            enabled: !salvando,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Nome',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: BotaoMicrofoneVoz(
                                campo: 'nome',
                                habilitado: !salvando,
                                controlador: controladorVoz,
                                aoReconhecer: (texto) => atualizarTextoPorVoz(
                                  nomeController,
                                  texto,
                                ),
                                aoErro: mostrarMensagem,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: cpfController,
                            enabled: !salvando,
                            keyboardType: TextInputType.number,
                            inputFormatters: const [CpfInputFormatter()],
                            decoration: InputDecoration(
                              labelText: 'CPF (opcional)',
                              hintText: '000.000.000-00',
                              prefixIcon: const Icon(
                                Icons.credit_card_outlined,
                              ),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: BotaoMicrofoneVoz(
                                campo: 'CPF',
                                habilitado: !salvando,
                                controlador: controladorVoz,
                                aoReconhecer: atualizarCpfPorVoz,
                                aoNaoReconhecer: () => mostrarMensagem(
                                  'Não foi possível reconhecer os 11 números do CPF.',
                                ),
                                aoErro: mostrarMensagem,
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
                                      onPressed: salvando
                                          ? null
                                          : limparDataNascimento,
                                      icon: const Icon(Icons.clear),
                                    ),
                                  BotaoMicrofoneVoz(
                                    campo: 'data de nascimento',
                                    habilitado: !salvando,
                                    controlador: controladorVoz,
                                    aoReconhecer:
                                        atualizarDataNascimentoPorVoz,
                                    aoNaoReconhecer: () => mostrarMensagem(
                                      'Não entendi a data. Diga, por exemplo, '
                                      '31 de julho de 1960.',
                                    ),
                                    aoErro: mostrarMensagem,
                                  ),
                                  IconButton(
                                    tooltip: 'Selecionar data',
                                    onPressed: salvando
                                        ? null
                                        : selecionarDataNascimento,
                                    icon: const Icon(
                                      Icons.calendar_month_outlined,
                                    ),
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
                              suffixIcon: BotaoMicrofoneVoz(
                                campo: 'endereço',
                                habilitado: !salvando,
                                controlador: controladorVoz,
                                aoReconhecer: (texto) => atualizarTextoPorVoz(
                                  enderecoController,
                                  texto,
                                ),
                                aoErro: mostrarMensagem,
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
                              suffixIcon: BotaoMicrofoneVoz(
                                campo: 'telefone',
                                habilitado: !salvando,
                                controlador: controladorVoz,
                                aoReconhecer: atualizarTelefonePorVoz,
                                aoNaoReconhecer: () => mostrarMensagem(
                                  'Não foi possível reconhecer o telefone.',
                                ),
                                aoErro: mostrarMensagem,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          construirHistoricoObservacoes(),
                          const SizedBox(height: 10),
                          TextField(
                            controller: novaObservacaoController,
                            enabled: !salvando,
                            minLines: 2,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: 'Nova observação',
                              hintText:
                                  'Digite ou use o microfone para acrescentar.',
                              prefixIcon: const Icon(
                                Icons.add_comment_outlined,
                              ),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              alignLabelWithHint: true,
                              suffixIcon: BotaoMicrofoneVoz(
                                campo: 'nova observação',
                                habilitado: !salvando,
                                controlador: controladorVoz,
                                aoReconhecer: (texto) => atualizarTextoPorVoz(
                                  novaObservacaoController,
                                  texto,
                                ),
                                aoErro: mostrarMensagem,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Responsabilidade pelo cadastro',
                            style: TextStyle(
                              color: azulInstitucional,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final cadastradoPor = TextField(
                                controller: cadastradoPorController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Cadastrado por',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Color(0xFFF5F5F5),
                                  isDense: true,
                                ),
                              );

                              final alteradoPor = TextField(
                                controller: alteradoPorController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Alterado por',
                                  prefixIcon: Icon(
                                    Icons.manage_accounts_outlined,
                                  ),
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Color(0xFFF5F5F5),
                                  isDense: true,
                                ),
                              );

                              if (constraints.maxWidth < 430) {
                                return Column(
                                  children: [
                                    cadastradoPor,
                                    const SizedBox(height: 10),
                                    alteradoPor,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: cadastradoPor),
                                  const SizedBox(width: 8),
                                  Expanded(child: alteradoPor),
                                ],
                              );
                            },
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
                              onPressed: salvando ? null : salvarAlteracoes,
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
                                salvando ? 'Salvando...' : 'Salvar alterações',
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
}
