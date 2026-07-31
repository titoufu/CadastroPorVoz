import 'dart:async';

import 'package:flutter/foundation.dart';

import 'voz_service.dart';

typedef TratadorResultadoVoz = bool Function(String texto);

class ControladorVoz extends ChangeNotifier {
  ControladorVoz._();

  static final ControladorVoz instancia = ControladorVoz._();

  final VozService _vozService = VozService.instancia;

  Future<bool>? _inicializacao;
  bool _disponivel = false;
  int _proximoId = 0;
  _SessaoVoz? _sessao;
  ValueChanged<String>? _aoErroDaPreparacao;

  bool get disponivel => _disponivel;
  bool get estaOuvindo => _sessao != null && !_sessao!.encerrando;
  String? get campoEmEscuta => estaOuvindo ? _sessao!.campo : null;

  Future<bool> preparar({ValueChanged<String>? aoErro}) {
    _aoErroDaPreparacao = aoErro;

    final inicializacaoAtual = _inicializacao;
    if (inicializacaoAtual != null) {
      return inicializacaoAtual;
    }

    final novaInicializacao = _inicializar();
    _inicializacao = novaInicializacao;
    return novaInicializacao;
  }

  Future<bool> _inicializar() async {
    _disponivel = await _vozService.inicializar(
      aoMudarStatus: (status) {
        if (status != 'listening') {
          _solicitarEncerramentoNatural();
        }
      },
      aoOcorrerErro: (mensagem) {
        final sessaoAtual = _sessao;
        final aoErro = sessaoAtual?.aoErro ?? _aoErroDaPreparacao;

        unawaited(parar(canceladaPeloUsuario: true));
        aoErro?.call('Erro no reconhecimento de voz: $mensagem');
      },
    );

    if (!_disponivel) {
      _inicializacao = null;
    }

    notifyListeners();
    return _disponivel;
  }

  Future<void> alternarEscuta({
    required String campo,
    required TratadorResultadoVoz aoReconhecer,
    VoidCallback? aoNaoReconhecer,
    ValueChanged<String>? aoErro,
  }) async {
    if (_sessao != null || _vozService.estaOuvindo) {
      await parar(canceladaPeloUsuario: true);
      return;
    }

    final preparada = await preparar(aoErro: aoErro);
    if (!preparada) {
      aoErro?.call('O reconhecimento de voz não está disponível.');
      return;
    }

    final sessao = _SessaoVoz(
      id: ++_proximoId,
      campo: campo,
      aoReconhecer: aoReconhecer,
      aoNaoReconhecer: aoNaoReconhecer,
      aoErro: aoErro,
    );

    _sessao = sessao;
    notifyListeners();

    try {
      await _vozService.iniciarEscuta(
        aoReconhecer: (texto) {
          if (_sessao != sessao) return;

          try {
            if (sessao.aoReconhecer(texto)) {
              sessao.reconheceuResultadoValido = true;
            }
          } catch (erro) {
            sessao.aoErro?.call(
              'Não foi possível aplicar o texto reconhecido: $erro',
            );
          }
        },
      );

      unawaited(_monitorarFimDaEscuta(sessao));
    } catch (erro) {
      _concluirSessao(sessao, canceladaPeloUsuario: true);
      aoErro?.call('Não foi possível iniciar o reconhecimento de voz: $erro');
    }
  }

  Future<void> parar({bool canceladaPeloUsuario = true}) async {
    final sessaoAtual = _sessao;

    try {
      if (_vozService.estaOuvindo) {
        await _vozService.pararEscuta();
      }
    } finally {
      if (sessaoAtual != null) {
        _concluirSessao(
          sessaoAtual,
          canceladaPeloUsuario: canceladaPeloUsuario,
        );
      }
    }
  }

  Future<void> _monitorarFimDaEscuta(_SessaoVoz sessao) async {
    while (_sessao == sessao && !sessao.encerrando) {
      await Future<void>.delayed(const Duration(milliseconds: 150));

      if (_sessao == sessao && !_vozService.estaOuvindo) {
        _solicitarEncerramentoNatural();
      }
    }
  }

  void _solicitarEncerramentoNatural() {
    final sessaoAtual = _sessao;
    if (sessaoAtual == null || sessaoAtual.encerrando) return;

    sessaoAtual.encerrando = true;
    notifyListeners();

    // Alguns aparelhos entregam o último resultado logo após o status "done".
    // O pequeno intervalo permite recebê-lo sem manter o microfone vermelho.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        _concluirSessao(sessaoAtual, canceladaPeloUsuario: false);
      }),
    );
  }

  void _concluirSessao(
    _SessaoVoz sessao, {
    required bool canceladaPeloUsuario,
  }) {
    if (_sessao != sessao) return;

    _sessao = null;
    notifyListeners();

    if (!canceladaPeloUsuario && !sessao.reconheceuResultadoValido) {
      sessao.aoNaoReconhecer?.call();
    }
  }
}

class _SessaoVoz {
  _SessaoVoz({
    required this.id,
    required this.campo,
    required this.aoReconhecer,
    this.aoNaoReconhecer,
    this.aoErro,
  });

  final int id;
  final String campo;
  final TratadorResultadoVoz aoReconhecer;
  final VoidCallback? aoNaoReconhecer;
  final ValueChanged<String>? aoErro;

  bool reconheceuResultadoValido = false;
  bool encerrando = false;
}
