import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../services/player_service.dart';

class ArtistScreen extends StatefulWidget {
  final ApiService api;
  final PlayerService player;
  final dynamic artistId; // int o null (si solo tenemos nombre)
  final String artistName;
  final String? artistThumb;
  final void Function(Song) onAddToLibrary;
  final void Function(dynamic id, String name, String? thumb)? onOpenArtist;
  final List<Playlist> playlists;
  final void Function(Song, Playlist)? onAddToPlaylist;

  const ArtistScreen({
    super.key,
    required this.api,
    required this.player,
    required this.artistName,
    this.artistId,
    this.artistThumb,
    required this.onAddToLibrary,
    this.onOpenArtist,
    this.playlists = const [],
    this.onAddToPlaylist,
  });

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  // resolución lazy de videoId para reproducir
  final Map<String, String?> _resolved = {};
  final Set<String> _resolving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      dynamic id = widget.artistId;
      if (id == null) {
        final found = await widget.api.deezerSearchArtist(widget.artistName);
        id = found?['id'];
      }
      if (id == null) {
        setState(() {
          _error = 'Artista no encontrado';
          _loading = false;
        });
        return;
      }
      final data = await widget.api.deezerArtist(id);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _resolveAndPlay(Map<String, dynamic> track) async {
    final key = '${track['artist']}___${track['title']}';
    if (_resolved.containsKey(key)) {
      final id = _resolved[key];
      if (id != null) _play(track, id);
      return;
    }
    if (_resolving.contains(key)) return;
    setState(() => _resolving.add(key));
    final id = await widget.api.resolveVideoId(
      track: track['title'] as String,
      artist: track['artist'] as String,
    );
    if (!mounted) return;
    setState(() {
      _resolved[key] = id;
      _resolving.remove(key);
    });
    if (id != null) _play(track, id);
  }

  void _play(Map<String, dynamic> track, String videoId) {
    widget.player.play(
      Song(
        videoId: videoId,
        title: track['title'] as String,
        artist: track['artist'] as String,
        thumbnail: track['thumbnail'] as String? ?? '',
      ),
    );
  }

  Future<void> _resolveAndAdd(Map<String, dynamic> track) async {
    final key = '${track['artist']}___${track['title']}';
    String? id = _resolved[key];
    if (id == null) {
      if (_resolving.contains(key)) return;
      setState(() => _resolving.add(key));
      id = await widget.api.resolveVideoId(
        track: track['title'] as String,
        artist: track['artist'] as String,
      );
      if (!mounted) return;
      setState(() {
        _resolved[key] = id;
        _resolving.remove(key);
      });
    }
    if (id != null) {
      widget.onAddToLibrary(
        Song(
          videoId: id,
          title: track['title'] as String,
          artist: track['artist'] as String,
          thumbnail: track['thumbnail'] as String? ?? '',
        ),
      );
    }
  }

  Future<void> _resolveAndQueue(
    Map<String, dynamic> track, {
    bool asNext = false,
  }) async {
    final key = '${track['artist']}___${track['title']}';
    String? id = _resolved[key];
    if (id == null) {
      if (_resolving.contains(key)) return;
      setState(() => _resolving.add(key));
      id = await widget.api.resolveVideoId(
        track: track['title'] as String,
        artist: track['artist'] as String,
      );
      if (!mounted) return;
      setState(() {
        _resolved[key] = id;
        _resolving.remove(key);
      });
    }
    if (id != null) {
      final song = Song(
        videoId: id,
        title: track['title'] as String,
        artist: track['artist'] as String,
        thumbnail: track['thumbnail'] as String? ?? '',
      );
      if (asNext)
        widget.player.playAsNext(song);
      else
        widget.player.addToQueue(song);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF121212) : const Color(0xFFF8F8F8);
    final sub = dark ? Colors.white54 : Colors.black45;

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1DB954)),
        ),
      );
    }
    if (_error != null || _data == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_rounded, size: 64, color: sub),
              const SizedBox(height: 12),
              Text(_error ?? 'Sin datos', style: TextStyle(color: sub)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final d = _data!;
    final name = d['name'] as String? ?? widget.artistName;
    final thumb = d['thumbnail'] as String? ?? widget.artistThumb ?? '';
    final fans = d['nb_fan'] as int? ?? 0;
    final nbAlbum = d['nb_album'] as int? ?? 0;
    final topTracks =
        (d['topTracks'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final albums =
        (d['albums'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final related =
        (d['related'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── Header: AppBar + foto en recuadro + blur de fondo ────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor:
                dark ? const Color(0xFF1A1A1A) : const Color(0xFF2A2A2A),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Fondo: misma imagen con blur fuerte
                  if (thumb.isNotEmpty) ...[
                    CachedNetworkImage(
                      imageUrl: thumb,
                      fit: BoxFit.cover,
                      errorWidget:
                          (_, __, ___) =>
                              Container(color: const Color(0xFF303030)),
                    ),
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                      child: Container(color: Colors.black.withAlpha(160)),
                    ),
                  ] else
                    Container(color: const Color(0xFF303030)),
                  // Gradiente abajo
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                        stops: [0.5, 1.0],
                      ),
                    ),
                  ),
                  // Foto en recuadro + info
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 16,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Foto en recuadro redondeado
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child:
                              thumb.isNotEmpty
                                  ? CachedNetworkImage(
                                    imageUrl: thumb,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorWidget:
                                        (_, __, ___) => Container(
                                          width: 100,
                                          height: 100,
                                          color: const Color(0xFF303030),
                                          child: const Icon(
                                            Icons.person_rounded,
                                            color: Colors.white54,
                                            size: 48,
                                          ),
                                        ),
                                  )
                                  : Container(
                                    width: 100,
                                    height: 100,
                                    color: const Color(0xFF303030),
                                    child: const Icon(
                                      Icons.person_rounded,
                                      color: Colors.white54,
                                      size: 48,
                                    ),
                                  ),
                        ),
                        const SizedBox(width: 14),
                        // Nombre + stats
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _StatChip(
                                    icon: Icons.favorite_rounded,
                                    label: _formatFans(fans),
                                  ),
                                  const SizedBox(width: 8),
                                  _StatChip(
                                    icon: Icons.album_rounded,
                                    label: '$nbAlbum álbumes',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Top Tracks ───────────────────────────────────────────────────
          if (topTracks.isNotEmpty) ...[
            _SliverSectionHeader(title: 'Canciones populares'),
            SliverList(
              delegate: SliverChildBuilderDelegate((_, i) {
                final t = topTracks[i];
                final key = '${t['artist']}___${t['title']}';
                final currentId = widget.player.currentSong?.videoId;
                final vid = _resolved[key];
                final isCurrent = vid != null && vid == currentId;
                final isResolving = _resolving.contains(key);
                return _TrackRow(
                  index: i + 1,
                  title: t['title'] as String? ?? '',
                  artist: t['artist'] as String? ?? '',
                  album: t['albumName'] as String? ?? '',
                  thumbnail: t['thumbnail'] as String? ?? '',
                  duration: t['duration'] as int? ?? 0,
                  isCurrent: isCurrent,
                  isResolving: isResolving,
                  dark: dark,
                  playlists: widget.playlists,
                  onTap: () => _resolveAndPlay(t),
                  onAdd: () => _resolveAndAdd(t),
                  onAddToQueue: () => _resolveAndQueue(t),
                  onPlayAsNext: () => _resolveAndQueue(t, asNext: true),
                  onAddToPlaylist: (pl) async {
                    final key = '${t['artist']}___${t['title']}';
                    String? id = _resolved[key];
                    if (id == null) {
                      id = await widget.api.resolveVideoId(
                        track: t['title'] as String,
                        artist: t['artist'] as String,
                      );
                      if (!mounted) return;
                      setState(() => _resolved[key] = id);
                    }
                    if (id != null) {
                      widget.onAddToPlaylist?.call(
                        Song(
                          videoId: id,
                          title: t['title'] as String,
                          artist: t['artist'] as String,
                          thumbnail: t['thumbnail'] as String? ?? '',
                        ),
                        pl,
                      );
                    }
                  },
                );
              }, childCount: topTracks.length),
            ),
          ],

          // ── Álbumes ───────────────────────────────────────────────────────
          if (albums.isNotEmpty) ...[
            _SliverSectionHeader(title: 'Discografía'),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: albums.length,
                  itemBuilder:
                      (_, i) => _AlbumCard(album: albums[i], dark: dark),
                ),
              ),
            ),
          ],

          // ── Artistas relacionados ─────────────────────────────────────────
          if (related.isNotEmpty) ...[
            _SliverSectionHeader(title: 'Te puede gustar'),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: related.length,
                  itemBuilder: (_, i) {
                    final a = related[i];
                    return GestureDetector(
                      onTap: () {
                        if (widget.onOpenArtist != null) {
                          widget.onOpenArtist!(
                            a['id'],
                            a['name'] as String? ?? '',
                            a['thumbnail'] as String?,
                          );
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => ArtistScreen(
                                    api: widget.api,
                                    player: widget.player,
                                    artistId: a['id'],
                                    artistName: a['name'] as String? ?? '',
                                    artistThumb: a['thumbnail'] as String?,
                                    onAddToLibrary: widget.onAddToLibrary,
                                    onOpenArtist: widget.onOpenArtist,
                                  ),
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: a['thumbnail'] as String? ?? '',
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                errorWidget:
                                    (_, __, ___) => Container(
                                      width: 90,
                                      height: 90,
                                      color:
                                          dark
                                              ? const Color(0xFF2A2A2A)
                                              : const Color(0xFFE0E0E0),
                                      child: const Icon(
                                        Icons.person_rounded,
                                        size: 40,
                                      ),
                                    ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 90,
                              child: Text(
                                a['name'] as String? ?? '',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  String _formatFans(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M oyentes';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K oyentes';
    return '$n oyentes';
  }
}

// ── Chip de estadística en el header ─────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cabecera de sección ───────────────────────────────────────────────────────

class _SliverSectionHeader extends StatelessWidget {
  final String title;
  const _SliverSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

// ── Fila de track ─────────────────────────────────────────────────────────────

class _TrackRow extends StatelessWidget {
  final int index;
  final String title, artist, album, thumbnail;
  final int duration;
  final bool isCurrent, isResolving, dark;
  final List<Playlist> playlists;
  final VoidCallback onTap, onAdd, onAddToQueue, onPlayAsNext;
  final void Function(Playlist) onAddToPlaylist;

  const _TrackRow({
    required this.index,
    required this.title,
    required this.artist,
    required this.album,
    required this.thumbnail,
    required this.duration,
    required this.isCurrent,
    required this.isResolving,
    required this.dark,
    required this.playlists,
    required this.onTap,
    required this.onAdd,
    required this.onAddToQueue,
    required this.onPlayAsNext,
    required this.onAddToPlaylist,
  });

  String _dur(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1DB954);
    final sub = dark ? Colors.white54 : Colors.black45;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Número o indicador activo
            SizedBox(
              width: 28,
              child:
                  isResolving
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: green,
                        ),
                      )
                      : Text(
                        '$index',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isCurrent ? green : sub,
                          fontSize: 14,
                          fontWeight:
                              isCurrent ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
            ),
            const SizedBox(width: 12),
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: thumbnail,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorWidget:
                    (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      color:
                          dark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFE0E0E0),
                      child: Icon(Icons.music_note, size: 20, color: sub),
                    ),
              ),
            ),
            const SizedBox(width: 12),
            // Título + álbum
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isCurrent ? green : null,
                    ),
                  ),
                  if (album.isNotEmpty)
                    Text(
                      album,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: sub),
                    ),
                ],
              ),
            ),
            // Duración
            if (duration > 0)
              Text(_dur(duration), style: TextStyle(fontSize: 12, color: sub)),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 20),
              tooltip: 'Agregar a biblioteca',
              onPressed: onAdd,
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

// ── Tarjeta de álbum ──────────────────────────────────────────────────────────

class _AlbumCard extends StatelessWidget {
  final Map<String, dynamic> album;
  final bool dark;
  const _AlbumCard({required this.album, required this.dark});

  @override
  Widget build(BuildContext context) {
    final title = album['title'] as String? ?? '';
    final cover = album['cover'] as String? ?? '';
    final date = album['releaseDate'] as String? ?? '';
    final year = date.length >= 4 ? date.substring(0, 4) : date;
    final tracks = album['nbTracks'] as int? ?? 0;
    final sub = dark ? Colors.white54 : Colors.black45;

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: cover,
                width: 130,
                height: 130,
                fit: BoxFit.cover,
                errorWidget:
                    (_, __, ___) => Container(
                      width: 130,
                      height: 130,
                      color:
                          dark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFE0E0E0),
                      child: Icon(Icons.album_rounded, size: 48, color: sub),
                    ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              tracks > 0 ? '$year · $tracks canciones' : year,
              style: TextStyle(fontSize: 11, color: sub),
            ),
          ],
        ),
      ),
    );
  }
}
