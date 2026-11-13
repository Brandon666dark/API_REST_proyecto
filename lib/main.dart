import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

// ---------- MODELO ----------
class Personaje {
  final int id;
  final String nombre;
  final String? imagen;
  final String aldea;
  final String clan;
  final String cumple;
  final String sexo;
  final String debut;

  Personaje({
    required this.id,
    required this.nombre,
    this.imagen,
    required this.aldea,
    required this.clan,
    required this.cumple,
    required this.sexo,
    required this.debut,
  });

  factory Personaje.fromJson(Map<String, dynamic> json) {
    final imagenes = json['images'];
    final personal = (json['personal'] is Map) ? json['personal'] as Map : {};
    final debut = (json['debut'] is Map) ? json['debut'] as Map : {};

    String texto(dynamic v) {
      if (v == null) return 'Desconocido';
      if (v is List) return v.isEmpty ? 'Desconocido' : v.join(', ');
      return v.toString();
    }

    return Personaje(
      id: json['id'] ?? 0,
      nombre: json['name'] ?? 'Sin nombre',
      imagen: (imagenes is List && imagenes.isNotEmpty) ? imagenes.first : null,
      aldea: texto(personal['affiliation']),
      clan: texto(personal['clan']),
      cumple: texto(personal['birthdate']),
      sexo: texto(personal['sex']),
      debut: texto(debut['anime']),
    );
  }
}

// ---------- SERVICIO (solo GET) ----------
class ApiService {
  static const String _baseUrl = 'https://dattebayo-api.onrender.com/characters';

  Future<List<Personaje>> obtenerPersonajes({
    int pagina = 1,
    int limite = 20,
    String nombre = '',
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'page': '$pagina',
      'limit': '$limite',
      if (nombre.isNotEmpty) 'name': nombre,
    });

    final respuesta = await http.get(uri).timeout(const Duration(seconds: 40));

    if (respuesta.statusCode == 200) {
      final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
      final lista = (datos['characters'] ?? []) as List;
      return lista.map((e) => Personaje.fromJson(e)).toList();
    } else if (respuesta.statusCode == 404) {
      return [];
    } else {
      throw Exception('Error ${respuesta.statusCode}');
    }
  }
}

// ---------- APP ----------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Naruto App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
        home: const ListaPage(),
      );
}

class ListaPage extends StatefulWidget {
  const ListaPage({super.key});

  @override
  State<ListaPage> createState() => _ListaPageState();
}

class _ListaPageState extends State<ListaPage> {
  final _api = ApiService();
  final _scroll = ScrollController();
  final _controller = TextEditingController();
  int _peticion = 0; // identifica la búsqueda vigente
  final List<Personaje> _personajes = [];

  int _pagina = 1;
  String _busqueda = '';
  bool _cargando = false;
  bool _hayMas = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        _cargar();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (_cargando || !_hayMas) return;
    final token = _peticion;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final nuevos = await _api.obtenerPersonajes(pagina: _pagina, nombre: _busqueda);
      if (token != _peticion) return; // llegó una respuesta de una búsqueda vieja
      setState(() {
        _personajes.addAll(nuevos);
        _hayMas = nuevos.length >= 20;
        _pagina++;
      });
    } catch (e) {
      if (token == _peticion) setState(() => _error = e.toString());
    } finally {
      if (token == _peticion) setState(() => _cargando = false);
    }
  }

  void _buscar(String texto) {
    FocusScope.of(context).unfocus(); // cierra el teclado
    setState(() {
      _peticion++; // invalida cualquier petición en curso
      _busqueda = texto.trim();
      _personajes.clear();
      _pagina = 1;
      _hayMas = true;
      _cargando = false;
      _error = null;
    });
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personajes de Naruto')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _buscar,
              decoration: InputDecoration(
                hintText: 'Buscar personaje (ej. Naruto)...',
                border: const OutlineInputBorder(),
                prefixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _buscar(_controller.text),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    _buscar('');
                  },
                ),
              ),
            ),
          ),
          Expanded(child: _contenido()),
        ],
      ),
    );
  }

  Widget _contenido() {
    if (_personajes.isEmpty) {
      if (_cargando) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Cargando... (el servidor puede tardar en despertar)'),
            ],
          ),
        );
      }
      if (_error != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $_error'),
              const SizedBox(height: 8),
              FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        );
      }
      return const Center(child: Text('Sin resultados'));
    }

    return ListView.builder(
      controller: _scroll,
      itemCount: _personajes.length + (_cargando ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _personajes.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final p = _personajes[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: p.imagen != null ? NetworkImage(p.imagen!) : null,
            child: p.imagen == null ? const Icon(Icons.person) : null,
          ),
          title: Text(p.nombre),
          subtitle: Text('Clan: ${p.clan}'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetallePage(personaje: p)),
          ),
        );
      },
    );
  }
}

class DetallePage extends StatelessWidget {
  final Personaje personaje;
  const DetallePage({super.key, required this.personaje});

  @override
  Widget build(BuildContext context) {
    final p = personaje;
    return Scaffold(
      appBar: AppBar(title: Text(p.nombre)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (p.imagen != null)
            Center(
              child: Image.network(
                p.imagen!,
                height: 280,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 80),
              ),
            ),
          const SizedBox(height: 16),
          Text(p.nombre, style: Theme.of(context).textTheme.headlineSmall),
          const Divider(),
          _fila('Afiliación', p.aldea),
          _fila('Clan', p.clan),
          _fila('Cumpleaños', p.cumple),
          _fila('Sexo', p.sexo),
          _fila('Debut (anime)', p.debut),
        ],
      ),
    );
  }

  Widget _fila(String titulo, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$titulo: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: valor),
        ])),
      );
}
