import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';

/// Persiste las playlists del usuario en shared_preferences.
class PlaylistService {
  static const _key = 'user_playlists';

  Future<List<Playlist>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<Playlist> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    // Solo guardamos playlists de usuario (no auto-playlists)
    final userPlaylists = playlists.where((p) => !p.isAuto).toList();
    await prefs.setString(
      _key,
      jsonEncode(userPlaylists.map((p) => p.toJson()).toList()),
    );
  }
}
