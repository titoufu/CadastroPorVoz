import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class TelaSobre extends StatefulWidget {
  const TelaSobre({super.key});

  @override
  State<TelaSobre> createState() => _TelaSobreState();
}

class _TelaSobreState extends State<TelaSobre> {
  static const azulInstitucional = Color(0xFF343795);
  static const azulClaro = Color(0xFFEFF5FF);

  String versao = 'Carregando...';

  @override
  void initState() {
    super.initState();
    carregarVersao();
  }

  Future<void> carregarVersao() async {
    try {
      final info = await PackageInfo.fromPlatform();

      if (!mounted) return;

      setState(() {
        versao = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        versao = 'Não disponível';
      });
    }
  }

  Widget cabecalhoInstitucional() {
    return Row(
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
    );
  }

  Widget linhaInformacao({
    required IconData icone,
    required String titulo,
    required String descricao,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: azulClaro,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icone, color: azulInstitucional, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  color: azulInstitucional,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                descricao,
                style: const TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: azulClaro,
      appBar: AppBar(
        backgroundColor: azulInstitucional,
        foregroundColor: Colors.white,
        title: const Text(
          'Sobre',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  cabecalhoInstitucional(),
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Sobre o aplicativo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: azulInstitucional,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          linhaInformacao(
                            icone: Icons.volunteer_activism_outlined,
                            titulo: 'Finalidade',
                            descricao:
                                'Apoiar o cadastro e o acompanhamento das '
                                'pessoas atendidas pelo Lar.',
                          ),
                          const SizedBox(height: 14),
                          linhaInformacao(
                            icone: Icons.cloud_done_outlined,
                            titulo: 'Recursos',
                            descricao:
                                'Armazenamento local, sincronização entre '
                                'celulares e apoio de voz no preenchimento.',
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: azulClaro,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: azulInstitucional,
                                  size: 21,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Versão instalada',
                                    style: TextStyle(
                                      color: azulInstitucional,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  versao,
                                  style: const TextStyle(
                                    color: Color(0xFF444444),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Lar Espírita Maria Lobato de Freitas',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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
