import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/player_service.dart';

class LibraryScreen extends StatefulWidget {
  final PlayerService player;
  final List<Song> songs;
  final List<Playlist> playlists;
  final Map<String, double> downloadProgress;
  final void Function(String videoId) onRemove;
  final void Function(String videoId) onDownload;
  final void Function(Playlist) onCreatePlaylist;
  final void Function(String playlistId) onDeletePlaylist;
  final void Function(Playlist) onOpenPlaylist;

  const LibraryScreen({
    super.key,
    required this.player,
    required this.songs,
    required this.playlists,
    required this.downloadProgress,
    required this.onRemove,
    required this.onDownload,
    required this.onCreatePlaylist,
    required this.onDeletePlaylist,
    required this.onOpenPlaylist,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  // Auto-playlists always shown first
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

  List<Playlist> get _allPlaylists => [..._autoPlaylists, ...widget.playlists];

  int _songCount(Playlist p) {
    if (p.id == 'auto_downloaded') {
      return widget.songs.where((s) => s.downloaded).length;
    }
    if (p.id == 'auto_pending') {
      return widget.songs.where((s) => !s.downloaded).length;
    }
    return p.videoIds
        .where((id) => widget.songs.any((s) => s.videoId == id))
        .length;
  }

  void _openPlaylist(Playlist playlist) {
    widget.onOpenPlaylist(playlist);
  }

  Future<void> _showCreateDialog() async {
    final ctrl = TextEditingController();
    Color selectedColor = const Color(0xFF9B59B6);

    final colors = [
      const Color(0xFF9B59B6),
      const Color(0xFFE74C3C),
      const Color(0xFFE67E22),
      const Color(0xFF2ECC71),
      const Color(0xFF3498DB),
      const Color(0xFF1ABC9C),
      const Color(0xFFF39C12),
      const Color(0xFF34495E),
    ];

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setS) {
              return AlertDialog(
                title: const Text('Nueva playlist'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Nombre de la playlist',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Color', style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children:
                          colors
                              .map(
                                (c) => GestureDetector(
                                  onTap: () => setS(() => selectedColor = c),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border:
                                          selectedColor == c
                                              ? Border.all(
                                                color: Colors.white,
                                                width: 2.5,
                                              )
                                              : null,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final name = ctrl.text.trim();
                      if (name.isEmpty) return;
                      widget.onCreatePlaylist(
                        Playlist(
                          id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
                          name: name,
                          videoIds: const [],
                          color: selectedColor,
                          icon: Icons.queue_music_rounded,
                        ),
                      );
                      Navigator.pop(ctx);
                    },
                    child: const Text('Crear'),
                  ),
                ],
              );
            },
          ),
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final allPlaylists = _allPlaylists;
    final bg = dark ? const Color(0xFF121212) : const Color(0xFFF8F8F8);
    final subColor = dark ? Colors.white54 : Colors.black45;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 12, 12),
              child: Row(
                children: [
                  Text(
                    'Tu biblioteca',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Nueva playlist',
                    onPressed: _showCreateDialog,
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, i) {
              final p = allPlaylists[i];
              final count = _songCount(p);
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 2,
                ),
                leading: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: p.color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(p.icon, color: Colors.white, size: 26),
                ),
                title: Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  'Playlist · $count ${count == 1 ? 'canción' : 'canciones'}',
                  style: TextStyle(fontSize: 12, color: subColor),
                ),
                trailing:
                    p.isAuto
                        ? null
                        : IconButton(
                          icon: Icon(Icons.more_vert_rounded, color: subColor),
                          onPressed:
                              () => showDialog(
                                context: context,
                                builder:
                                    (_) => AlertDialog(
                                      title: const Text('Eliminar playlist'),
                                      content: Text(
                                        '¿Eliminar "${p.name}"? Las canciones seguirán en tu biblioteca.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(context),
                                          child: const Text('Cancelar'),
                                        ),
                                        FilledButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            widget.onDeletePlaylist(p.id);
                                          },
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          child: const Text('Eliminar'),
                                        ),
                                      ],
                                    ),
                              ),
                        ),
                onTap: () => _openPlaylist(p),
              );
            }, childCount: allPlaylists.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
