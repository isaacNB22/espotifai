import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

/// URL base del servidor Node.js. Cambiar en producción o leer de config.
const String kBaseUrl = 'http://localhost:3000';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  // ─── Búsqueda ────────────────────────────────────────────────────────────

  /// Busca canciones en YouTube vía el servidor.
  Future<List<Song>> search(String query) async {
    final uri = Uri.parse(
      '$kBaseUrl/api/search',
    ).replace(queryParameters: {'q': query});
    final res = await _client.get(uri);
    _checkStatus(res);
    final body = jsonDecode(res.body);
    // El servidor devuelve { results: [...], quota: {...} }
    final List<dynamic> data =
        (body is Map ? body['results'] : body) as List<dynamic>;
    return data.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Biblioteca ──────────────────────────────────────────────────────────

  /// Obtiene todas las canciones guardadas en la biblioteca.
  Future<List<Song>> getLibrary() async {
    final uri = Uri.parse('$kBaseUrl/api/library');
    final res = await _client.get(uri);
    _checkStatus(res);
    final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
    return data.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Agrega una canción a la biblioteca.
  Future<Song> addToLibrary(Song song) async {
    final uri = Uri.parse('$kBaseUrl/api/library');
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(song.toJson()),
    );
    _checkStatus(res);
    return Song.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Elimina una canción de la biblioteca por videoId.
  Future<void> removeFromLibrary(String videoId) async {
    final uri = Uri.parse('$kBaseUrl/api/library/$videoId');
    final res = await _client.delete(uri);
    _checkStatus(res);
  }

  // ─── Descarga ────────────────────────────────────────────────────────────

  /// Inicia la descarga de una canción. Devuelve el jobId.
  Future<String> startDownload(String videoId) async {
    final uri = Uri.parse('$kBaseUrl/api/download');
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'videoId': videoId}),
    );
    _checkStatus(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['jobId'] as String;
  }

  /// Consulta el estado de una descarga en curso.
  Future<Map<String, dynamic>> getDownloadStatus(String jobId) async {
    final uri = Uri.parse('$kBaseUrl/api/download/status/$jobId');
    final res = await _client.get(uri);
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ─── Importar por URL ────────────────────────────────────────────────────

  /// Importa una canción o playlist desde una URL de YouTube.
  Future<List<Song>> importUrl(String url) async {
    final uri = Uri.parse('$kBaseUrl/api/library/import');
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': url}),
    );
    _checkStatus(res);
    final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
    return data.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Stats ───────────────────────────────────────────────────────────────

  /// Obtiene las estadísticas de cuota de la API.
  Future<Map<String, dynamic>> getStats() async {
    final uri = Uri.parse('$kBaseUrl/api/stats');
    final res = await _client.get(uri);
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ─── Stream URL ──────────────────────────────────────────────────────────

  /// Devuelve la URL de streaming para un videoId.
  String streamUrl(String videoId) => '$kBaseUrl/api/stream/$videoId';

  // ─── Privado ─────────────────────────────────────────────────────────────

  void _checkStatus(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String message = res.body;
      try {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        message = json['error'] as String? ?? message;
      } catch (_) {}
      throw ApiException(res.statusCode, message);
    }
  }

  void dispose() => _client.close();
}
