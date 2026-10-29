import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';

const verde = Color(0xFF216B54);
const cidades = ['São Paulo', 'Campinas', 'Jundiaí'];
const categorias = [
  'Academia',
  'Restaurante',
  'Cafeteria',
  'Hospital',
  'Farmácia',
  'Parque',
  'Shopping',
  'Hotel',
  'Outro',
];

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
        colorScheme: ColorScheme.fromSeed(seedColor: verde),
        scaffoldBackgroundColor: const Color(0xFFF6F7F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: verde,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      home: const NavegacaoPrincipal(),
    );
  }
}

class NavegacaoPrincipal extends StatefulWidget {
  const NavegacaoPrincipal({super.key});

  @override
  State<NavegacaoPrincipal> createState() => _NavegacaoPrincipalState();
}

class _NavegacaoPrincipalState extends State<NavegacaoPrincipal> {
  int aba = 0;
  String cidade = cidades.first;
  String pesquisa = '';
  String categoria = 'Todas';
  final buscaController = TextEditingController();

  CollectionReference<Map<String, dynamic>> get locais =>
      FirebaseFirestore.instance.collection('locais');

  @override
  void dispose() {
    buscaController.dispose();
    super.dispose();
  }

  void mensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> carregarLocais() async {
    final snap = await locais.get();
    return snap.docs;
  }

  bool combina(Map<String, dynamic> d, {bool apenasFavoritos = false}) {
    final nome = (d['nome'] ?? '').toString().toLowerCase();
    final cat = (d['categoria'] ?? '').toString().toLowerCase();
    final cid = (d['cidade'] ?? '').toString();
    final termo = pesquisa.trim().toLowerCase();
    return (termo.isEmpty || nome.contains(termo) || cat.contains(termo)) &&
        (cidade == 'Todas' || cid == cidade) &&
        (categoria == 'Todas' || d['categoria'] == categoria) &&
        (!apenasFavoritos || d['favorito'] == true);
  }

  Future<void> abrirFormulario({
    DocumentSnapshot<Map<String, dynamic>>? documento,
  }) async {
    final dados = documento?.data() ?? <String, dynamic>{};
    final novo = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => FormularioLocal(dados: dados, editando: documento != null),
    );
    if (novo == null) return;
    try {
      if (documento == null) {
        await locais.add(novo);
        mensagem('Estabelecimento cadastrado!');
      } else {
        await locais.doc(documento.id).update(novo);
        mensagem('Estabelecimento atualizado!');
      }
      setState(() {});
    } on FirebaseException catch (e, stackTrace) {
      debugPrint('ERRO FIRESTORE AO SALVAR: ${e.code} - ${e.message}');
      debugPrintStack(stackTrace: stackTrace);
      mensagem('Erro no Firestore (${e.code}): ${e.message ?? 'Não foi possível salvar.'}');
    } catch (e, stackTrace) {
      debugPrint('ERRO INESPERADO AO SALVAR: $e');
      debugPrintStack(stackTrace: stackTrace);
      mensagem('Não foi possível salvar o local: $e');
    }
  }

  Future<void> excluir(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir estabelecimento?'),
        content: Text('Deseja excluir "${doc.data()?['nome'] ?? 'este local'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await locais.doc(doc.id).delete();
      mensagem('Estabelecimento excluído.');
      setState(() {});
    } on FirebaseException catch (e) {
      mensagem('Erro ao excluir (${e.code}): ${e.message ?? 'operação recusada'}');
    } catch (e) {
      debugPrint('ERRO AO EXCLUIR: $e');
      mensagem('Não foi possível excluir: $e');
    }
  }

  Future<void> alternarFavorito(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final favorito = doc.data()?['favorito'] == true;
    try {
      await locais.doc(doc.id).update({'favorito': !favorito});
      setState(() {});
    } on FirebaseException catch (e) {
      mensagem('Erro ao alterar favorito (${e.code}): ${e.message ?? 'operação recusada'}');
    } catch (e) {
      debugPrint('ERRO AO ALTERAR FAVORITO: $e');
      mensagem('Não foi possível alterar o favorito: $e');
    }
  }

  void abrirDetalhes(DocumentSnapshot<Map<String, dynamic>> doc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetalhesLocal(
          documento: doc,
          aoEditar: () {
            Navigator.pop(context);
            abrirFormulario(documento: doc);
          },
          aoFavoritar: () => alternarFavorito(doc),
          aoExcluir: () {
            Navigator.pop(context);
            excluir(doc);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulos = ['Mapa', 'Favoritos', 'Perfil'];
    return Scaffold(
      appBar: AppBar(
        title: Text('Formativa Mobile${aba == 1 ? ' • Favoritos' : ''}'),
        actions: [
          IconButton(
            tooltip: 'Cadastrar estabelecimento',
            onPressed: () => abrirFormulario(),
            icon: const Icon(Icons.add_business),
          ),
        ],
      ),
      body: IndexedStack(
        index: aba,
        children: [
          telaMapa(),
          telaFavoritos(),
          telaPerfil(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: aba,
        onDestinationSelected: (i) => setState(() => aba = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Favoritos'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget filtros({bool compacto = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, compacto ? 8 : 14, 14, 8),
      child: Column(
        children: [
          TextField(
            controller: buscaController,
            onChanged: (v) => setState(() => pesquisa = v),
            decoration: InputDecoration(
              hintText: 'Buscar locais, endereços ou categorias...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: cidade,
                  isExpanded: true,
                  decoration: _decoracao('Cidade', Icons.location_city),
                  items: ['Todas', ...cidades]
                      .map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setState(() => cidade = v ?? 'Todas'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: categoria,
                  isExpanded: true,
                  decoration: _decoracao('Categoria', Icons.category),
                  items: ['Todas', ...categorias]
                      .map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setState(() => categoria = v ?? 'Todas'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _decoracao(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );

  Widget telaMapa() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text('Encontre lugares perto de você', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
        ),
        filtros(compacto: true),
        Expanded(
          child: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            future: carregarLocais(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return _erroFirestore(snapshot.error.toString());
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.where((d) => combina(d.data())).toList();
              final marcadores = <Marker>[];
              for (final doc in docs) {
                final d = doc.data();
                final lat = (d['latitude'] as num?)?.toDouble();
                final lng = (d['longitude'] as num?)?.toDouble();
                if (lat != null && lng != null) {
                  marcadores.add(
                    Marker(
                      point: LatLng(lat, lng),
                      width: 150,
                      height: 66,
                      child: GestureDetector(
                        onTap: () => abrirDetalhes(doc),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: Text(
                                d['nome']?.toString() ?? 'Estabelecimento',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Icon(Icons.location_on, color: verde, size: 30),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              }
              final centro = _centroCidade(cidade == 'Todas' ? cidades.first : cidade);
              return Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(initialCenter: centro, initialZoom: 12.5),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.formativa',
                      ),
                      MarkerLayer(markers: marcadores),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            'OpenStreetMap contributors',
                            onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (marcadores.isEmpty)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            docs.isEmpty
                                ? 'Nenhum local corresponde aos filtros.'
                                : 'Adicione latitude e longitude aos locais para exibir marcadores no mapa.',
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 14,
                    bottom: 18,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'resultados',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ResultadosPage(
                                documentos: docs,
                                aoAbrir: abrirDetalhes,
                                aoEditar: (d) => abrirFormulario(documento: d),
                                aoExcluir: excluir,
                                aoFavoritar: alternarFavorito,
                              ),
                            ),
                          ),
                          child: const Icon(Icons.layers_outlined),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'centralizar',
                          onPressed: () => mensagem('Use a seleção de cidade para alterar a região do mapa.'),
                          child: const Icon(Icons.my_location),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget telaFavoritos() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: locais.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _erroFirestore(snapshot.error.toString());
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs.where((d) => combina(d.data(), apenasFavoritos: true)).toList();
        return Column(
          children: [
            filtros(compacto: true),
            Expanded(
              child: docs.isEmpty
                  ? const Center(child: Text('Você ainda não tem locais favoritos.'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children: docs.map((d) => CartaoLocal(
                        documento: d,
                        aoAbrir: () => abrirDetalhes(d),
                        aoEditar: () => abrirFormulario(documento: d),
                        aoExcluir: () => excluir(d),
                        aoFavoritar: () => alternarFavorito(d),
                      )).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget telaPerfil() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const CircleAvatar(radius: 42, child: Icon(Icons.person, size: 46)),
        const SizedBox(height: 14),
        const Center(child: Text('Perfil do usuário', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        const Center(child: Text('Formativa Mobile • Localização de estabelecimentos')),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.add_business, color: verde),
            title: const Text('Cadastrar estabelecimento'),
            subtitle: const Text('Adicionar um novo local ao Firestore'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => abrirFormulario(),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.list_alt, color: verde),
            title: const Text('Ver resultados'),
            subtitle: const Text('Pesquisar, editar ou excluir locais'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final docs = await carregarLocais();
              if (!mounted) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => ResultadosPage(
                documentos: docs.where((d) => combina(d.data())).toList(),
                aoAbrir: abrirDetalhes,
                aoEditar: (d) => abrirFormulario(documento: d),
                aoExcluir: excluir,
                aoFavoritar: alternarFavorito,
              )));
            },
          ),
        ),
      ],
    );
  }

  Widget _erroFirestore(String erro) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text('Não foi possível carregar os locais.\nConfira as regras do Firestore.\n\n$erro', textAlign: TextAlign.center),
    ),
  );
}

LatLng _centroCidade(String cidade) {
  switch (cidade) {
    case 'Campinas':
      return const LatLng(-22.9056, -47.0608);
    case 'Jundiaí':
      return const LatLng(-23.1857, -46.8978);
    default:
      return const LatLng(-23.5505, -46.6333);
  }
}

class ResultadosPage extends StatelessWidget {
  const ResultadosPage({
    super.key,
    required this.documentos,
    required this.aoAbrir,
    required this.aoEditar,
    required this.aoExcluir,
    required this.aoFavoritar,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> documentos;
  final void Function(DocumentSnapshot<Map<String, dynamic>>) aoAbrir;
  final void Function(DocumentSnapshot<Map<String, dynamic>>) aoEditar;
  final void Function(DocumentSnapshot<Map<String, dynamic>>) aoExcluir;
  final void Function(DocumentSnapshot<Map<String, dynamic>>) aoFavoritar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resultados')),
      body: documentos.isEmpty
          ? const Center(child: Text('Nenhum resultado encontrado.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: documentos.length,
              itemBuilder: (_, i) {
                final d = documentos[i];
                return CartaoLocal(
                  documento: d,
                  aoAbrir: () => aoAbrir(d),
                  aoEditar: () => aoEditar(d),
                  aoExcluir: () => aoExcluir(d),
                  aoFavoritar: () => aoFavoritar(d),
                );
              },
            ),
    );
  }
}

class CartaoLocal extends StatelessWidget {
  const CartaoLocal({
    super.key,
    required this.documento,
    required this.aoAbrir,
    required this.aoEditar,
    required this.aoExcluir,
    required this.aoFavoritar,
  });

  final DocumentSnapshot<Map<String, dynamic>> documento;
  final VoidCallback aoAbrir;
  final VoidCallback aoEditar;
  final VoidCallback aoExcluir;
  final VoidCallback aoFavoritar;

  @override
  Widget build(BuildContext context) {
    final d = documento.data() ?? {};
    final nome = d['nome']?.toString() ?? 'Sem nome';
    final categoria = d['categoria']?.toString() ?? 'Outro';
    final cidade = d['cidade']?.toString() ?? '';
    final favorito = d['favorito'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: aoAbrir,
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(9)),
          child: Icon(_icone(categoria), color: verde, size: 28),
        ),
        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$categoria • $cidade'),
              Text('📍 ${d['distancia'] ?? '-'} km   ★ ${d['avaliacao'] ?? '-'}'),
              if ((d['horario'] ?? '').toString().isNotEmpty) Text('Aberto/horário: ${d['horario']}'),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'detalhes') aoAbrir();
            if (v == 'editar') aoEditar();
            if (v == 'excluir') aoExcluir();
            if (v == 'favorito') aoFavoritar();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'detalhes', child: Text('Ver detalhes')),
            const PopupMenuItem(value: 'editar', child: Text('Editar')),
            PopupMenuItem(value: 'favorito', child: Text(favorito ? 'Remover favorito' : 'Favoritar')),
            const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
          ],
          child: const Icon(Icons.more_vert),
        ),
      ),
    );
  }
}

class DetalhesLocal extends StatelessWidget {
  const DetalhesLocal({
    super.key,
    required this.documento,
    required this.aoEditar,
    required this.aoFavoritar,
    required this.aoExcluir,
  });

  final DocumentSnapshot<Map<String, dynamic>> documento;
  final VoidCallback aoEditar;
  final VoidCallback aoFavoritar;
  final VoidCallback aoExcluir;

  @override
  Widget build(BuildContext context) {
    final d = documento.data() ?? {};
    final nome = d['nome']?.toString() ?? 'Estabelecimento';
    final favorito = d['favorito'] == true;
    final lat = (d['latitude'] as num?)?.toDouble();
    final lng = (d['longitude'] as num?)?.toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do local'),
        actions: [
          IconButton(
            tooltip: favorito ? 'Remover favorito' : 'Favoritar',
            onPressed: aoFavoritar,
            icon: Icon(favorito ? Icons.favorite : Icons.favorite_border),
          ),
          IconButton(tooltip: 'Editar', onPressed: aoEditar, icon: const Icon(Icons.edit)),
          IconButton(tooltip: 'Excluir', onPressed: aoExcluir, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 190,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Icon(Icons.image_outlined, size: 72, color: Colors.white)),
          ),
          const SizedBox(height: 18),
          Text(nome, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          Text('${d['categoria'] ?? 'Outro'} • ${d['cidade'] ?? ''}'),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber),
              const SizedBox(width: 4),
              Text('${d['avaliacao'] ?? '-'}'),
              const SizedBox(width: 18),
              const Icon(Icons.location_on_outlined),
              const SizedBox(width: 4),
              Text('${d['distancia'] ?? '-'} km'),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.access_time, color: verde),
              title: const Text('Horário de funcionamento'),
              subtitle: Text(d['horario']?.toString().isNotEmpty == true ? d['horario'].toString() : 'Não informado'),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Sobre', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(d['descricao']?.toString().isNotEmpty == true ? d['descricao'].toString() : 'Nenhuma descrição cadastrada.'),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: lat != null && lng != null
                ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapaLocalPage(nome: nome, latitude: lat, longitude: lng)))
                : () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cadastre latitude e longitude para ver este local no mapa.')),
                  ),
            icon: const Icon(Icons.location_on),
            label: const Text('Ver no mapa'),
          ),
        ],
      ),
    );
  }
}

class MapaLocalPage extends StatelessWidget {
  const MapaLocalPage({super.key, required this.nome, required this.latitude, required this.longitude});
  final String nome;
  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    final posicao = LatLng(latitude, longitude);
    return Scaffold(
      appBar: AppBar(title: Text(nome)),
      body: FlutterMap(
        options: MapOptions(initialCenter: posicao, initialZoom: 16),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.formativa',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: posicao,
                width: 170,
                height: 60,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      color: Colors.white,
                      child: Text(nome, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const Icon(Icons.location_on, color: verde, size: 30),
                  ],
                ),
              ),
            ],
          ),
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution(
                'OpenStreetMap contributors',
                onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FormularioLocal extends StatefulWidget {
  const FormularioLocal({super.key, required this.dados, required this.editando});
  final Map<String, dynamic> dados;
  final bool editando;

  @override
  State<FormularioLocal> createState() => _FormularioLocalState();
}

class _FormularioLocalState extends State<FormularioLocal> {
  final chave = GlobalKey<FormState>();
  late final TextEditingController nome;
  late final TextEditingController avaliacao;
  late final TextEditingController distancia;
  late final TextEditingController horario;
  late final TextEditingController descricao;
  late final TextEditingController latitude;
  late final TextEditingController longitude;
  late String cidade;
  late String categoria;
  late bool favorito;

  @override
  void initState() {
    super.initState();
    final d = widget.dados;
    nome = TextEditingController(text: d['nome']?.toString() ?? '');
    avaliacao = TextEditingController(text: d['avaliacao']?.toString() ?? '4.0');
    distancia = TextEditingController(text: d['distancia']?.toString() ?? '1.0');
    horario = TextEditingController(text: d['horario']?.toString() ?? '08:00 às 22:00');
    descricao = TextEditingController(text: d['descricao']?.toString() ?? '');
    latitude = TextEditingController(text: d['latitude']?.toString() ?? '');
    longitude = TextEditingController(text: d['longitude']?.toString() ?? '');
    cidade = cidades.contains(d['cidade']) ? d['cidade'] as String : cidades.first;
    categoria = categorias.contains(d['categoria']) ? d['categoria'] as String : categorias.first;
    favorito = d['favorito'] == true;
  }

  @override
  void dispose() {
    nome.dispose();
    avaliacao.dispose();
    distancia.dispose();
    horario.dispose();
    descricao.dispose();
    latitude.dispose();
    longitude.dispose();
    super.dispose();
  }

  String? numeroValido(String? v, String nomeCampo, {double? maximo}) {
    final n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
    if (n == null || !n.isFinite) return 'Informe $nomeCampo válido.';
    if (n < 0 || (maximo != null && n > maximo)) return 'Valor fora do limite permitido.';
    return null;
  }

  void salvar() {
    if (!chave.currentState!.validate()) return;
    final lat = latitude.text.trim().isEmpty ? null : double.tryParse(latitude.text.trim().replaceAll(',', '.'));
    final lng = longitude.text.trim().isEmpty ? null : double.tryParse(longitude.text.trim().replaceAll(',', '.'));
    if ((lat == null) != (lng == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha latitude e longitude juntas, ou deixe ambas vazias.')));
      return;
    }
    if (lat != null && (lat < -90 || lat > 90 || lng! < -180 || lng > 180)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Latitude ou longitude fora do intervalo válido.')));
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'nome': nome.text.trim(),
      'categoria': categoria,
      'cidade': cidade,
      'avaliacao': double.parse(avaliacao.text.trim().replaceAll(',', '.')),
      'distancia': double.parse(distancia.text.trim().replaceAll(',', '.')),
      'horario': horario.text.trim(),
      'descricao': descricao.text.trim(),
      'favorito': favorito,
      if (lat != null && lng != null) 'latitude': lat,
      if (lat != null && lng != null) 'longitude': lng,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.editando ? 'Editar estabelecimento' : 'Novo estabelecimento'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: chave,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: nome, decoration: const InputDecoration(labelText: 'Nome *'), validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome.' : null),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: categoria,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: categorias.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => categoria = v ?? categorias.first),
                ),
                DropdownButtonFormField<String>(
                  value: cidade,
                  decoration: const InputDecoration(labelText: 'Cidade'),
                  items: cidades.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => cidade = v ?? cidades.first),
                ),
                TextFormField(controller: avaliacao, decoration: const InputDecoration(labelText: 'Avaliação (0–5)'), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => numeroValido(v, 'uma avaliação', maximo: 5)),
                TextFormField(controller: distancia, decoration: const InputDecoration(labelText: 'Distância em km'), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => numeroValido(v, 'uma distância')),
                TextFormField(controller: horario, decoration: const InputDecoration(labelText: 'Horário de funcionamento')),
                TextFormField(controller: descricao, decoration: const InputDecoration(labelText: 'Descrição'), minLines: 2, maxLines: 4),
                const Divider(),
                const Align(alignment: Alignment.centerLeft, child: Text('Localização no mapa (opcional)', style: TextStyle(fontWeight: FontWeight.bold))),
                TextFormField(controller: latitude, decoration: const InputDecoration(labelText: 'Latitude', hintText: '-23.5505'), keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true)),
                TextFormField(controller: longitude, decoration: const InputDecoration(labelText: 'Longitude', hintText: '-46.6333'), keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true)),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Favorito'), value: favorito, onChanged: (v) => setState(() => favorito = v)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton.icon(onPressed: salvar, icon: const Icon(Icons.save), label: const Text('Salvar')),
      ],
    );
  }
}

IconData _icone(String categoria) {
  switch (categoria.toLowerCase()) {
    case 'academia': return Icons.fitness_center;
    case 'restaurante': return Icons.restaurant;
    case 'cafeteria': return Icons.coffee;
    case 'hospital': return Icons.local_hospital;
    case 'farmácia':
    case 'farmacia': return Icons.local_pharmacy;
    case 'parque': return Icons.park;
    case 'shopping': return Icons.shopping_bag;
    case 'hotel': return Icons.hotel;
    default: return Icons.place;
  }
}
