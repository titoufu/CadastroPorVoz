import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class TelaSobre extends StatefulWidget {
  const TelaSobre({super.key});

  @override
  State<TelaSobre> createState() => _TelaSobreState();
}

class _TelaSobreState extends State<TelaSobre> {
  String versao = 'Carregando...';

  @override
  void initState() {
    super.initState();
    carregarVersao();
  }

  Future<void> carregarVersao() async {
    final info = await PackageInfo.fromPlatform();

    if (!mounted) return;

    setState(() {
      versao = '${info.version}+${info.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cadastro Assistido',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text('Versão: $versao'),
            const SizedBox(height: 16),
            const Text(
              'Aplicativo para cadastro de pessoas com suporte a voz, '
              'armazenamento local e sincronização entre celulares.',
            ),
          ],
        ),
      ),
    );
  }
}