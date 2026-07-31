import 'package:flutter/services.dart';

class ConversoresVoz {
  const ConversoresVoz._();

  static String textoNatural(String texto) {
    return texto.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String somenteDigitos(String texto) {
    return texto.replaceAll(RegExp(r'\D'), '');
  }

  static String extrairDigitosFalados(String texto) {
    final normalizado = normalizarTexto(texto)
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();

    if (normalizado.isEmpty) return '';

    const algarismosPorPalavra = <String, String>{
      'zero': '0',
      'um': '1',
      'uma': '1',
      'dois': '2',
      'duas': '2',
      'tres': '3',
      'quatro': '4',
      'cinco': '5',
      'seis': '6',
      'sete': '7',
      'oito': '8',
      'nove': '9',
    };

    final resultado = StringBuffer();
    for (final parte in normalizado.split(RegExp(r'\s+'))) {
      if (RegExp(r'^\d+$').hasMatch(parte)) {
        resultado.write(parte);
      } else {
        resultado.write(algarismosPorPalavra[parte] ?? '');
      }
    }

    return resultado.toString();
  }

  static String formatarCpf(String texto) {
    var digitos = extrairDigitosFalados(texto);
    if (digitos.length > 11) {
      digitos = digitos.substring(0, 11);
    }

    final resultado = StringBuffer();

    for (var i = 0; i < digitos.length; i++) {
      if (i == 3 || i == 6) {
        resultado.write('.');
      } else if (i == 9) {
        resultado.write('-');
      }

      resultado.write(digitos[i]);
    }

    return resultado.toString();
  }

  static String formatarTelefone(String texto) {
    var digitos = extrairDigitosFalados(texto);

    if ((digitos.length == 12 || digitos.length == 13) &&
        digitos.startsWith('55')) {
      digitos = digitos.substring(2);
    }

    if (digitos.length > 11) {
      digitos = digitos.substring(0, 11);
    }

    if (digitos.isEmpty) return '';
    if (digitos.length <= 2) return '($digitos';

    final ddd = digitos.substring(0, 2);
    final numero = digitos.substring(2);

    if (numero.length <= 4) return '($ddd) $numero';

    final tamanhoPrimeiraParte = numero.length <= 8 ? 4 : 5;
    final primeiraParte = numero.substring(0, tamanhoPrimeiraParte);
    final segundaParte = numero.substring(tamanhoPrimeiraParte);

    return '($ddd) $primeiraParte-$segundaParte';
  }

  static DateTime? interpretarDataNascimento(String texto) {
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
    final hojeCivil = DateTime(hoje.year, hoje.month, hoje.day);

    return dataValida && !data.isAfter(hojeCivil) ? data : null;
  }

  static String formatarData(DateTime data) {
    String doisDigitos(int valor) => valor.toString().padLeft(2, '0');

    return '${doisDigitos(data.day)}/'
        '${doisDigitos(data.month)}/'
        '${data.year}';
  }

  static String normalizarTexto(String texto) {
    const comAcentos = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const semAcentos = 'aaaaaeeeeiiiiooooouuuucn';
    var resultado = texto.toLowerCase().trim();

    for (var i = 0; i < comAcentos.length; i++) {
      resultado = resultado.replaceAll(comAcentos[i], semAcentos[i]);
    }

    return resultado.replaceAll(RegExp(r'\s+'), ' ');
  }
}

class CpfInputFormatter extends TextInputFormatter {
  const CpfInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatado = ConversoresVoz.formatarCpf(newValue.text);

    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  }
}

class TelefoneInputFormatter extends TextInputFormatter {
  const TelefoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatado = ConversoresVoz.formatarTelefone(newValue.text);

    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  }
}
