import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lastfm_track.dart';
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
  Future<List<Song>> search(
    String query, {
    String? duration, // 'short' | 'medium' | 'long'
    String? publishedAfter, // 'YYYY-MM-DD'
  }) async {
    final params = <String, String>{'q': query};
    if (duration != null) params['duration'] = duration;
    if (publishedAfter != null) params['publishedAfter'] = publishedAfter;
    final uri = Uri.parse(
      '$kBaseUrl/api/search',
    ).replace(queryParameters: params);
    final res = await _client.get(uri);
    _checkStatus(res);
    final body = jsonDecode(res.body);
    final List<dynamic> data =
        (body is Map ? body['results'] : body) as List<dynamic>;
    return data.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Busca tracks en Last.fm (sin costar quota de YouTube).
  /// Los resultados NO tienen videoId — se resuelve con [resolveVideoId] al reproducir.
  Future<List<LastfmTrack>> searchLastfm(String query) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse(
      '$kBaseUrl/api/lastfm/search',
    ).replace(queryParameters: {'q': query.trim(), 'limit': '12'});
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
      return data
          .map((e) => LastfmTrack.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Resuelve el videoId de YouTube para un track de Last.fm.
  /// Costo: 100 unidades de quota. Llamar solo al reproducir.
  Future<String?> resolveVideoId({
    required String track,
    required String artist,
  }) async {
    final uri = Uri.parse(
      '$kBaseUrl/api/lastfm/resolve',
    ).replace(queryParameters: {'track': track, 'artist': artist});
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return json['videoId'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Sugerencias de autocompletado (sin quota — API pública de Google).
  Future<List<String>> searchSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse(
      '$kBaseUrl/api/search/suggestions',
    ).replace(queryParameters: {'q': query.trim()});
    try {
      final res = await _client.get(uri);
      if (res.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
      return data.cast<String>();
    } catch (_) {
      return [];
    }
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
    final res = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'url': url}),
        )
        .timeout(const Duration(seconds: 60));
    _checkStatus(res);
    final dynamic decoded = jsonDecode(res.body);
    if (decoded is! List)
      throw ApiException(500, 'Respuesta inesperada del servidor');
    return decoded
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList();
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

  // ─── Last.fm ─────────────────────────────────────────────────────────────

  /// Canciones en tendencia global (chart.getTopTracks).
  Future<List<LastfmTrack>> chartTracks() =>
      _lastfmGet('/api/lastfm/chart/tracks');

  /// Artistas en tendencia global (chart.getTopArtists). Devuelve lista de maps.
  Future<List<Map<String, dynamic>>> chartArtists() async {
    final uri = Uri.parse('$kBaseUrl/api/lastfm/chart/artists');
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Top tracks de un artista específico.
  Future<List<LastfmTrack>> artistTopTracks(String artist) =>
      _lastfmGet('/api/lastfm/artist/top', params: {'artist': artist});

  /// Canciones similares a una canción de la biblioteca.
  Future<List<LastfmTrack>> similarTracks({
    required String track,
    required String artist,
  }) => _lastfmGet(
    '/api/lastfm/similar',
    params: {'track': track, 'artist': artist},
  );

  /// Nuevos lanzamientos basados en artistas favoritos (CSV).
  Future<List<LastfmTrack>> newReleases({List<String> artists = const []}) =>
      _lastfmGet(
        '/api/lastfm/new-releases',
        params: artists.isEmpty ? {} : {'artists': artists.join(',')},
      );

  Future<List<LastfmTrack>> _lastfmGet(
    String path, {
    Map<String, String> params = const {},
  }) async {
    final uri = Uri.parse(
      '$kBaseUrl$path',
    ).replace(queryParameters: params.isEmpty ? null : params);
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
      return data
          .map((e) => LastfmTrack.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Deezer ──────────────────────────────────────────────────────────────

  /// Artistas trending del chart de Deezer.
  Future<List<Map<String, dynamic>>> deezerTrendingArtists({
    int limit = 12,
  }) async {
    final uri = Uri.parse(
      '$kBaseUrl/api/deezer/trending-artists',
    ).replace(queryParameters: {'limit': '$limit'});
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Géneros musicales de Deezer con imagen.
  Future<List<Map<String, dynamic>>> deezerGenres() async {
    final uri = Uri.parse('$kBaseUrl/api/deezer/genres');
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Busca un artista por nombre en Deezer y devuelve su id + info básica.
  Future<Map<String, dynamic>?> deezerSearchArtist(String name) async {
    final uri = Uri.parse(
      '$kBaseUrl/api/deezer/search-artist',
    ).replace(queryParameters: {'q': name});
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Detalle completo de un artista Deezer: info, top tracks, álbumes, relacionados.
  Future<Map<String, dynamic>?> deezerArtist(dynamic id) async {
    final uri = Uri.parse('$kBaseUrl/api/deezer/artist/$id');
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

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
