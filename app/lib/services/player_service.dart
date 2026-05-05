import 'dart:async';
import 'dart:math';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import 'api_service.dart';

enum PlayerStatus { idle, loading, playing, paused, error }

class PlayerService {
  final Player _player = Player();
  // Segundo player para crossfade
  final Player _playerB = Player();
  bool _usingA = true;
  Player get _active => _usingA ? _player : _playerB;
  Player get _standby => _usingA ? _playerB : _player;

  final ApiService _api;

  Song? currentSong;
  PlayerStatus status = PlayerStatus.idle;

  List<Song> _queue = []; // cola actual (barajada si shuffle está activo)
  List<Song> _originalQueue = []; // cola en orden original
  int _queueIndex = -1;
  bool _shuffle = false;
  bool get shuffle => _shuffle;
  set shuffle(bool value) {
    _shuffle = value;
    if (value) {
      _originalQueue = List.of(_queue);
      final current = _queueIndex >= 0 ? _queue[_queueIndex] : null;
      _queue.shuffle();
      if (current != null) {
        _queue.remove(current);
        _queue.insert(0, current);
        _queueIndex = 0;
      }
    } else {
      final current = _queueIndex >= 0 ? _queue[_queueIndex] : null;
      _queue = List.of(_originalQueue);
      if (current != null) {
        _queueIndex = _queue.indexWhere((s) => s.videoId == current.videoId);
        if (_queueIndex == -1) _queueIndex = 0;
      }
    }
    _notify();
  }

  bool repeat = false;

  // Speed
  double speed = 1.0;

  // Crossfade duration en segundos (0 = desactivado)
  double crossfadeSec = 3.0;
  bool _crossfading = false;

  // Equalizer bands: 60Hz, 170Hz, 310Hz, 600Hz, 1kHz, 3kHz, 6kHz, 12kHz, 14kHz, 16kHz
  // Valores en dB, -12..+12
  static const List<int> eqFrequencies = [
    60,
    170,
    310,
    600,
    1000,
    3000,
    6000,
    12000,
    14000,
    16000,
  ];
  List<double> eqBands = List.filled(10, 0.0);

  // Sleep timer
  Timer? _sleepTimer;
  DateTime? _sleepEnd;
  Duration? get sleepRemaining {
    if (_sleepEnd == null) return null;
    final r = _sleepEnd!.difference(DateTime.now());
    return r.isNegative ? null : r;
  }

  int _loadId = 0;

  final List<void Function()> _listeners = [];
  final List<StreamSubscription> _subs = [];

  void addListener(void Function() fn) => _listeners.add(fn);
  void removeListener(void Function() fn) => _listeners.remove(fn);

  set onStateChanged(void Function()? fn) => _legacyListener = fn;
  void Function()? _legacyListener;

  void _notify() {
    _legacyListener?.call();
    for (final fn in List.of(_listeners)) fn();
  }

  PlayerService({required ApiService api}) : _api = api {
    _subs.add(
      _player.stream.playing.listen((playing) {
        if (!_usingA) return;
        if (status == PlayerStatus.loading) return;
        final next = playing ? PlayerStatus.playing : PlayerStatus.paused;
        if (status != next) {
          status = next;
          _notify();
        }
      }),
    );
    _subs.add(
      _playerB.stream.playing.listen((playing) {
        if (_usingA) return;
        if (status == PlayerStatus.loading) return;
        final next = playing ? PlayerStatus.playing : PlayerStatus.paused;
        if (status != next) {
          status = next;
          _notify();
        }
      }),
    );

    _subs.add(
      _player.stream.completed.listen((c) {
        if (_usingA && c) _onCompleted();
      }),
    );
    _subs.add(
      _playerB.stream.completed.listen((c) {
        if (!_usingA && c) _onCompleted();
      }),
    );

    // Crossfade watch
    _subs.add(
      _player.stream.position.listen((pos) {
        if (_usingA) _checkCrossfade(pos, _player.state.duration);
      }),
    );
    _subs.add(
      _playerB.stream.position.listen((pos) {
        if (!_usingA) _checkCrossfade(pos, _playerB.state.duration);
      }),
    );

    _loadResume();
  }

  void _onCompleted() {
    if (repeat) {
      _active.seek(Duration.zero);
      _active.play();
    } else {
      _playNextInQueue();
    }
  }

  void _checkCrossfade(Duration pos, Duration dur) {
    if (crossfadeSec <= 0 || _crossfading || dur == Duration.zero) return;
    final remaining = dur - pos;
    if (remaining.inSeconds <= crossfadeSec && remaining.inSeconds >= 0) {
      _crossfading = true;
      _startCrossfade();
    }
  }

  Future<void> _startCrossfade() async {
    if (_queue.isEmpty) {
      _crossfading = false;
      return;
    }
    final nextIdx =
        shuffle
            ? Random().nextInt(_queue.length)
            : (_queueIndex + 1) % _queue.length;
    if (nextIdx == _queueIndex && !repeat) {
      _crossfading = false;
      return;
    }

    final nextSong = _queue[nextIdx];
    final url = _api.streamUrl(nextSong.videoId);

    // Pre-cargar en standby
    await _standby.open(Media(url), play: true);
    await _standby.setVolume(0);
    await _standby.setRate(speed);

    final stepMs = 100;
    final steps = (crossfadeSec * 1000 / stepMs).round();
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(Duration(milliseconds: stepMs));
      final ratio = i / steps;
      await _active.setVolume((1 - ratio) * 100);
      await _standby.setVolume(ratio * 100);
    }

    _usingA = !_usingA;
    await _active.setVolume(100); // activo ya es el nuevo
    await _standby.stop();
    await _standby.setVolume(100);

    _queueIndex = nextIdx;
    currentSong = nextSong;
    status = PlayerStatus.playing;
    _crossfading = false;
    _saveResume();
    _notify();
  }

  Stream<Duration> get positionStream => _active.stream.position;
  Stream<Duration?> get durationStream =>
      _active.stream.duration.map((d) => d == Duration.zero ? null : d);
  Duration get position => _active.state.position;
  Duration? get duration {
    final d = _active.state.duration;
    return d == Duration.zero ? null : d;
  }

  bool get isPlaying => status == PlayerStatus.playing;
  List<Song> get queue => _queue;
  int get queueIndex => _queueIndex;

  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    _originalQueue = List.of(songs);
    _queue = List.of(songs);
    _queueIndex = startIndex;
    if (_shuffle) {
      final current = _queue[_queueIndex];
      _queue.shuffle();
      _queue.remove(current);
      _queue.insert(0, current);
      _queueIndex = 0;
    }
    await _loadAndPlay(_queue[_queueIndex]);
  }

  /// Salta al índice dado en la cola actual sin reordenarla.
  Future<void> jumpToIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queueIndex = index;
    await _loadAndPlay(_queue[_queueIndex]);
  }

  /// Agrega una canción al final de la cola.
  void addToQueue(Song song) {
    _queue.add(song);
    _originalQueue.add(song);
    _notify();
  }

  /// Inserta una canción como la siguiente en la cola.
  void playAsNext(Song song) {
    final insertIdx = _queueIndex + 1;
    _queue.insert(insertIdx.clamp(0, _queue.length), song);
    _originalQueue.insert(insertIdx.clamp(0, _originalQueue.length), song);
    _notify();
  }

  /// Reordena la cola (drag & drop). oldIndex y newIndex son posiciones absolutas.
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final song = _queue.removeAt(oldIndex);
    final adjustedNew = oldIndex < newIndex ? newIndex - 1 : newIndex;
    _queue.insert(adjustedNew, song);
    // Actualizar queueIndex si la canción actual se movió
    if (oldIndex == _queueIndex) {
      _queueIndex = adjustedNew;
    } else if (oldIndex < _queueIndex && adjustedNew >= _queueIndex) {
      _queueIndex--;
    } else if (oldIndex > _queueIndex && adjustedNew <= _queueIndex) {
      _queueIndex++;
    }
    _originalQueue = List.of(_queue);
    _notify();
  }

  Future<void> play(Song song) async {
    if (currentSong?.videoId == song.videoId) {
      if (status == PlayerStatus.paused) await _active.play();
      return;
    }
    final idx = _queue.indexWhere((s) => s.videoId == song.videoId);
    if (idx != -1) {
      _queueIndex = idx;
    } else {
      _queue = [song];
      _originalQueue = [song];
      _queueIndex = 0;
    }
    await _loadAndPlay(song);
  }

  Future<void> playNext() async {
    if (_queue.isEmpty) return;
    _queueIndex = (_queueIndex + 1) % _queue.length;
    await _loadAndPlay(_queue[_queueIndex]);
  }

  Future<void> playPrev() async {
    if (_queue.isEmpty) return;
    if (position.inSeconds > 3) {
      await _active.seek(Duration.zero);
      return;
    }
    _queueIndex = (_queueIndex - 1 + _queue.length) % _queue.length;
    await _loadAndPlay(_queue[_queueIndex]);
  }

  Future<void> _playNextInQueue() async {
    if (_queue.isEmpty) {
      status = PlayerStatus.idle;
      currentSong = null;
      _notify();
      return;
    }
    if (_queueIndex >= _queue.length - 1) {
      if (repeat) {
        _queueIndex = 0;
      } else {
        status = PlayerStatus.idle;
        currentSong = null;
        _notify();
        return;
      }
    } else {
      _queueIndex++;
    }
    await _loadAndPlay(_queue[_queueIndex]);
  }

  Future<void> _loadAndPlay(Song song) async {
    _crossfading = false;
    final myLoadId = ++_loadId;
    status = PlayerStatus.loading;
    currentSong = song;
    _notify();
    try {
      final url = _api.streamUrl(song.videoId);
      await _active.open(Media(url), play: true);
      if (myLoadId != _loadId) return;
      await _active.setRate(speed);
      await _applyEq();
      status = PlayerStatus.playing;
      _saveResume();
      _notify();
    } catch (_) {
      if (myLoadId != _loadId) return;
      status = PlayerStatus.error;
      currentSong = null;
      _notify();
    }
  }

  Future<void> pause() async {
    await _active.pause();
    status = PlayerStatus.paused;
    _saveResume();
    _notify();
  }

  Future<void> resume() async {
    await _active.play();
    status = PlayerStatus.playing;
    _notify();
  }

  Future<void> stop() async {
    _loadId++;
    await _active.stop();
    currentSong = null;
    status = PlayerStatus.idle;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEnd = null;
    _notify();
  }

  Future<void> seek(Duration position) => _active.seek(position);
  double _volumeLevel = 1.0;
  double get volume => _volumeLevel;
  Future<void> setVolume(double volume) async {
    _volumeLevel = volume.clamp(0.0, 1.0);
    await _active.setVolume(_volumeLevel * 100);
  }

  // ── Velocidad ────────────────────────────────────────────────────────────

  Future<void> setSpeed(double s) async {
    speed = s;
    await _active.setRate(s);
    _notify();
  }

  // ── Ecualizador ──────────────────────────────────────────────────────────

  Future<void> setEqBand(int index, double db) async {
    eqBands[index] = db.clamp(-12.0, 12.0);
    await _applyEq();
    _notify();
  }

  Future<void> resetEq() async {
    eqBands = List.filled(10, 0.0);
    await _applyEq();
    _notify();
  }

  Future<void> _applyEq() async {
    // media_kit en Windows usa libmpv → soporta filtros de audio vía NativePlayer
    try {
      final native = _active.platform as dynamic;
      // Construir filtro equalizer de mpv
      // formato: equalizer=f=60:width_type=o:width=1:gain=X,equalizer=...
      if (eqBands.every((b) => b == 0.0)) {
        await native.setProperty('af', '');
      } else {
        final filters = List.generate(eqBands.length, (i) {
          final freq = eqFrequencies[i];
          final gain = eqBands[i].toStringAsFixed(1);
          return 'equalizer=f=$freq:width_type=o:width=1:gain=$gain';
        }).join(',');
        await native.setProperty('af', filters);
      }
    } catch (_) {
      // Plataforma sin soporte NativePlayer (no-op)
    }
  }

  // ── Sleep Timer ──────────────────────────────────────────────────────────

  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepEnd = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      pause();
      _sleepEnd = null;
      _sleepTimer = null;
      _notify();
    });
    _notify();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEnd = null;
    _notify();
  }

  // ── Persistencia (reanudar) ──────────────────────────────────────────────

  Future<void> _saveResume() async {
    if (currentSong == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('resume_videoId', currentSong!.videoId);
    await prefs.setString('resume_title', currentSong!.title);
    await prefs.setString('resume_artist', currentSong!.artist);
    await prefs.setString('resume_thumbnail', currentSong!.thumbnail);
    await prefs.setInt('resume_position_ms', position.inMilliseconds);
  }

  Future<void> _loadResume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final videoId = prefs.getString('resume_videoId');
      if (videoId == null) return;
      final song = Song(
        videoId: videoId,
        title: prefs.getString('resume_title') ?? '',
        artist: prefs.getString('resume_artist') ?? '',
        thumbnail: prefs.getString('resume_thumbnail') ?? '',
      );
      final posMs = prefs.getInt('resume_position_ms') ?? 0;
      currentSong = song;
      status = PlayerStatus.paused;
      _queue = [song];
      _queueIndex = 0;
      // Cargar el media pero no reproducir, y saltar a la posición guardada
      final url = _api.streamUrl(song.videoId);
      await _active.open(Media(url), play: false);
      if (posMs > 0) await _active.seek(Duration(milliseconds: posMs));
      _notify();
    } catch (_) {}
  }

  void dispose() {
    _sleepTimer?.cancel();
    for (final sub in _subs) sub.cancel();
    _player.dispose();
    _playerB.dispose();
  }
}
