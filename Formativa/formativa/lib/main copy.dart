
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const FormativaApp());
}

class FormativaApp extends StatelessWidget {
  const FormativaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Formativa Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF246B52),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F5),
      ),
      home: const TelaPrincipal(),
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  final TextEditingController _buscaController =
      TextEditingController();

  String _cidadeSelecionada = 'Todas';
  String _categoriaSelecionada = 'Todas';

  final List<String> _cidades = const [
    'Todas',
    'São Paulo',
    'Campinas',
    'Jundiaí',
  ];

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  bool _correspondeAoFiltro(Map<String, dynamic> dados) {
    final nome = (dados['nome'] ?? '').toString().toLowerCase();
    final categoria =
        (dados['categoria'] ?? '').toString().toLowerCase();
    final cidade = (dados['cidade'] ?? '').toString();

    final busca = _buscaController.text.trim().toLowerCase();

    final correspondeBusca =
        nome.contains(busca) || categoria.contains(busca);

    final correspondeCidade = _cidadeSelecionada == 'Todas' ||
        cidade == _cidadeSelecionada;

    final correspondeCategoria =
        _categoriaSelecionada == 'Todas' ||
        categoria == _categoriaSelecionada.toLowerCase();

    return correspondeBusca &&
        correspondeCidade &&
        correspondeCategoria;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Formativa Mobile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF246B52),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Encontre lugares perto de você',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pesquise estabelecimentos por nome ou categoria.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _buscaController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar estabelecimentos...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _cidadeSelecionada,
                    decoration: InputDecoration(
                      labelText: 'Cidade',
                      prefixIcon: const Icon(Icons.location_city),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _cidades.map((cidade) {
                      return DropdownMenuItem(
                        value: cidade,
                        child: Text(cidade),
                      );
                    }).toList(),
                    onChanged: (cidade) {
                      if (cidade != null) {
                        setState(() {
                          _cidadeSelecionada = cidade;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _categoriaSelecionada,
                    decoration: InputDecoration(
                      labelText: 'Categoria',
                      prefixIcon: const Icon(Icons.category),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Todas',
                        child: Text('Todas as categorias'),
                      ),
                      DropdownMenuItem(
                        value: 'Restaurante',
                        child: Text('Restaurante'),
                      ),
                      DropdownMenuItem(
                        value: 'Mercado',
                        child: Text('Mercado'),
                      ),
                      DropdownMenuItem(
                        value: 'Farmácia',
                        child: Text('Farmácia'),
                      ),
                      DropdownMenuItem(
                        value: 'Lazer',
                        child: Text('Lazer'),
                      ),
                      DropdownMenuItem(
                        value: 'Cafeteria',
                        child: Text('Cafeteria'),
                      ),
                    ],
                    onChanged: (categoria) {
                      if (categoria != null) {
                        setState(() {
                          _categoriaSelecionada = categoria;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Estabelecimentos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('locais')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Não foi possível carregar os locais. '
                          'Verifique se o Firestore está configurado '
                          'e se as regras permitem a leitura.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final documentos = snapshot.data?.docs ?? [];

                  final locais = documentos.where((documento) {
                    return _correspondeAoFiltro(documento.data());
                  }).toList();

                  if (locais.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 56,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Nenhum estabelecimento encontrado.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Adicione documentos à coleção "locais" '
                              'no Firestore.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: locais.length,
                    itemBuilder: (context, index) {
                      final documento = locais[index];
                      final dados = documento.data();

                      final nome =
                          (dados['nome'] ?? 'Sem nome').toString();
                      final categoria =
                          (dados['categoria'] ?? 'Sem categoria')
                              .toString();
                      final cidade =
                          (dados['cidade'] ?? 'Sem cidade').toString();
                      final descricao =
                          (dados['descricao'] ?? '').toString();
                      final avaliacao = dados['avaliacao'];

                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor:
                                const Color(0xFFE1F0E8),
                            child: Icon(
                              _iconeCategoria(categoria),
                              color: const Color(0xFF246B52),
                            ),
                          ),
                          title: Text(
                            nome,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('$categoria • $cidade'),
                                if (descricao.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(descricao),
                                ],
                                if (avaliacao is num) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '★ ${avaliacao.toStringAsFixed(1)}',
                                  ),
                                ],
                              ],
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                          ),
                          onTap: () {
                            showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(nome),
                                content: Text(
                                  'Categoria: $categoria\n'
                                  'Cidade: $cidade\n\n'
                                  '${descricao.isEmpty ? 'Sem descrição.' : descricao}',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context),
                                    child: const Text('Fechar'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconeCategoria(String categoria) {
    switch (categoria.toLowerCase()) {
      case 'restaurante':
        return Icons.restaurant;
      case 'mercado':
        return Icons.shopping_cart;
      case 'farmácia':
      case 'farmacia':
        return Icons.local_pharmacy;
      case 'lazer':
        return Icons.park;
      case 'cafeteria':
        return Icons.local_cafe;
      default:
        return Icons.place;
    }
  }
}
