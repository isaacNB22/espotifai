import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' hide Playlist;
import 'models/playlist.dart';
import 'models/song.dart';
import 'screens/import_screen.dart';
import 'screens/library_screen.dart';
import 'screens/playlist_detail_screen.dart';
import 'screens/search_screen.dart';
import 'screens/stats_screen.dart';
import 'services/api_service.dart';
import 'services/player_service.dart';
import 'theme/app_theme.dart';
import 'widgets/player_bar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const EspotifaiApp());
}

class EspotifaiApp extends StatefulWidget {
  const EspotifaiApp({super.key});

  // ignore: library_private_types_in_public_api
  static _EspotifaiAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_EspotifaiAppState>()!;

  @override
  State<EspotifaiApp> createState() => _EspotifaiAppState();
}

class _EspotifaiAppState extends State<EspotifaiApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  bool get isDark => _themeMode == ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Espotifai',
      debugShowCheckedModeBanner: false,
      theme: lightTheme(),
      darkTheme: darkTheme(),
      themeMode: _themeMode,
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final ApiService _api;
  late final PlayerService _player;

  int _currentIndex = 0;
  bool _railExtended = false;
  List<Song> _library = [];
  bool _libraryLoaded = false;
  List<Playlist> _playlists = [];
  // Playlist abierta en el detalle (sin push de ruta, vive dentro del shell)
  Playlist? _detailPlaylist;
  Map<String, double> _downloadProgress = {}; // videoId -> 0.0..1.0

  @override
  void initState() {
    super.initState();
    _api = ApiService();
    _player = PlayerService(api: _api);
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    try {
      final songs = await _api.getLibrary();
      setState(() {
        _library = songs;
        _libraryLoaded = true;
      });
    } catch (_) {
      setState(() => _libraryLoaded = true);
    }
  }

  Future<void> _addToLibrary(Song song) async {
    try {
      final saved = await _api.addToLibrary(song);
      setState(() {
        if (!_library.any((s) => s.videoId == saved.videoId)) {
          _library = [..._library, saved];
        }
      });
      if (mounted) {
        _showSnack('${song.title} agregada a tu biblioteca');
      }
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, error: true);
    }
  }

  Future<void> _removeFromLibrary(String videoId) async {
    try {
      await _api.removeFromLibrary(videoId);
      setState(
        () => _library = _library.where((s) => s.videoId != videoId).toList(),
      );
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, error: true);
    }
  }

  Future<void> _downloadSong(String videoId) async {
    try {
      final jobId = await _api.startDownload(videoId);
      setState(() => _downloadProgress = {..._downloadProgress, videoId: 0.01});
      _pollDownload(jobId, videoId);
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, error: true);
    }
  }

  Future<void> _pollDownload(String jobId, String videoId) async {
    // Simula avance de barra hasta 0.9 mientras espera
    double fakeProgress = 0.05;
    while (true) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final status = await _api.getDownloadStatus(jobId);
        final state = status['status'] as String? ?? '';
        if (state == 'done') {
          setState(() {
            _downloadProgress = {..._downloadProgress, videoId: 1.0};
            _library =
                _library
                    .map(
                      (s) =>
                          s.videoId == videoId
                              ? s.copyWith(downloaded: true)
                              : s,
                    )
                    .toList();
          });
          // Quitar el indicador después de mostrar el checkmark brevemente
          await Future.delayed(const Duration(seconds: 2));
          setState(() {
            final updated = Map<String, double>.from(_downloadProgress);
            updated.remove(videoId);
            _downloadProgress = updated;
          });
          break;
        } else if (state == 'error') {
          setState(() {
            final updated = Map<String, double>.from(_downloadProgress);
            updated.remove(videoId);
            _downloadProgress = updated;
          });
          if (mounted) _showSnack('Error en la descarga', error: true);
          break;
        } else {
          // Avanza la barra lentamente hasta 0.88
          fakeProgress = (fakeProgress + 0.04).clamp(0.0, 0.88);
          setState(
            () =>
                _downloadProgress = {
                  ..._downloadProgress,
                  videoId: fakeProgress,
                },
          );
        }
      } catch (_) {
        break;
      }
    }
  }

  void _onImported(List<Song> songs) {
    setState(() {
      for (final s in songs) {
        if (!_library.any((e) => e.videoId == s.videoId)) {
          _library = [..._library, s];
        }
      }
    });
  }

  void _createPlaylist(Playlist p) {
    setState(() => _playlists = [..._playlists, p]);
  }

  void _deletePlaylist(String id) {
    setState(() => _playlists = _playlists.where((p) => p.id != id).toList());
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            error
                ? Theme.of(context).colorScheme.error
                : const Color(0xFF1DB954),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = EspotifaiApp.of(context);
    final dark = appState.isDark;
    final screens = <Widget>[
      SearchScreen(api: _api, player: _player, onAddToLibrary: _addToLibrary),
      _libraryLoaded
          ? _detailPlaylist != null
              ? PlaylistDetailScreen(
                playlist: _detailPlaylist!,
                allSongs: _library,
                player: _player,
                onRemoveSong: _removeFromLibrary,
                onDownload: _downloadSong,
                downloadProgress: _downloadProgress,
                onBack: () => setState(() => _detailPlaylist = null),
              )
              : LibraryScreen(
                player: _player,
                songs: _library,
                playlists: _playlists,
                onRemove: _removeFromLibrary,
                onDownload: _downloadSong,
                downloadProgress: _downloadProgress,
                onCreatePlaylist: _createPlaylist,
                onDeletePlaylist: _deletePlaylist,
                onOpenPlaylist: (p) => setState(() => _detailPlaylist = p),
              )
          : const Center(child: CircularProgressIndicator()),
      ImportScreen(api: _api, onImported: _onImported),
      StatsScreen(api: _api, libraryCount: _library.length),
    ];

    const destinations = [
      NavigationRailDestination(
        icon: Icon(Icons.search_rounded),
        label: Text('Buscar'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.library_music_rounded),
        label: Text('Biblioteca'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.add_link_rounded),
        label: Text('Importar'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.bar_chart_rounded),
        label: Text('Stats'),
      ),
    ];

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  extended: _railExtended,
                  selectedIndex: _currentIndex,
                  onDestinationSelected:
                      (i) => setState(() => _currentIndex = i),
                  leading: Column(
                    children: [
                      const SizedBox(height: 8),
                      // Logo + toggle
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap:
                            () =>
                                setState(() => _railExtended = !_railExtended),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1DB954),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.music_note,
                                  size: 17,
                                  color: Colors.black,
                                ),
                              ),
                              if (_railExtended) ...[
                                const SizedBox(width: 10),
                                const Text(
                                  'espotifai',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: IconButton(
                          icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
                          tooltip: dark ? 'Modo claro' : 'Modo oscuro',
                          onPressed: appState.toggleTheme,
                        ),
                      ),
                    ),
                  ),
                  destinations: destinations,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: screens[_currentIndex]),
              ],
            ),
          ),
          PlayerBar(player: _player),
        ],
      ),
    );
  }
}
