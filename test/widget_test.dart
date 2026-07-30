import 'package:flutter_test/flutter_test.dart';
import 'package:cadastro_por_voz/main.dart';

void main() {
  testWidgets('Exibe a tela de cadastro', (WidgetTester tester) async {
    await tester.pumpWidget(const CadastroPorVozApp());

    expect(find.text('Cadastro Assistido'), findsOneWidget);
    expect(find.text('Salvar cadastro'), findsOneWidget);
  });
}
