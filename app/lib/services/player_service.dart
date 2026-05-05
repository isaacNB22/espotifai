import 'dart:async';
import 'dart:math';
import 'package:media_kit/media_kit.dart';
import '../models/song.dart';
import 'api_service.dart';

enum PlayerStatus { idle, loading, playing, paused, error }

class PlayerService {
  final Player _player = Player();
  final ApiService _api;

  Song? currentSong;
  PlayerStatus status = PlayerStatus.idle;

  List<Song> _queue = [];
  int _queueIndex = -1;
  bool shuffle = false;
  bool repeat = false;

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
    _subs.add(_player.stream.playing.listen((playing) {
      if (status == PlayerStatus.loading) return;
      final next = playing ? PlayerStatus.playing : PlayerStatus.paused;
      if (status != next) {
        status = next;
        _notify();
      }
    }));

    _subs.add(_player.stream.completed.listen((completed) {
      if (!completed) return;
      if (repeat) {
        _player.seek(Duration.zero);
        _player.play();
      } else {
        _playNextInQueue();
      }
    }));
  }

  Stream<Duration> get positionStream => _player.stream.position;
  Stream<Duration?> get durationStream =>
      _player.stream.duration.map((d) => d == Duration.zero ? null : d);
  Duration get position => _player.state.position;
  Duration? get duration {
    final d = _player.state.duration;
    return d == Duration.zero ? null : d;
  }

  bool get isPlaying => status == PlayerStatus.playing;
  List<Song> get queue => _queue;
  int get queueIndex => _queueIndex;

  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    _queue = List.of(songs);
    _queueIndex = startIndex;
    await _loadAndPlay(_queue[_queueIndex]);
  }

  Future<void> play(Song song) async {
    if (currentSong?.videoId == song.videoId) {
      if (status == PlayerStatus.paused) await _player.play();
      return;
    }
    final idx = _queue.indexWhere((s) => s.videoId == song.videoId);
    if (idx != -1) {
      _queueIndex = idx;
    } else {
      _queue = [song];
      _queueIndex = 0;
    }
    await _loadAndPlay(song);
  }

  Future<void> playNext() async {
    if (_queue.isEmpty) return;
    _queueIndex = shuffle
        ? Random().nextInt(_queue.length)
        : (_queueIndex + 1) % _queue.length;
    await _loadAndPlay(_queue[_queueIndex]);
  }

  Future<void> playPrev() async {
    if (_queue.isEmpty) return;
    if (position.inSeconds > 3) {
      await _player.seek(Duration.zero);
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
    if (shuffle) {
      _queueIndex = Random().nextInt(_queue.length);
    } else {
      if (_queueIndex >= _queue.length - 1) {
        status = PlayerStatus.idle;
        currentSong = null;
        _notify();
        return;
      }
      _queueIndex++;
    }
    await _loadAndPlay(_queue[_queueIndex]);
  }

  Future<void> _loadAndPlay(Song song) async {
    final myLoadId = ++_loadId;
    status = PlayerStatus.loading;
    currentSong = song;
    _notify();
    try {
      final url = _api.streamUrl(song.videoId);
      await _player.open(Media(url), play: true);
      if (myLoadId != _loadId) return;
      status = PlayerStatus.playing;
      _notify();
    } catch (_) {
      if (myLoadId != _loadId) return;
      status = PlayerStatus.error;
      currentSong = null;
      _notify();
    }
  }

  Future<void> pause() async {
    await _player.pause();
    status = PlayerStatus.paused;
    _notify();
  }

  Future<void> resume() async {
    await _player.play();
    status = PlayerStatus.playing;
    _notify();
  }

  Future<void> stop() async {
    _loadId++;
    await _player.stop();
    currentSong = null;
    status = PlayerStatus.idle;
    _notify();
  }

  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> setVolume(double volume) => _player.setVolume(volume * 100);

  void dispose() {
    for (final sub in _subs) sub.cancel();
    _player.dispose();
  }
}