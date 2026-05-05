import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/player_service.dart';

class NowPlayingScreen extends StatefulWidget {
  final PlayerService player;
  const NowPlayingScreen({super.key, required this.player});
  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  Timer? _sleepTimer;
  int _rightTab = 0;
  bool _showEq = false;

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_rebuild);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.player.removeListener(_rebuild);
    _sleepTimer?.cancel();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  String _fmt(Duration? d) {
    if (d == null) return '-:--';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _showSpeedDialog() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Velocidad de reproducción'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  speeds
                      .map(
                        (s) => RadioListTile<double>(
                          title: Text(s == 1.0 ? 'Normal (1x)' : '${s}x'),
                          value: s,
                          groupValue: widget.player.speed,
                          activeColor: const Color(0xFF1DB954),
                          onChanged: (v) {
                            if (v != null) widget.player.setSpeed(v);
                            Navigator.pop(context);
                          },
                        ),
                      )
                      .toList(),
            ),
          ),
    );
  }

  void _showSleepDialog() {
    final options = [
      const Duration(minutes: 5),
      const Duration(minutes: 10),
      const Duration(minutes: 15),
      const Duration(minutes: 30),
      const Duration(minutes: 45),
      const Duration(hours: 1),
    ];
    final labels = ['5 min', '10 min', '15 min', '30 min', '45 min', '1 hora'];
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Sleep timer'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.player.sleepRemaining != null)
                  ListTile(
                    leading: const Icon(
                      Icons.cancel_rounded,
                      color: Colors.red,
                    ),
                    title: Text(
                      'Cancelar (${_fmt(widget.player.sleepRemaining)} restante)',
                      style: const TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      widget.player.cancelSleepTimer();
                      Navigator.pop(context);
                    },
                  ),
                ...List.generate(
                  options.length,
                  (i) => ListTile(
                    title: Text(labels[i]),
                    onTap: () {
                      widget.player.setSleepTimer(options[i]);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showCrossfadeDialog() {
    double val = widget.player.crossfadeSec;
    showDialog(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (ctx, setSt) => AlertDialog(
                  title: const Text('Crossfade'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        val == 0 ? 'Desactivado' : '${val.toStringAsFixed(1)}s',
                      ),
                      Slider(
                        value: val,
                        min: 0,
                        max: 10,
                        divisions: 20,
                        activeColor: const Color(0xFF1DB954),
                        onChanged: (v) => setSt(() => val = v),
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
                        widget.player.crossfadeSec = val;
                        Navigator.pop(ctx);
                      },
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final song = p.currentSong;

    return Stack(
      children: [
        Positioned.fill(
          child:
              song?.thumbnail.isNotEmpty == true
                  ? CachedNetworkImage(
                    imageUrl: song!.thumbnail,
                    fit: BoxFit.cover,
                    errorWidget:
                        (_, __, ___) =>
                            Container(color: const Color(0xFF1A0000)),
                  )
                  : Container(color: const Color(0xFF1A0000)),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.black.withAlpha(170)),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 28,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Column(
                          children: [
                            Text(
                              'REPRODUCIENDO',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white54,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Espotifai',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.speed_rounded,
                          size: 20,
                          color:
                              p.speed != 1.0
                                  ? const Color(0xFF1DB954)
                                  : Colors.white54,
                        ),
                        tooltip: 'Velocidad',
                        onPressed: _showSpeedDialog,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.bedtime_rounded,
                          size: 20,
                          color:
                              p.sleepRemaining != null
                                  ? const Color(0xFF1DB954)
                                  : Colors.white54,
                        ),
                        tooltip: 'Sleep timer',
                        onPressed: _showSleepDialog,
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(32, 8, 20, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child:
                                              song?.thumbnail.isNotEmpty == true
                                                  ? CachedNetworkImage(
                                                    imageUrl: song!.thumbnail,
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (_, __) =>
                                                            _ArtPlaceholder(),
                                                    errorWidget:
                                                        (_, __, ___) =>
                                                            _ArtPlaceholder(),
                                                  )
                                                  : _ArtPlaceholder(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    song?.title ?? '—',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    song?.artist ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white60,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  StreamBuilder<Duration>(
                                    stream: p.positionStream,
                                    builder: (ctx, snap) {
                                      final pos = snap.data ?? Duration.zero;
                                      final dur = p.duration;
                                      final maxMs =
                                          (dur?.inMilliseconds.toDouble() ?? 0)
                                              .clamp(1.0, double.infinity);
                                      final valMs = pos.inMilliseconds
                                          .toDouble()
                                          .clamp(0.0, maxMs);
                                      return Column(
                                        children: [
                                          SliderTheme(
                                            data: SliderThemeData(
                                              trackHeight: 3,
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                    enabledThumbRadius: 5,
                                                  ),
                                              overlayShape:
                                                  const RoundSliderOverlayShape(
                                                    overlayRadius: 10,
                                                  ),
                                              activeTrackColor: Colors.white,
                                              inactiveTrackColor:
                                                  Colors.white24,
                                              thumbColor: Colors.white,
                                            ),
                                            child: Slider(
                                              value: valMs,
                                              max: maxMs,
                                              onChanged:
                                                  (v) => p.seek(
                                                    Duration(
                                                      milliseconds: v.toInt(),
                                                    ),
                                                  ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  _fmt(pos),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white54,
                                                  ),
                                                ),
                                                Text(
                                                  _fmt(dur),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white54,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 4),

                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _Btn(
                                        icon: Icons.shuffle_rounded,
                                        active: p.shuffle,
                                        onTap:
                                            () => setState(
                                              () => p.shuffle = !p.shuffle,
                                            ),
                                      ),
                                      _Btn(
                                        icon: Icons.skip_previous_rounded,
                                        size: 32,
                                        onTap: p.playPrev,
                                      ),
                                      GestureDetector(
                                        onTap: p.isPlaying ? p.pause : p.resume,
                                        child: Container(
                                          width: 56,
                                          height: 56,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child:
                                              p.status == PlayerStatus.loading
                                                  ? const Padding(
                                                    padding: EdgeInsets.all(16),
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2.5,
                                                          color: Color(
                                                            0xFF1DB954,
                                                          ),
                                                        ),
                                                  )
                                                  : Icon(
                                                    p.isPlaying
                                                        ? Icons.pause_rounded
                                                        : Icons
                                                            .play_arrow_rounded,
                                                    size: 32,
                                                    color: Colors.black,
                                                  ),
                                        ),
                                      ),
                                      _Btn(
                                        icon: Icons.skip_next_rounded,
                                        size: 32,
                                        onTap: p.playNext,
                                      ),
                                      _Btn(
                                        icon: Icons.repeat_rounded,
                                        active: p.repeat,
                                        onTap:
                                            () => setState(
                                              () => p.repeat = !p.repeat,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.volume_down_rounded,
                                        size: 16,
                                        color: Colors.white54,
                                      ),
                                      Expanded(
                                        child: SliderTheme(
                                          data: SliderThemeData(
                                            trackHeight: 3,
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                                  enabledThumbRadius: 5,
                                                ),
                                            activeTrackColor: Colors.white,
                                            inactiveTrackColor: Colors.white24,
                                            thumbColor: Colors.white,
                                          ),
                                          child: Slider(
                                            value: p.volume,
                                            onChanged: (v) {
                                              p.setVolume(v);
                                              setState(() {});
                                            },
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.volume_up_rounded,
                                        size: 16,
                                        color: Colors.white54,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _SmallChip(
                                        icon: Icons.equalizer_rounded,
                                        label: 'EQ',
                                        active: p.eqBands.any((b) => b != 0),
                                        onTap:
                                            () => setState(
                                              () => _showEq = !_showEq,
                                            ),
                                      ),
                                      const SizedBox(width: 12),
                                      _SmallChip(
                                        icon: Icons.swap_horiz_rounded,
                                        label:
                                            p.crossfadeSec > 0
                                                ? '${p.crossfadeSec.toStringAsFixed(0)}s'
                                                : 'Crossfade',
                                        active: p.crossfadeSec > 0,
                                        onTap: _showCrossfadeDialog,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 24, 16),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(80),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child:
                                    _showEq
                                        ? _EqPanel(player: p)
                                        : Column(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  _Tab(
                                                    label: 'Cola',
                                                    icon:
                                                        Icons
                                                            .queue_music_rounded,
                                                    selected: _rightTab == 0,
                                                    onTap:
                                                        () => setState(
                                                          () => _rightTab = 0,
                                                        ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  _Tab(
                                                    label: 'Letra',
                                                    icon: Icons.lyrics_rounded,
                                                    selected: _rightTab == 1,
                                                    onTap:
                                                        () => setState(
                                                          () => _rightTab = 1,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Divider(
                                              color: Colors.white12,
                                              height: 1,
                                            ),
                                            Expanded(
                                              child:
                                                  _rightTab == 0
                                                      ? _QueuePanel(player: p)
                                                      : const _LyricsPanel(),
                                            ),
                                          ],
                                        ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QueuePanel extends StatefulWidget {
  final PlayerService player;
  const _QueuePanel({required this.player});
  @override
  State<_QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends State<_QueuePanel> {
  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final queue = p.queue;
    final current = p.queueIndex;
    if (queue.isEmpty) {
      return const Center(
        child: Text(
          'Cola vacía.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: queue.length,
      onReorder: (oldIdx, newIdx) {
        setState(() => p.reorderQueue(oldIdx, newIdx));
      },
      proxyDecorator:
          (child, _, __) => Material(color: Colors.transparent, child: child),
      itemBuilder: (ctx, i) {
        final song = queue[i];
        final isCurrent = i == current;
        return ListTile(
          key: ValueKey(song.videoId + i.toString()),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 2,
          ),
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: song.thumbnail,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorWidget:
                      (_, __, ___) => Container(
                        width: 40,
                        height: 40,
                        color: Colors.white12,
                        child: const Icon(
                          Icons.music_note,
                          size: 16,
                          color: Colors.white38,
                        ),
                      ),
                ),
              ),
              if (isCurrent)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1DB954),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.equalizer_rounded,
                      size: 10,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCurrent ? const Color(0xFF1DB954) : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  isCurrent
                      ? const Color(0xFF1DB954).withAlpha(180)
                      : Colors.white54,
              fontSize: 12,
            ),
          ),
          onTap: isCurrent ? null : () => p.jumpToIndex(i),
          trailing: ReorderableDragStartListener(
            index: i,
            child: const Icon(
              Icons.drag_handle_rounded,
              color: Colors.white38,
              size: 20,
            ),
          ),
        );
      },
    );
  }
}

class _LyricsPanel extends StatelessWidget {
  const _LyricsPanel();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lyrics_rounded, size: 48, color: Colors.white24),
        SizedBox(height: 12),
        Text(
          'Letra no disponible',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      ],
    ),
  );
}

class _EqPanel extends StatefulWidget {
  final PlayerService player;
  const _EqPanel({required this.player});
  @override
  State<_EqPanel> createState() => _EqPanelState();
}

class _EqPanelState extends State<_EqPanel> {
  static const _labels = ['60Hz', '230Hz', '910Hz', '3.6k', '14k'];
  static const _indices = [0, 2, 4, 6, 9];
  static const _presets = {
    'Plano': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Graves': [6.0, 5.0, 3.0, 0.0, 0.0, 0.0, 0.0, -1.0, -1.0, -2.0],
    'Voz': [-2.0, -1.0, 0.0, 3.0, 5.0, 5.0, 3.0, 1.0, 0.0, -1.0],
    'Acústico': [4.0, 3.0, 2.0, 1.0, 0.0, 0.0, 1.0, 2.0, 2.0, 1.0],
    'Electrónica': [5.0, 3.0, -1.0, -3.0, 0.0, 1.0, 2.0, 4.0, 5.0, 4.0],
  };

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    const green = Color(0xFF1DB954);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Ecualizador',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  p.resetEq();
                  setState(() {});
                },
                child: const Text(
                  'Reset',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (i) {
                final bandIdx = _indices[i];
                final val = p.eqBands[bandIdx];
                return _VerticalBand(
                  label: _labels[i],
                  value: val,
                  green: green,
                  onChanged: (v) {
                    setState(() => p.eqBands[bandIdx] = v);
                    p.setEqBand(bandIdx, v);
                  },
                );
              }),
            ),
          ),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          const Text(
            'PRESETS',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _presets.entries
                    .map(
                      (e) => GestureDetector(
                        onTap: () {
                          setState(() {
                            for (int i = 0; i < 10; i++)
                              p.eqBands[i] = e.value[i];
                          });
                          for (int i = 0; i < 10; i++)
                            p.setEqBand(i, e.value[i]);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(20),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            e.key,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }
}

class _VerticalBand extends StatelessWidget {
  final String label;
  final double value;
  final Color green;
  final void Function(double) onChanged;
  const _VerticalBand({
    required this.label,
    required this.value,
    required this.green,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final valStr =
        value == 0
            ? '0'
            : (value > 0
                ? '+${value.toStringAsFixed(0)}'
                : value.toStringAsFixed(0));
    return Column(
      children: [
        Text(
          valStr,
          style: TextStyle(
            fontSize: 11,
            color: value == 0 ? Colors.white38 : green,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: green,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: value,
                min: -12,
                max: 12,
                divisions: 24,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white54),
        ),
      ],
    );
  }
}

class _ArtPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white12, Colors.white.withAlpha(5)],
      ),
    ),
    child: const Icon(
      Icons.music_note_rounded,
      size: 80,
      color: Colors.white24,
    ),
  );
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool active;
  final VoidCallback onTap;
  const _Btn({
    required this.icon,
    required this.onTap,
    this.size = 24,
    this.active = false,
  });
  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(
      icon,
      size: size,
      color: active ? const Color(0xFF1DB954) : Colors.white70,
    ),
    onPressed: onTap,
    splashRadius: 22,
  );
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? Colors.white : Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: selected ? Colors.black : Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SmallChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SmallChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1DB954);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? green.withAlpha(40) : Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? green : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? green : Colors.white54),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? green : Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
