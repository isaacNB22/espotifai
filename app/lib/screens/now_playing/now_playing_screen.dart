import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/player_service.dart';
import '../../utils/duration_fmt.dart';
import '../../widgets/common/pill_tab.dart';
import 'widgets/eq_panel.dart';
import 'widgets/lyrics_panel.dart';
import 'widgets/player_left_panel.dart';
import 'widgets/queue_panel.dart';

class NowPlayingScreen extends StatefulWidget {
  final PlayerService player;
  const NowPlayingScreen({super.key, required this.player});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  Timer? _sleepTimer;
  int _rightTab = 0; // 0=Cola 1=Letra
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

  void _rebuild() { if (mounted) setState(() {}); }

  void _showSpeedDialog() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Velocidad de reproduccion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: speeds.map((s) => RadioListTile<double>(
            title: Text(s == 1.0 ? 'Normal (1x)' : '${s}x'),
            value: s,
            groupValue: widget.player.speed,
            activeColor: const Color(0xFF1DB954),
            onChanged: (v) {
              if (v != null) widget.player.setSpeed(v);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showSleepDialog() {
    final options = [
      const Duration(minutes: 5), const Duration(minutes: 10),
      const Duration(minutes: 15), const Duration(minutes: 30),
      const Duration(minutes: 45), const Duration(hours: 1),
    ];
    final labels = ['5 min', '10 min', '15 min', '30 min', '45 min', '1 hora'];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sleep timer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.player.sleepRemaining != null)
              ListTile(
                leading: const Icon(Icons.cancel_rounded, color: Colors.red),
                title: Text(
                  'Cancelar (${fmtDuration(widget.player.sleepRemaining)} restante)',
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () { widget.player.cancelSleepTimer(); Navigator.pop(context); },
              ),
            ...List.generate(options.length, (i) => ListTile(
              title: Text(labels[i]),
              onTap: () { widget.player.setSleepTimer(options[i]); Navigator.pop(context); },
            )),
          ],
        ),
      ),
    );
  }

  void _showCrossfadeDialog() {
    double val = widget.player.crossfadeSec;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Crossfade'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(val == 0 ? 'Desactivado' : '${val.toStringAsFixed(1)}s'),
              Slider(
                value: val, min: 0, max: 10, divisions: 20,
                activeColor: const Color(0xFF1DB954),
                onChanged: (v) => setSt(() => val = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () { widget.player.crossfadeSec = val; Navigator.pop(ctx); },
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
        // Fondo: imagen borrosa
        Positioned.fill(
          child: song?.thumbnail.isNotEmpty == true
              ? CachedNetworkImage(
                  imageUrl: song!.thumbnail,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: const Color(0xFF1A0000)),
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
                _TopBar(
                  player: p,
                  onClose: () => Navigator.pop(context),
                  onSpeed: _showSpeedDialog,
                  onSleep: _showSleepDialog,
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
                            child: PlayerLeftPanel(
                              player: p,
                              showEq: _showEq,
                              onToggleEq: () => setState(() => _showEq = !_showEq),
                              onCrossfadeTap: _showCrossfadeDialog,
                              onStateChanged: () => setState(() {}),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: _RightPanel(
                              player: p,
                              showEq: _showEq,
                              tab: _rightTab,
                              onTabChanged: (t) => setState(() => _rightTab = t),
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

// Barra superior con controles de cerrar, velocidad y sleep
class _TopBar extends StatelessWidget {
  final PlayerService player;
  final VoidCallback onClose;
  final VoidCallback onSpeed;
  final VoidCallback onSleep;

  const _TopBar({
    required this.player,
    required this.onClose,
    required this.onSpeed,
    required this.onSleep,
  });

  @override
  Widget build(BuildContext context) {
    final p = player;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: Colors.white),
            onPressed: onClose,
          ),
          const Expanded(
            child: Column(
              children: [
                Text('REPRODUCIENDO',
                    style: TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                Text('Espotifai',
                    style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.speed_rounded, size: 20,
                color: p.speed != 1.0 ? const Color(0xFF1DB954) : Colors.white54),
            tooltip: 'Velocidad',
            onPressed: onSpeed,
          ),
          IconButton(
            icon: Icon(Icons.bedtime_rounded, size: 20,
                color: p.sleepRemaining != null ? const Color(0xFF1DB954) : Colors.white54),
            tooltip: 'Sleep timer',
            onPressed: onSleep,
          ),
        ],
      ),
    );
  }
}

// Panel derecho con tabs Cola / Letra o el panel de EQ
class _RightPanel extends StatelessWidget {
  final PlayerService player;
  final bool showEq;
  final int tab;
  final void Function(int) onTabChanged;

  const _RightPanel({
    required this.player,
    required this.showEq,
    required this.tab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(80),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.hardEdge,
        child: showEq
            ? EqPanel(player: player)
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        PillTab(
                          label: 'Cola',
                          icon: Icons.queue_music_rounded,
                          selected: tab == 0,
                          onTap: () => onTabChanged(0),
                        ),
                        const SizedBox(width: 8),
                        PillTab(
                          label: 'Letra',
                          icon: Icons.lyrics_rounded,
                          selected: tab == 1,
                          onTap: () => onTabChanged(1),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: tab == 0
                        ? QueuePanel(player: player)
                        : const LyricsPanel(),
                  ),
                ],
              ),
      ),
    );
  }
}
