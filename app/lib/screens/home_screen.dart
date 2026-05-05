import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lastfm_track.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../services/player_service.dart';
import 'artist_screen.dart';

class HomeScreen extends StatefulWidget {
  final ApiService api;
  final PlayerService player;
  final List<Song> library;
  final List<Playlist> playlists;
  final void Function(Song) onAddToLibrary;
  final void Function(Playlist) onOpenPlaylist;
  final void Function(Song, Playlist) onAddToPlaylist;

  const HomeScreen({
    super.key,
    required this.api,
    required this.player,
    required this.library,
    required this.playlists,
    required this.onAddToLibrary,
    required this.onOpenPlaylist,
    required this.onAddToPlaylist,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  // ── Estado de datos ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> _artists = [];
  List<Map<String, dynamic>> _genres = [];
  bool _loadingArtists = true;
  bool _loadingGenres = true;

  // ── Búsqueda integrada ────────────────────────────────────────────────────
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  List<LastfmTrack> _searchResults = [];
  bool _searchLoading = false;
  bool _showResults = false;
  final Map<String, String?> _resolved = {};
  final Set<String> _resolving = {};
  Timer? _debounce;
  List<String> _history = [];
  List<String> _suggestions = [];
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    _loadArtists();
    _loadGenres();
    _loadHistory();
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus) {
        setState(() => _showOverlay = true);
      } else {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _showOverlay = false);
        });
      }
    });
    _searchController.addListener(() {
      setState(() => _showOverlay = _searchFocus.hasFocus);
      _debounce?.cancel();
      final q = _searchController.text.trim();
      if (q.isEmpty) {
        setState(() => _suggestions = []);
        return;
      }
      _debounce = Timer(const Duration(milliseconds: 350), () async {
        final s = await widget.api.searchSuggestions(q);
        if (mounted) setState(() => _suggestions = s);
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Carga de datos ────────────────────────────────────────────────────────

  Future<void> _loadArtists() async {
    setState(() => _loadingArtists = true);
    final artists = await widget.api.deezerTrendingArtists(limit: 10);
    if (mounted)
      setState(() {
        _artists = artists;
        _loadingArtists = false;
      });
  }

  Future<void> _loadGenres() async {
    setState(() => _loadingGenres = true);
    final genres = await widget.api.deezerGenres();
    if (mounted)
      setState(() {
        _genres = genres.take(6).toList();
        _loadingGenres = false;
      });
  }

  // ── Historial ─────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted)
      setState(() => _history = prefs.getStringList('search_history') ?? []);
  }

  Future<void> _saveToHistory(String q) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('search_history') ?? [];
    list.remove(q);
    list.insert(0, q);
    if (list.length > 20) list.removeLast();
    await prefs.setStringList('search_history', list);
    if (mounted) setState(() => _history = list);
  }

  Future<void> _removeHistory(String q) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('search_history') ?? [];
    list.remove(q);
    await prefs.setStringList('search_history', list);
    if (mounted) setState(() => _history = list);
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    if (mounted) setState(() => _history = []);
  }

  // ── Búsqueda ──────────────────────────────────────────────────────────────

  Future<void> _doSearch(String q) async {
    q = q.trim();
    if (q.isEmpty) return;
    _searchFocus.unfocus();
    _saveToHistory(q);
    setState(() {
      _showOverlay = false;
      _suggestions = [];
      _searchLoading = true;
      _showResults = true;
      _resolved.clear();
      _resolving.clear();
    });
    final results = await widget.api.searchLastfm(q);
    if (mounted)
      setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
  }

  Future<void> _resolveAndDo(
    LastfmTrack t,
    void Function(String) action,
  ) async {
    final key = '${t.artist}|${t.title}';
    if (_resolved.containsKey(key)) {
      final id = _resolved[key];
      if (id != null) action(id);
      return;
    }
    // Si ya se está resolviendo, esperar a que termine
    if (_resolving.contains(key)) {
      // Reintentar tras resolver
      while (_resolving.contains(key)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (!mounted) return;
      final id = _resolved[key];
      if (id != null) action(id);
      return;
    }
    setState(() => _resolving.add(key));
    final id = await widget.api.resolveVideoId(
      track: t.title,
      artist: t.artist,
    );
    if (!mounted) return;
    setState(() {
      _resolved[key] = id;
      _resolving.remove(key);
    });
    if (id != null) action(id);
  }

  Song _toSongResolved(LastfmTrack t, String videoId) => Song(
    videoId: videoId,
    title: t.title,
    artist: t.artist,
    thumbnail: t.thumbnail,
  );

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<Playlist> get _autoPlaylists => [
    Playlist(
      id: 'auto_downloaded',
      name: 'Descargadas',
      videoIds: const [],
      color: const Color(0xFF1DB954),
      icon: Icons.download_done_rounded,
      isAuto: true,
    ),
    Playlist(
      id: 'auto_pending',
      name: 'Sin descargar',
      videoIds: const [],
      color: const Color(0xFF5B8FD4),
      icon: Icons.cloud_download_rounded,
      isAuto: true,
    ),
  ];

  List<Playlist> get _userPlaylists => [
    ..._autoPlaylists,
    ...widget.playlists.where((p) => !p.isAuto),
  ];

  List<Song> get _recentSongs {
    final sorted = [...widget.library]..sort(
      (a, b) => (b.addedAt ?? DateTime(0)).compareTo(a.addedAt ?? DateTime(0)),
    );
    return sorted.take(6).toList();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final currentSong = widget.player.currentSong;
    final bg = dark ? const Color(0xFF121212) : const Color(0xFFF8F8F8);

    return Navigator(
      key: _navigatorKey,
      onGenerateRoute:
          (_) => MaterialPageRoute(
            builder: (_) => _buildHomeContent(dark, currentSong, bg),
          ),
    );
  }

  Widget _buildHomeContent(bool dark, Song? currentSong, Color bg) {
    return ColoredBox(
      color: bg,
      child: Column(
        children: [
          // ── Barra de búsqueda ──────────────────────────────────────────────
          _SearchBar(
            controller: _searchController,
            focusNode: _searchFocus,
            loading: _searchLoading,
            hasText: _showResults || _searchController.text.isNotEmpty,
            dark: dark,
            onSubmit: _doSearch,
            onClear: () {
              _searchController.clear();
              setState(() {
                _showResults = false;
                _searchResults = [];
              });
            },
          ),

          // ── Contenido + overlay flotante ───────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                // Contenido principal
                _showResults
                    ? _SearchResultsView(
                      results: _searchResults,
                      loading: _searchLoading,
                      dark: dark,
                      currentId: currentSong?.videoId,
                      resolved: _resolved,
                      resolving: _resolving,
                      playlists: widget.playlists,
                      onPlay:
                          (t) => _resolveAndDo(
                            t,
                            (id) => widget.player.play(_toSongResolved(t, id)),
                          ),
                      onAdd:
                          (t) => _resolveAndDo(
                            t,
                            (id) =>
                                widget.onAddToLibrary(_toSongResolved(t, id)),
                          ),
                      onAddToQueue:
                          (t) => _resolveAndDo(
                            t,
                            (id) => widget.player.addToQueue(
                              _toSongResolved(t, id),
                            ),
                          ),
                      onPlayAsNext:
                          (t) => _resolveAndDo(
                            t,
                            (id) => widget.player.playAsNext(
                              _toSongResolved(t, id),
                            ),
                          ),
                      onAddToPlaylist:
                          (t, pl) => _resolveAndDo(
                            t,
                            (id) => widget.onAddToPlaylist(
                              _toSongResolved(t, id),
                              pl,
                            ),
                          ),
                    )
                    : RefreshIndicator(
                      color: const Color(0xFF1DB954),
                      onRefresh: () async {
                        await Future.wait([_loadArtists(), _loadGenres()]);
                      },
                      child: CustomScrollView(
                        slivers: [
                          // Saludo
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                              child: Text(
                                _greeting(),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ),

                          // ── Sección 1: Playlists recientes + última canción ──
                          _SectionHeader(title: 'Acceso rápido'),
                          SliverToBoxAdapter(
                            child: _QuickAccessRow(
                              playlists: _userPlaylists,
                              recentSongs: _recentSongs,
                              currentSong: currentSong,
                              dark: dark,
                              player: widget.player,
                              onOpenPlaylist: widget.onOpenPlaylist,
                            ),
                          ),

                          // ── Sección 2: Artistas trending Deezer ─────────────
                          _SectionHeader(title: 'Artistas en tendencia'),
                          SliverToBoxAdapter(
                            child:
                                _loadingArtists
                                    ? const _ArtistSkeleton()
                                    : _ArtistRow(
                                      artists: _artists,
                                      dark: dark,
                                      onArtistTap: (id, name, thumb) {
                                        void openArtist(
                                          dynamic aid,
                                          String an,
                                          String? at,
                                        ) {
                                          _navigatorKey.currentState!.push(
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => ArtistScreen(
                                                    api: widget.api,
                                                    player: widget.player,
                                                    artistId: aid,
                                                    artistName: an,
                                                    artistThumb: at,
                                                    onAddToLibrary:
                                                        widget.onAddToLibrary,
                                                    playlists: widget.playlists,
                                                    onAddToPlaylist:
                                                        widget.onAddToPlaylist,
                                                    onOpenArtist: openArtist,
                                                  ),
                                            ),
                                          );
                                        }

                                        openArtist(id, name, thumb);
                                      },
                                    ),
                          ),

                          // ── Sección 3: Géneros ───────────────────────────────
                          _SectionHeader(title: 'Géneros'),
                          SliverToBoxAdapter(
                            child:
                                _loadingGenres
                                    ? const _GenreSkeleton()
                                    : _GenreGrid(
                                      genres: _genres,
                                      dark: dark,
                                      onGenreTap: (name) {
                                        _searchController.text = name;
                                        _doSearch(name);
                                      },
                                    ),
                          ),

                          const SliverToBoxAdapter(child: SizedBox(height: 32)),
                        ],
                      ),
                    ),

                // Overlay flotante historial / sugerencias
                if (_showOverlay &&
                    (_searchController.text.trim().isEmpty
                        ? _history.isNotEmpty
                        : _suggestions.isNotEmpty))
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: _SuggestionsOverlay(
                          items:
                              _searchController.text.trim().isEmpty
                                  ? _history
                                  : _suggestions,
                          isHistory: _searchController.text.trim().isEmpty,
                          dark: dark,
                          onSelect: _doSearch,
                          onRemove:
                              _searchController.text.trim().isEmpty
                                  ? _removeHistory
                                  : null,
                          onClear:
                              _searchController.text.trim().isEmpty &&
                                      _history.isNotEmpty
                                  ? _clearHistory
                                  : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Barra de búsqueda ────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  final bool hasText;
  final bool dark;
  final void Function(String) onSubmit;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.loading,
    required this.hasText,
    required this.dark,
    required this.onSubmit,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color:
                    focusNode.hasFocus
                        ? const Color(0xFF1DB954)
                        : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: ListenableBuilder(
              listenable: focusNode,
              builder:
                  (_, __) => TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: 'Artistas, canciones...',
                      hintStyle: TextStyle(
                        color: dark ? Colors.white38 : Colors.black38,
                      ),
                      prefixIcon:
                          loading
                              ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF1DB954),
                                  ),
                                ),
                              )
                              : const Icon(Icons.search_rounded, size: 22),
                      suffixIcon:
                          hasText
                              ? GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onClear,
                                child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Icon(Icons.close_rounded, size: 18),
                                ),
                              )
                              : null,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onSubmitted: onSubmit,
                    textInputAction: TextInputAction.search,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Cabecera de sección ──────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

// ── Fila de acceso rápido ────────────────────────────────────────────────────

class _QuickAccessRow extends StatelessWidget {
  final List<Playlist> playlists;
  final List<Song> recentSongs;
  final Song? currentSong;
  final bool dark;
  final PlayerService player;
  final void Function(Playlist) onOpenPlaylist;

  const _QuickAccessRow({
    required this.playlists,
    required this.recentSongs,
    required this.currentSong,
    required this.dark,
    required this.player,
    required this.onOpenPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    // Solo playlists + canción actual (si hay)
    final items = <_QuickItem>[];
    for (final p in playlists) items.add(_QuickItem.playlist(p));
    if (currentSong != null) items.add(_QuickItem.song(currentSong!));

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(
          'Agrega canciones o playlists para verlas aquí',
          style: TextStyle(
            color: dark ? Colors.white38 : Colors.black38,
            fontSize: 13,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsivo: 2 cols < 500px, 3 cols < 800px, 4 cols en adelante
          int cols =
              constraints.maxWidth < 500
                  ? 2
                  : constraints.maxWidth < 800
                  ? 3
                  : 4;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisExtent: 52,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder:
                (_, i) => _QuickCard(
                  item: items[i],
                  dark: dark,
                  isCurrent: items[i].song?.videoId == currentSong?.videoId,
                  onTap: () {
                    if (items[i].playlist != null)
                      onOpenPlaylist(items[i].playlist!);
                    else if (items[i].song != null)
                      player.play(items[i].song!);
                  },
                ),
          );
        },
      ),
    );
  }
}

// ── Grid de géneros ───────────────────────────────────────────────────────────

class _GenreGrid extends StatelessWidget {
  final List<Map<String, dynamic>> genres;
  final bool dark;
  final void Function(String) onGenreTap;

  const _GenreGrid({
    required this.genres,
    required this.dark,
    required this.onGenreTap,
  });

  static const _colors = [
    Color(0xFF1E3264),
    Color(0xFF503750),
    Color(0xFF056952),
    Color(0xFF477D95),
    Color(0xFF8C1932),
    Color(0xFF2D6B4F),
    Color(0xFF4B3B8C),
    Color(0xFF8B6B3D),
    Color(0xFF1E5B5B),
    Color(0xFF6B3D3D),
    Color(0xFF3D5B8C),
    Color(0xFF5B8C3D),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          int cols =
              constraints.maxWidth < 500
                  ? 2
                  : constraints.maxWidth < 800
                  ? 3
                  : 4;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: genres.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisExtent: 52,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (_, i) {
              final g = genres[i];
              final name = g['name'] as String? ?? '';
              final thumb = g['thumbnail'] as String? ?? '';
              final color = _colors[i % _colors.length];
              return GestureDetector(
                onTap: () => onGenreTap(name),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ColoredBox(
                    color: color,
                    child: Row(
                      children: [
                        // Imagen izquierda, ancho fijo, altura completa
                        if (thumb.isNotEmpty)
                          SizedBox(
                            width: 64,
                            child: CachedNetworkImage(
                              imageUrl: thumb,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const SizedBox(),
                            ),
                          )
                        else
                          const SizedBox(width: 52),
                        // Texto derecha
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Skeleton para géneros ─────────────────────────────────────────────────────

class _GenreSkeleton extends StatelessWidget {
  const _GenreSkeleton();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = dark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          int cols =
              constraints.maxWidth < 500
                  ? 2
                  : constraints.maxWidth < 800
                  ? 3
                  : 4;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisExtent: 52,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder:
                (_, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ColoredBox(color: color),
                ),
          );
        },
      ),
    );
  }
}

class _QuickItem {
  final Playlist? playlist;
  final Song? song;
  _QuickItem.playlist(this.playlist) : song = null;
  _QuickItem.song(this.song) : playlist = null;
}

// â”€â”€ Tarjeta compacta del grid (estilo Spotify) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _QuickCard extends StatelessWidget {
  final _QuickItem item;
  final bool dark;
  final bool isCurrent;
  final VoidCallback onTap;

  const _QuickCard({
    required this.item,
    required this.dark,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1DB954);
    final bg = dark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8);
    final activeBg = dark ? const Color(0xFF1A3A25) : const Color(0xFFD0F0DC);

    final isPlaylist = item.playlist != null;
    final label = isPlaylist ? item.playlist!.name : (item.song?.title ?? '');
    final thumb = item.song?.thumbnail ?? '';
    final color = isPlaylist ? item.playlist!.color : green;
    final icon = isPlaylist ? item.playlist!.icon : null;

    return SizedBox(
      height: 52,
      child: Material(
        color: isCurrent ? activeBg : bg,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Row(
            children: [
              // Thumbnail o Ã­cono
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(6),
                ),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child:
                      isPlaylist || thumb.isEmpty
                          ? Container(
                            color: color,
                            child: Icon(
                              icon ?? Icons.music_note_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          )
                          : CachedNetworkImage(
                            imageUrl: thumb,
                            fit: BoxFit.cover,
                            errorWidget:
                                (_, __, ___) => Container(
                                  color: green.withAlpha(60),
                                  child: const Icon(
                                    Icons.music_note_rounded,
                                    color: Colors.white38,
                                  ),
                                ),
                          ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isCurrent ? green : null,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Tarjeta "Seguir escuchando" â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ArtistRow extends StatelessWidget {
  final List<Map<String, dynamic>> artists;
  final bool dark;
  final void Function(dynamic id, String name, String? thumb)? onArtistTap;

  const _ArtistRow({
    required this.artists,
    required this.dark,
    this.onArtistTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF1E3264),
      const Color(0xFF503750),
      const Color(0xFF056952),
      const Color(0xFF477D95),
      const Color(0xFF8C1932),
      const Color(0xFF2D6B4F),
      const Color(0xFF4B3B8C),
      const Color(0xFF6B4226),
    ];
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: artists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final a = artists[i];
          final name = a['name'] as String? ?? '';
          final thumb = a['thumbnail'] as String? ?? '';
          final id = a['id'];
          final bg = colors[i % colors.length];
          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
          return GestureDetector(
            onTap:
                () => onArtistTap?.call(id, name, thumb.isEmpty ? null : thumb),
            child: SizedBox(
              width: 100,
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bg,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child:
                        thumb.isNotEmpty
                            ? CachedNetworkImage(
                              imageUrl: thumb,
                              fit: BoxFit.cover,
                              errorWidget:
                                  (_, __, ___) => Center(
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                            )
                            : Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ArtistSkeleton extends StatelessWidget {
  const _ArtistSkeleton();
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = dark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder:
            (_, __) => Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Container(width: 70, height: 10, color: color),
              ],
            ),
      ),
    );
  }
}

// ── Vista de resultados de búsqueda ─────────────────────────────────────────

class _SearchResultsView extends StatelessWidget {
  final List<LastfmTrack> results;
  final bool loading;
  final bool dark;
  final String? currentId;
  final Map<String, String?> resolved;
  final Set<String> resolving;
  final List<Playlist> playlists;
  final void Function(LastfmTrack) onPlay;
  final void Function(LastfmTrack) onAdd;
  final void Function(LastfmTrack) onAddToQueue;
  final void Function(LastfmTrack) onPlayAsNext;
  final void Function(LastfmTrack, Playlist) onAddToPlaylist;

  const _SearchResultsView({
    required this.results,
    required this.loading,
    required this.dark,
    required this.currentId,
    required this.resolved,
    required this.resolving,
    required this.playlists,
    required this.onPlay,
    required this.onAdd,
    required this.onAddToQueue,
    required this.onPlayAsNext,
    required this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(color: Color(0xFF1DB954)),
        ),
      );
    }
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 56,
                color: dark ? Colors.white30 : Colors.black26,
              ),
              const SizedBox(height: 12),
              Text(
                'Sin resultados',
                style: TextStyle(color: dark ? Colors.white54 : Colors.black45),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, i) {
        final t = results[i];
        final key = '${t.artist}|${t.title}';
        final vid = t.videoId ?? resolved[key];
        final isCurrent = vid != null && vid == currentId;
        final isResolving = resolving.contains(key);
        return _LastfmResultRow(
          track: t,
          isCurrent: isCurrent,
          isResolving: isResolving,
          dark: dark,
          onPlay: () => onPlay(t),
          onAddToLibrary: () => onAdd(t),
          onAddToQueue: () => onAddToQueue(t),
          onPlayAsNext: () => onPlayAsNext(t),
          playlists: playlists,
          onAddToPlaylist: (p) => onAddToPlaylist(t, p),
        );
      },
    );
  }
}

// ── Overlay historial / sugerencias ─────────────────────────────────────────

class _SuggestionsOverlay extends StatelessWidget {
  final List<String> items;
  final bool isHistory;
  final bool dark;
  final void Function(String) onSelect;
  final void Function(String)? onRemove;
  final VoidCallback? onClear;

  const _SuggestionsOverlay({
    required this.items,
    required this.isHistory,
    required this.dark,
    required this.onSelect,
    this.onRemove,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF1E1E1E) : Colors.white;
    final labelColor = dark ? Colors.white54 : Colors.black45;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dark ? Colors.white12 : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isHistory)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
              child: Row(
                children: [
                  Text(
                    'Búsquedas recientes',
                    style: TextStyle(
                      fontSize: 12,
                      color: labelColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (onClear != null)
                    GestureDetector(
                      onTap: onClear,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          'Borrar todo',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF1DB954),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ...items.map(
            (s) => _SuggestionRow(
              label: s,
              isHistory: isHistory,
              dark: dark,
              labelColor: labelColor,
              onSelect: onSelect,
              onRemove: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final String label;
  final bool isHistory;
  final bool dark;
  final Color labelColor;
  final void Function(String) onSelect;
  final void Function(String)? onRemove;

  const _SuggestionRow({
    required this.label,
    required this.isHistory,
    required this.dark,
    required this.labelColor,
    required this.onSelect,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onSelect(label),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              isHistory ? Icons.history_rounded : Icons.search_rounded,
              size: 18,
              color: labelColor,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            if (onRemove != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onRemove!(label),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16, color: labelColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Fila de resultado Last.fm ─────────────────────────────────────────────

class _LastfmResultRow extends StatelessWidget {
  final LastfmTrack track;
  final bool isCurrent;
  final bool isResolving;
  final bool dark;
  final VoidCallback onPlay;
  final VoidCallback onAddToLibrary;
  final VoidCallback onAddToQueue;
  final VoidCallback onPlayAsNext;
  final List<Playlist> playlists;
  final void Function(Playlist) onAddToPlaylist;

  const _LastfmResultRow({
    required this.track,
    required this.isCurrent,
    required this.isResolving,
    required this.dark,
    required this.onPlay,
    required this.onAddToLibrary,
    required this.onAddToQueue,
    required this.onPlayAsNext,
    required this.playlists,
    required this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1DB954);
    final sub = dark ? Colors.white54 : Colors.black45;

    return InkWell(
      onTap: onPlay,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: track.thumbnail,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget:
                        (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          color:
                              dark
                                  ? const Color(0xFF333333)
                                  : const Color(0xFFDDDDDD),
                          child: Icon(Icons.music_note, size: 20, color: sub),
                        ),
                  ),
                ),
                if (isCurrent)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.equalizer_rounded,
                      color: green,
                      size: 20,
                    ),
                  ),
                if (isResolving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: green,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isCurrent ? green : null,
                    ),
                  ),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: sub),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 20),
              tooltip: 'Agregar a biblioteca',
              onPressed: onAddToLibrary,
            ),
            PopupMenuButton<Object?>(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              tooltip: 'Más opciones',
              padding: EdgeInsets.zero,
              itemBuilder:
                  (_) => [
                    const PopupMenuItem(
                      value: 'next',
                      child: Row(
                        children: [
                          Icon(Icons.queue_play_next_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Reproducir siguiente'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'queue',
                      child: Row(
                        children: [
                          Icon(Icons.add_to_queue_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Agregar a la cola'),
                        ],
                      ),
                    ),
                    if (playlists.where((p) => !p.isAuto).isNotEmpty) ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        enabled: false,
                        height: 28,
                        child: Text(
                          'Agregar a playlist',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ...playlists
                          .where((p) => !p.isAuto)
                          .map(
                            (p) => PopupMenuItem<Object?>(
                              value: p,
                              child: Row(
                                children: [
                                  Icon(p.icon, size: 16, color: p.color),
                                  const SizedBox(width: 8),
                                  Text(p.name),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ],
              onSelected: (val) {
                if (val == 'next')
                  onPlayAsNext();
                else if (val == 'queue')
                  onAddToQueue();
                else if (val is Playlist)
                  onAddToPlaylist(val);
              },
            ),
          ],
        ),
      ),
    );
  }
}
