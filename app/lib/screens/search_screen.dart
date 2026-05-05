import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lastfm_track.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../services/player_service.dart';

const _kHistoryKey = 'search_history';
const _kHistoryMax = 10;

class SearchScreen extends StatefulWidget {
  final ApiService api;
  final PlayerService player;
  final void Function(Song) onAddToLibrary;
  final List<Playlist> playlists;
  final void Function(Song, Playlist) onAddToPlaylist;

  const SearchScreen({
    super.key,
    required this.api,
    required this.player,
    required this.onAddToLibrary,
    required this.playlists,
    required this.onAddToPlaylist,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<LastfmTrack> _results = [];
  bool _loading = false;
  String? _error;

  // Resolución lazy de videoId: track key → videoId
  final Map<String, String?> _resolved = {};
  final Set<String> _resolving = {};

  // Historial
  List<String> _history = [];

  // Autocomplete
  List<String> _suggestions = [];
  Timer? _debounce;
  bool _showOverlay =
      false; // true cuando el campo tiene foco y hay sugerencias/historial

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _showOverlay = true);
      } else {
        // Delay para que los taps en el overlay completen antes de ocultarlo
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _showOverlay = false);
        });
      }
    });
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Historial ─────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _history = prefs.getStringList(_kHistoryKey) ?? []);
  }

  Future<void> _saveToHistory(String q) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kHistoryKey) ?? [];
    list.remove(q);
    list.insert(0, q);
    if (list.length > _kHistoryMax) list.removeLast();
    await prefs.setStringList(_kHistoryKey, list);
    setState(() => _history = list);
  }

  Future<void> _removeHistory(String q) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kHistoryKey) ?? [];
    list.remove(q);
    await prefs.setStringList(_kHistoryKey, list);
    setState(() => _history = list);
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHistoryKey);
    setState(() => _history = []);
  }

  // ── Autocomplete ──────────────────────────────────────────────────────────

  void _onTextChanged() {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final s = await widget.api.searchSuggestions(q);
      if (mounted) setState(() => _suggestions = s);
    });
  }

  // ── Búsqueda con Last.fm ──────────────────────────────────────────────────

  Future<void> _search([String? override]) async {
    final q = (override ?? _controller.text).trim();
    if (q.isEmpty) return;
    if (override != null) {
      _controller.text = override;
      _controller.selection = TextSelection.collapsed(offset: override.length);
    }
    _focusNode.unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _suggestions = [];
      _showOverlay = false;
      _resolved.clear();
      _resolving.clear();
    });
    await _saveToHistory(q);
    try {
      final results = await widget.api.searchLastfm(q);
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _error = 'Error de conexión con el servidor');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Resuelve el videoId de un track de forma lazy y reproduce/agrega
  String _trackKey(LastfmTrack t) => '${t.artist}___${t.title}';

  Future<void> _resolveAndDo(
    LastfmTrack t,
    void Function(String videoId) action,
  ) async {
    final key = _trackKey(t);
    if (_resolved.containsKey(key)) {
      final id = _resolved[key];
      if (id != null) action(id);
      return;
    }
    if (_resolving.contains(key)) return;
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

  Song _toSong(LastfmTrack t, String videoId) => Song(
    videoId: videoId,
    title: t.title,
    artist: t.artist,
    thumbnail: t.thumbnail,
  );

  void _play(LastfmTrack t) =>
      _resolveAndDo(t, (id) => widget.player.play(_toSong(t, id)));

  void _addToLibrary(LastfmTrack t) =>
      _resolveAndDo(t, (id) => widget.onAddToLibrary(_toSong(t, id)));

  void _addToQueue(LastfmTrack t) =>
      _resolveAndDo(t, (id) => widget.player.addToQueue(_toSong(t, id)));

  void _playAsNext(LastfmTrack t) =>
      _resolveAndDo(t, (id) => widget.player.playAsNext(_toSong(t, id)));

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final currentId = widget.player.currentSong?.videoId;
    final showHistoryOrSuggestions =
        _showOverlay &&
        (_controller.text.isEmpty
            ? _history.isNotEmpty
            : _suggestions.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Barra de búsqueda estilo Spotify ────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color:
                    _focusNode.hasFocus
                        ? const Color(0xFF1DB954)
                        : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Artistas, canciones, podcasts...',
                hintStyle: TextStyle(
                  color: dark ? Colors.white38 : Colors.black38,
                ),
                prefixIcon:
                    _loading
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
                    _controller.text.isEmpty
                        ? null
                        : GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _controller.clear();
                            setState(() => _suggestions = []);
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.close_rounded, size: 18),
                          ),
                        ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: (_) => _search(),
              textInputAction: TextInputAction.search,
            ),
          ),
        ),

        // ── Error ───────────────────────────────────────────────────────────
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ),

        // ── Historial / Sugerencias (overlay) ───────────────────────────────
        if (showHistoryOrSuggestions)
          _SuggestionsOverlay(
            items: _controller.text.isEmpty ? _history : _suggestions,
            isHistory: _controller.text.isEmpty,
            dark: dark,
            onSelect: (s) => _search(s),
            onRemove: _controller.text.isEmpty ? _removeHistory : null,
            onClear:
                _controller.text.isEmpty && _history.isNotEmpty
                    ? _clearHistory
                    : null,
          )
        else ...[
          if (_results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                '${_results.length} resultados · Last.fm',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child:
                _results.isEmpty && !_loading
                    ? _EmptySearch(
                      dark: dark,
                      api: widget.api,
                      onSearch: _search,
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: _results.length,
                      separatorBuilder:
                          (_, __) => const Divider(height: 1, indent: 72),
                      itemBuilder: (context, i) {
                        final t = _results[i];
                        final key = _trackKey(t);
                        final resolvedId = _resolved[key];
                        final isResolving = _resolving.contains(key);
                        final isCurrent =
                            resolvedId != null && resolvedId == currentId;
                        return _LastfmResultRow(
                          track: t,
                          isCurrent: isCurrent,
                          isResolving: isResolving,
                          dark: dark,
                          onPlay: () => _play(t),
                          onAddToLibrary: () => _addToLibrary(t),
                          onAddToQueue: () => _addToQueue(t),
                          onPlayAsNext: () => _playAsNext(t),
                          playlists: widget.playlists,
                          onAddToPlaylist: (pl) async {
                            final key2 = _trackKey(t);
                            String? id = _resolved[key2];
                            if (id == null) {
                              id = await widget.api.resolveVideoId(
                                track: t.title,
                                artist: t.artist,
                              );
                              if (id != null && mounted)
                                setState(() => _resolved[key2] = id);
                            }
                            if (id != null)
                              widget.onAddToPlaylist(_toSong(t, id), pl);
                          },
                        );
                      },
                    ),
          ),
        ],
      ],
    );
  }
}

// ── Fila de resultado Last.fm ─────────────────────────────────────────────────

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
            // Thumbnail
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
            // Título + artista
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
            // Botón agregar a biblioteca
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 20),
              tooltip: 'Agregar a biblioteca',
              onPressed: onAddToLibrary,
            ),
            // Menú más opciones
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
                                  SizedBox(width: 8),
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
                    // GestureDetector evita el bug de teclado de Flutter/Windows con TextButton
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

/// Fila individual de sugerencia/historial.
/// Maneja los taps de forma independiente: selección vs. eliminación.
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
      // Solo seleccionar cuando se toca el área principal, no el botón X
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
              // GestureDetector con HitTestBehavior.opaque absorbe el tap para que
              // no llegue al InkWell padre (evita que se busque al borrar del historial)
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

// ── Empty state con artistas tendencia de Last.fm ────────────────────────────

class _EmptySearch extends StatefulWidget {
  final bool dark;
  final ApiService api;
  final void Function(String) onSearch;

  const _EmptySearch({
    required this.dark,
    required this.api,
    required this.onSearch,
  });

  @override
  State<_EmptySearch> createState() => _EmptySearchState();
}

class _EmptySearchState extends State<_EmptySearch> {
  List<Map<String, dynamic>> _artists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.api.chartArtists().then((a) {
      if (mounted)
        setState(() {
          _artists = a;
          _loading = false;
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final labelColor = dark ? Colors.white54 : Colors.black45;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explorar artistas',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _artists.isEmpty
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_rounded, size: 64, color: labelColor),
                    const SizedBox(height: 12),
                    Text(
                      'Busca tus canciones favoritas',
                      style: TextStyle(color: labelColor, fontSize: 15),
                    ),
                  ],
                ),
              )
              : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2.0,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _artists.length,
                itemBuilder: (context, i) {
                  final a = _artists[i];
                  final name = a['name'] as String? ?? '';
                  final thumb = a['thumbnail'] as String? ?? '';
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
                  final bg = colors[i % colors.length];
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                  return GestureDetector(
                    onTap: () => widget.onSearch(name),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: bg),
                          if (thumb.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: thumb,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const SizedBox(),
                            ),
                          // Gradiente para legibilidad
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black54],
                              ),
                            ),
                          ),
                          if (thumb.isEmpty)
                            Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          Positioned(
                            left: 10,
                            bottom: 8,
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                shadows: [Shadow(blurRadius: 4)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}
