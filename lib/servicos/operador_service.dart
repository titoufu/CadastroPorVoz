import 'package:shared_preferences/shared_preferences.dart';

class OperadorService {
  OperadorService._();

  static final OperadorService instancia = OperadorService._();

  static const String _chaveNomeOperador = 'nome_operador';

  final SharedPreferencesAsync _preferencias =
      SharedPreferencesAsync();

  Future<String> carregarNome() async {
    final nome = await _preferencias.getString(
      _chaveNomeOperador,
    );

    return nome?.trim() ?? '';
  }

  Future<void> salvarNome(String nome) async {
    final nomeLimpo = nome.trim();

    if (nomeLimpo.isEmpty) {
      await _preferencias.remove(_chaveNomeOperador);
      return;
    }

    await _preferencias.setString(
      _chaveNomeOperador,
      nomeLimpo,
    );
  }
}