import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../modelos/pessoa.dart';

class ExportacaoService {
  static Future<void> exportarCsv(List<Pessoa> pessoas) async {
    final excel = Excel.createExcel();

    const nomePlanilha = 'Cadastros';
    final planilha = excel[nomePlanilha];

    // Remove a planilha criada automaticamente.
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    planilha.appendRow([
      TextCellValue('UUID'),
      TextCellValue('Nome'),
      TextCellValue('Endereço'),
      TextCellValue('Telefone'),
      TextCellValue('Observações'),
      TextCellValue('Criado em'),
      TextCellValue('Criado por'),
      TextCellValue('Alterado em'),
      TextCellValue('Alterado por'),
    ]);

    for (final pessoa in pessoas) {
      planilha.appendRow([
        TextCellValue(pessoa.uuid),
        TextCellValue(pessoa.nome),
        TextCellValue(pessoa.endereco),
        TextCellValue(pessoa.telefone),
        TextCellValue(pessoa.observacoes),
        TextCellValue(pessoa.criadoEm.toIso8601String()),
        TextCellValue(pessoa.criadoPor),
        TextCellValue(
          pessoa.alteradoEm?.toIso8601String() ?? '',
        ),
        TextCellValue(pessoa.alteradoPor ?? ''),
      ]);
    }

    final bytes = excel.save();

    if (bytes == null) {
      throw Exception('Não foi possível gerar o arquivo Excel.');
    }

    final diretorio = await getTemporaryDirectory();
    final agora = DateTime.now();

    final nomeArquivo =
        'cadastros_${agora.year}-'
        '${agora.month.toString().padLeft(2, '0')}-'
        '${agora.day.toString().padLeft(2, '0')}_'
        '${agora.hour.toString().padLeft(2, '0')}'
        '${agora.minute.toString().padLeft(2, '0')}.xlsx';

    final arquivo = File(
      '${diretorio.path}/$nomeArquivo',
    );

    await arquivo.writeAsBytes(
      bytes,
      flush: true,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            arquivo.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.'
                'spreadsheetml.sheet',
          ),
        ],
        subject: 'Cadastros',
        text: 'Arquivo de cadastros em formato Excel.',
      ),
    );
  }
}