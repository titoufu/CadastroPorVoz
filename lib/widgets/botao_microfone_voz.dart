import 'package:flutter/material.dart';

import '../servicos/controlador_voz.dart';

class BotaoMicrofoneVoz extends StatelessWidget {
  const BotaoMicrofoneVoz({
    super.key,
    required this.campo,
    required this.aoReconhecer,
    this.aoNaoReconhecer,
    this.aoErro,
    this.habilitado = true,
    this.controlador,
  });

  final String campo;
  final TratadorResultadoVoz aoReconhecer;
  final VoidCallback? aoNaoReconhecer;
  final ValueChanged<String>? aoErro;
  final bool habilitado;
  final ControladorVoz? controlador;

  @override
  Widget build(BuildContext context) {
    final controladorEfetivo = controlador ?? ControladorVoz.instancia;

    return AnimatedBuilder(
      animation: controladorEfetivo,
      builder: (context, child) {
        final estaOuvindo = controladorEfetivo.campoEmEscuta == campo;

        return IconButton(
          tooltip: estaOuvindo ? 'Parar de ouvir' : 'Ditar $campo',
          onPressed: !habilitado
              ? null
              : () {
                  controladorEfetivo.alternarEscuta(
                    campo: campo,
                    aoReconhecer: aoReconhecer,
                    aoNaoReconhecer: aoNaoReconhecer,
                    aoErro: aoErro,
                  );
                },
          icon: Icon(
            estaOuvindo ? Icons.mic : Icons.mic_none,
            color: estaOuvindo ? Colors.red : const Color(0xFF343795),
          ),
        );
      },
    );
  }
}
