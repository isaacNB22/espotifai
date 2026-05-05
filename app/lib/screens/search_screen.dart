import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../services/player_service.dart';
import '../widgets/song_card.dart';

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
  List<Song> _results = [];
  bool _loading = false;
  String? _error;

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.api.search(q);
      setState(() => _results = results);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Error de conexión con el servidor');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final currentId = widget.player.currentSong?.videoId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Artistas, canciones...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon:
                        _loading
                            ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                            : null,
                  ),
                  onSubmitted: (_) => _search(),
                  textInputAction: TextInputAction.search,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loading ? null : _search,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                child: const Text('Buscar'),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ),
        if (_results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              '${_results.length} resultados',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child:
              _results.isEmpty && !_loading
                  ? _EmptySearch(dark: dark)
                  : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: _results.length,
                    separatorBuilder:
                        (_, __) => const Divider(height: 1, indent: 82),
                    itemBuilder: (context, i) {
                      final song = _results[i];
                      return SongCard(
                        song: song,
                        isPlaying: song.videoId == currentId,
                        onPlay: () => widget.player.play(song),
                        onAddToLibrary: () => widget.onAddToLibrary(song),
                        showAddButton: true,
                        playlists: widget.playlists,
                        onAddToPlaylist: widget.onAddToPlaylist,
                        onAddToQueue: () => widget.player.addToQueue(song),
                        onPlayAsNext: () => widget.player.playAsNext(song),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

class _EmptySearch extends StatelessWidget {
  final bool dark;
  const _EmptySearch({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_rounded,
            size: 64,
            color: dark ? const Color(0xFF535353) : const Color(0xFFBBBBBB),
          ),
          const SizedBox(height: 16),
          Text(
            'Busca tus canciones favoritas',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: dark ? const Color(0xFF535353) : const Color(0xFFAAAAAA),
            ),
          ),
        ],
      ),
    );
  }
}
