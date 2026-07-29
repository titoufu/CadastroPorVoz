import 'package:speech_to_text/speech_to_text.dart';

class VozService {
  VozService._();

  static final VozService instancia = VozService._();

  final SpeechToText _reconhecedor = SpeechToText();

  bool _inicializado = false;

  bool get estaOuvindo => _reconhecedor.isListening;

  bool get estaDisponivel => _inicializado;

  Future<bool> inicializar({
    void Function(String status)? aoMudarStatus,
    void Function(String mensagem)? aoOcorrerErro,
  }) async {
    if (_inicializado) {
      return true;
    }

    _inicializado = await _reconhecedor.initialize(
      onStatus: aoMudarStatus,
      onError: (erro) {
        aoOcorrerErro?.call(erro.errorMsg);
      },
    );

    return _inicializado;
  }

  Future<void> iniciarEscuta({
    required void Function(String texto) aoReconhecer,
  }) async {
    if (!_inicializado || _reconhecedor.isListening) {
      return;
    }

    await _reconhecedor.listen(
      onResult: (resultado) {
        aoReconhecer(resultado.recognizedWords);
      },
    );
  }

  Future<void> pararEscuta() async {
    await _reconhecedor.stop();
  }

  Future<void> cancelarEscuta() async {
    await _reconhecedor.cancel();
  }
}