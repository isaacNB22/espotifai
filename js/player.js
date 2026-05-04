/* player.js — Music Player powered by Howler.js */
'use strict';

document.addEventListener('DOMContentLoaded', () => {
  const playerEl = document.getElementById('player');
  const thumb = document.getElementById('playerThumb');
  const titleEl = document.getElementById('playerTitle');
  const authorEl = document.getElementById('playerAuthor');
  const playBtn = document.getElementById('playerPlay');
  const prevBtn = document.getElementById('playerPrev');
  const nextBtn = document.getElementById('playerNext');
  const shuffleBtn = document.getElementById('playerShuffle');
  const repeatBtn = document.getElementById('playerRepeat');
  const seekEl = document.getElementById('playerSeek');
  const volEl = document.getElementById('playerVol');
  const curEl = document.getElementById('playerCurrent');
  const durEl = document.getElementById('playerDuration');
  const iconPlay = document.getElementById('iconPlay');
  const iconPause = document.getElementById('iconPause');

  if (!playerEl) return;

  const appShell = document.querySelector('.app-shell');
  const expEl = document.getElementById('playerExp');
  const expBg = document.getElementById('playerExpBg');
  const expArt = document.getElementById('playerExpArt');
  const expTitle = document.getElementById('playerExpTitle');
  const expAuthor = document.getElementById('playerExpAuthor');
  const expSeek = document.getElementById('playerExpSeek');
  const expCurrent = document.getElementById('playerExpCurrent');
  const expDuration = document.getElementById('playerExpDuration');
  const expPlay = document.getElementById('playerExpPlay');
  const expPrev = document.getElementById('playerExpPrev');
  const expNext = document.getElementById('playerExpNext');
  const expVol = document.getElementById('playerExpVol');
  const expClose = document.getElementById('playerExpClose');
  const iconExpPlay = document.getElementById('iconExpPlay');
  const iconExpPause = document.getElementById('iconExpPause');

  const API_BASE = window.location.protocol === 'file:' ? 'http://localhost:3000' : '';

  let _playlist = [];
  let _origPlaylist = [];
  let _idx = -1;
  let _howl = null;
  let _seeking = false;
  let _rafId = null;
  let _vol = 1;
  let _shuffle = false;
  let _repeat = 'none'; // 'none' | 'one' | 'all'

  /* ── Helpers ── */
  function _fmt(s) {
    if (!isFinite(s) || isNaN(s) || s < 0) return '0:00';
    const m = Math.floor(s / 60);
    return m + ':' + String(Math.floor(s % 60)).padStart(2, '0');
  }

  function _setPlayIcon(playing) {
    if (iconPlay) iconPlay.style.display = playing ? 'none' : '';
    if (iconPause) iconPause.style.display = playing ? '' : 'none';
    if (iconExpPlay) iconExpPlay.style.display = playing ? 'none' : '';
    if (iconExpPause) iconExpPause.style.display = playing ? '' : 'none';
  }

  function _updateNowPlaying(videoId) {
    document.querySelectorAll('.lib-track').forEach((row) => {
      row.classList.toggle('now-playing', row.dataset.videoId === videoId);
    });
  }

  /* ── RAF loop para seek slider ── */
  function _startRAF() {
    cancelAnimationFrame(_rafId);
    function tick() {
      if (!_howl || _seeking) {
        _rafId = requestAnimationFrame(tick);
        return;
      }
      const seek = _howl.seek();
      const dur = _howl.duration();
      if (typeof seek === 'number' && dur) {
        const pct = (seek / dur) * 100;
        const timeStr = _fmt(seek);
        const durStr = _fmt(dur);
        if (seekEl) seekEl.value = pct;
        if (expSeek) expSeek.value = pct;
        if (curEl) curEl.textContent = timeStr;
        if (expCurrent) expCurrent.textContent = timeStr;
        if (durEl) durEl.textContent = durStr;
        if (expDuration) expDuration.textContent = durStr;
        if ('mediaSession' in navigator && navigator.mediaSession.setPositionState) {
          try {
            navigator.mediaSession.setPositionState({
              duration: dur,
              playbackRate: 1,
              position: seek,
            });
          } catch (_) {}
        }
      }
      _rafId = requestAnimationFrame(tick);
    }
    _rafId = requestAnimationFrame(tick);
  }

  /* ── Load track con crossfade ── */
  function _loadTrack(t) {
    if (_howl) {
      const old = _howl;
      old.fade(old.volume(), 0, 300);
      setTimeout(() => old.unload(), 350);
      _howl = null;
    }

    const thumbSrc = t.thumbnail || '';
    if (thumb) {
      thumb.src = thumbSrc;
      thumb.alt = t.title || '';
    }
    if (expArt) {
      expArt.src = thumbSrc;
      expArt.alt = t.title || '';
    }
    if (titleEl) titleEl.textContent = t.title || 'Sin título';
    if (authorEl) authorEl.textContent = t.author || '';
    if (expTitle) expTitle.textContent = t.title || 'Sin título';
    if (expAuthor) expAuthor.textContent = t.author || '';
    if (expBg) expBg.style.backgroundImage = thumbSrc ? `url('${thumbSrc}')` : '';
    if (seekEl) seekEl.value = 0;
    if (expSeek) expSeek.value = 0;
    if (curEl) curEl.textContent = '0:00';
    if (expCurrent) expCurrent.textContent = '0:00';
    if (durEl) durEl.textContent = '0:00';
    if (expDuration) expDuration.textContent = '0:00';
    playerEl.classList.add('visible');
    appShell?.classList.add('has-player');
    _updateNowPlaying(t.videoId);

    if ('mediaSession' in navigator) {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: t.title || 'Sin título',
        artist: t.author || '',
        artwork: thumbSrc ? [{ src: thumbSrc, sizes: '480x360', type: 'image/jpeg' }] : [],
      });
      navigator.mediaSession.setActionHandler('play', () => player.toggle());
      navigator.mediaSession.setActionHandler('pause', () => player.toggle());
      navigator.mediaSession.setActionHandler('nexttrack', () => player.next());
      navigator.mediaSession.setActionHandler('previoustrack', () => player.prev());
      navigator.mediaSession.setActionHandler('seekto', (d) => {
        if (_howl && d.seekTime != null) _howl.seek(d.seekTime);
      });
    }

    _howl = new Howl({
      src: [API_BASE + '/api/stream/' + t.videoId],
      html5: true,
      volume: 0,
      format: ['mp3'],
      onplay: () => {
        _howl.fade(0, _vol, 250);
        _setPlayIcon(true);
        if ('mediaSession' in navigator) navigator.mediaSession.playbackState = 'playing';
        _startRAF();
      },
      onpause: () => {
        _setPlayIcon(false);
        if ('mediaSession' in navigator) navigator.mediaSession.playbackState = 'paused';
      },
      onstop: () => _setPlayIcon(false),
      onend: () => player.next(),
      onloaderror: (_id, err) => console.warn('[player] load error:', err),
      onplayerror: (_id, _err) => {
        _howl?.once('unlock', () => _howl.play());
      },
    });

    _howl.play();
  }

  /* ── Player API ── */
  const player = {
    play(videoId) {
      const idx = _playlist.findIndex((t) => t.videoId === videoId);
      if (idx === -1) return;
      _idx = idx;
      _loadTrack(_playlist[idx]);
    },
    toggle() {
      if (!_howl) return;
      if (_howl.playing()) _howl.pause();
      else _howl.play();
    },
    next() {
      if (!_playlist.length) return;
      if (_repeat === 'one') {
        _howl?.seek(0);
        _howl?.play();
        return;
      }
      _idx = (_idx + 1) % _playlist.length;
      _loadTrack(_playlist[_idx]);
    },
    prev() {
      if (!_playlist.length) return;
      const seek = typeof _howl?.seek() === 'number' ? _howl.seek() : 0;
      if (seek > 3) {
        _howl?.seek(0);
        return;
      }
      _idx = (_idx - 1 + _playlist.length) % _playlist.length;
      _loadTrack(_playlist[_idx]);
    },
    currentVideoId() {
      return _idx >= 0 ? (_playlist[_idx]?.videoId ?? null) : null;
    },
    load(tracks) {
      _origPlaylist = tracks || [];
      _playlist = _shuffle ? _shuffled(_origPlaylist) : _origPlaylist.slice();
    },
  };

  function _shuffled(arr) {
    const a = arr.slice();
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }

  /* ── Controls ── */
  playBtn?.addEventListener('click', () => player.toggle());
  nextBtn?.addEventListener('click', () => player.next());
  prevBtn?.addEventListener('click', () => player.prev());

  shuffleBtn?.addEventListener('click', () => {
    _shuffle = !_shuffle;
    shuffleBtn.classList.toggle('is-active', _shuffle);
    if (_origPlaylist.length) {
      const cur = _playlist[_idx]?.videoId;
      _playlist = _shuffle ? _shuffled(_origPlaylist) : _origPlaylist.slice();
      _idx = cur ? _playlist.findIndex((t) => t.videoId === cur) : 0;
      if (_idx < 0) _idx = 0;
    }
  });

  repeatBtn?.addEventListener('click', () => {
    const modes = ['none', 'one', 'all'];
    _repeat = modes[(modes.indexOf(_repeat) + 1) % modes.length];
    repeatBtn.classList.toggle('is-active', _repeat !== 'none');
    repeatBtn.title =
      _repeat === 'one' ? 'Repetir una' : _repeat === 'all' ? 'Repetir todo' : 'Repetir';
  });

  function _setVolume(v) {
    _vol = Math.max(0, Math.min(1, Number(v)));
    if (_howl) _howl.volume(_vol);
    if (volEl) volEl.value = _vol;
    if (expVol) expVol.value = _vol;
  }
  volEl?.addEventListener('input', () => _setVolume(volEl.value));
  expVol?.addEventListener('input', () => _setVolume(expVol.value));

  seekEl?.addEventListener('mousedown', () => {
    _seeking = true;
  });
  seekEl?.addEventListener(
    'touchstart',
    () => {
      _seeking = true;
    },
    { passive: true }
  );
  seekEl?.addEventListener('input', () => {
    if (_howl && curEl) curEl.textContent = _fmt((_howl.duration() * seekEl.value) / 100);
  });
  seekEl?.addEventListener('change', () => {
    if (_howl) _howl.seek((_howl.duration() * Number(seekEl.value)) / 100);
    _seeking = false;
  });
  expSeek?.addEventListener('change', () => {
    if (_howl) _howl.seek((_howl.duration() * Number(expSeek.value)) / 100);
  });

  document.addEventListener('keydown', (e) => {
    if (e.code === 'Escape' && expEl?.classList.contains('open')) {
      closeExpanded();
      return;
    }
    if (['INPUT', 'TEXTAREA'].includes(e.target.tagName)) return;
    if (e.code === 'Space') {
      e.preventDefault();
      player.toggle();
    }
    if (e.code === 'ArrowRight' && _howl) _howl.seek(Math.min(_howl.duration(), _howl.seek() + 5));
    if (e.code === 'ArrowLeft' && _howl) _howl.seek(Math.max(0, _howl.seek() - 5));
  });

  /* ── Expanded player ── */
  function openExpanded() {
    if (!expEl) return;
    expEl.classList.add('open');
    expEl.removeAttribute('aria-hidden');
  }
  function closeExpanded() {
    expEl?.classList.remove('open');
    expEl?.setAttribute('aria-hidden', 'true');
  }
  thumb?.addEventListener('click', openExpanded);
  expClose?.addEventListener('click', closeExpanded);
  expPlay?.addEventListener('click', () => player.toggle());
  expNext?.addEventListener('click', () => player.next());
  expPrev?.addEventListener('click', () => player.prev());

  window.espotifaiPlayer = player;
});

document.addEventListener('DOMContentLoaded', () => {
  const audio = document.getElementById('audioEl');
  const playerEl = document.getElementById('player');
  const thumb = document.getElementById('playerThumb');
  const titleEl = document.getElementById('playerTitle');
  const authorEl = document.getElementById('playerAuthor');
  const playBtn = document.getElementById('playerPlay');
  const prevBtn = document.getElementById('playerPrev');
  const nextBtn = document.getElementById('playerNext');
  const seekEl = document.getElementById('playerSeek');
  const volEl = document.getElementById('playerVol');
  const curEl = document.getElementById('playerCurrent');
  const durEl = document.getElementById('playerDuration');
  const iconPlay = document.getElementById('iconPlay');
  const iconPause = document.getElementById('iconPause');

  if (!audio || !playerEl) return;

  const appShell = document.querySelector('.app-shell');
  const expEl = document.getElementById('playerExp');
  const expBg = document.getElementById('playerExpBg');
  const expArt = document.getElementById('playerExpArt');
  const expTitle = document.getElementById('playerExpTitle');
  const expAuthor = document.getElementById('playerExpAuthor');
  const expSeek = document.getElementById('playerExpSeek');
  const expCurrent = document.getElementById('playerExpCurrent');
  const expDuration = document.getElementById('playerExpDuration');
  const expPlay = document.getElementById('playerExpPlay');
  const expPrev = document.getElementById('playerExpPrev');
  const expNext = document.getElementById('playerExpNext');
  const expVol = document.getElementById('playerExpVol');
  const expClose = document.getElementById('playerExpClose');
  const iconExpPlay = document.getElementById('iconExpPlay');
  const iconExpPause = document.getElementById('iconExpPause');

  let _playlist = [];
  let _idx = -1;
  let _seeking = false;

  const player = {
    load(tracks) {
      _playlist = (tracks || []).filter((t) => t.downloadStatus === 'done');
    },
    play(videoId) {
      const idx = _playlist.findIndex((t) => t.videoId === videoId);
      if (idx === -1) return;
      _idx = idx;
      _loadTrack(_playlist[idx]);
      audio.play().catch((err) => console.warn('[player] play error:', err));
    },
    toggle() {
      if (audio.paused) audio.play().catch(() => {});
      else audio.pause();
    },
    next() {
      if (!_playlist.length) return;
      _idx = (_idx + 1) % _playlist.length;
      _loadTrack(_playlist[_idx]);
      audio.play().catch(() => {});
    },
    prev() {
      if (!_playlist.length) return;
      if (audio.currentTime > 3) {
        audio.currentTime = 0;
        return;
      }
      _idx = (_idx - 1 + _playlist.length) % _playlist.length;
      _loadTrack(_playlist[_idx]);
      audio.play().catch(() => {});
    },
    currentVideoId() {
      return _idx >= 0 ? (_playlist[_idx]?.videoId ?? null) : null;
    },
  };

  function _loadTrack(t) {
    const API = window.location.protocol === 'file:' ? 'http://localhost:3000' : '';
    audio.src = API + '/api/stream/' + t.videoId;
    audio.load();
    if (titleEl) titleEl.textContent = t.title || 'Sin titulo';
    if (authorEl) authorEl.textContent = t.author || '';
    const thumbSrc = t.thumbnail || '';
    if (thumb) {
      thumb.src = thumbSrc;
      thumb.alt = t.title || '';
    }
    // Expanded player sync
    if (expArt) {
      expArt.src = thumbSrc;
      expArt.alt = t.title || '';
    }
    if (expTitle) expTitle.textContent = t.title || 'Sin titulo';
    if (expAuthor) expAuthor.textContent = t.author || '';
    if (expBg) expBg.style.backgroundImage = thumbSrc ? `url('${thumbSrc}')` : '';
    playerEl.classList.add('visible');
    appShell?.classList.add('has-player');

    // Media Session API — controles del OS / lockscreen
    if ('mediaSession' in navigator) {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: t.title || 'Sin titulo',
        artist: t.author || '',
        artwork: thumbSrc ? [{ src: thumbSrc, sizes: '480x360', type: 'image/jpeg' }] : [],
      });
      navigator.mediaSession.setActionHandler('play', () => audio.play().catch(() => {}));
      navigator.mediaSession.setActionHandler('pause', () => audio.pause());
      navigator.mediaSession.setActionHandler('nexttrack', () => player.next());
      navigator.mediaSession.setActionHandler('previoustrack', () => player.prev());
      navigator.mediaSession.setActionHandler('seekto', (d) => {
        if (d.seekTime != null) audio.currentTime = d.seekTime;
      });
    }

    if (seekEl) seekEl.value = 0;
    if (curEl) curEl.textContent = '0:00';
    if (durEl) durEl.textContent = '0:00';
    if (expSeek) expSeek.value = 0;
    if (expCurrent) expCurrent.textContent = '0:00';
    if (expDuration) expDuration.textContent = '0:00';
    _updateNowPlaying(t.videoId);
  }

  function _fmt(s) {
    if (!isFinite(s) || isNaN(s)) return '0:00';
    const m = Math.floor(s / 60);
    const sec = String(Math.floor(s % 60)).padStart(2, '0');
    return m + ':' + sec;
  }

  function _setPlayIcon(playing) {
    if (iconPlay) iconPlay.style.display = playing ? 'none' : '';
    if (iconPause) iconPause.style.display = playing ? '' : 'none';
    if (iconExpPlay) iconExpPlay.style.display = playing ? 'none' : '';
    if (iconExpPause) iconExpPause.style.display = playing ? '' : 'none';
  }

  function _updateNowPlaying(videoId) {
    document.querySelectorAll('.lib-track').forEach((row) => {
      if (row.dataset.videoId === videoId) row.classList.add('now-playing');
      else row.classList.remove('now-playing');
    });
  }

  playBtn?.addEventListener('click', () => player.toggle());
  nextBtn?.addEventListener('click', () => player.next());
  prevBtn?.addEventListener('click', () => player.prev());

  // Expanded player open/close
  function openExpanded() {
    if (!expEl) return;
    expEl.classList.add('open');
    expEl.removeAttribute('aria-hidden');
    if (volEl && expVol) expVol.value = volEl.value;
    if (seekEl && expSeek) expSeek.value = seekEl.value;
    if (curEl && expCurrent) expCurrent.textContent = curEl.textContent;
    if (durEl && expDuration) expDuration.textContent = durEl.textContent;
  }
  function closeExpanded() {
    expEl?.classList.remove('open');
    expEl?.setAttribute('aria-hidden', 'true');
  }
  thumb?.addEventListener('click', openExpanded);
  expClose?.addEventListener('click', closeExpanded);
  expPlay?.addEventListener('click', () => player.toggle());
  expNext?.addEventListener('click', () => player.next());
  expPrev?.addEventListener('click', () => player.prev());
  expVol?.addEventListener('input', () => {
    audio.volume = Number(expVol.value);
    if (volEl) volEl.value = expVol.value;
  });
  expSeek?.addEventListener('change', () => {
    if (audio.duration) audio.currentTime = (expSeek.value / 100) * audio.duration;
  });

  // Escape key closes expanded
  document.addEventListener('keydown', (e) => {
    if (e.code === 'Escape' && expEl?.classList.contains('open')) {
      closeExpanded();
      return;
    }
    if (['INPUT', 'TEXTAREA'].includes(e.target.tagName)) return;
    if (e.code === 'Space') {
      e.preventDefault();
      player.toggle();
    }
    if (e.code === 'ArrowRight')
      audio.currentTime = Math.min(audio.duration || 0, audio.currentTime + 5);
    if (e.code === 'ArrowLeft') audio.currentTime = Math.max(0, audio.currentTime - 5);
  });

  audio.addEventListener('play', () => {
    _setPlayIcon(true);
    if ('mediaSession' in navigator) navigator.mediaSession.playbackState = 'playing';
  });
  audio.addEventListener('pause', () => {
    _setPlayIcon(false);
    if ('mediaSession' in navigator) navigator.mediaSession.playbackState = 'paused';
  });
  audio.addEventListener('ended', () => player.next());
  audio.addEventListener('error', (e) => console.warn('[player] audio error:', e));

  audio.addEventListener('timeupdate', () => {
    if (_seeking) return;
    const ct = audio.currentTime;
    const dur = audio.duration;
    const timeStr = _fmt(ct);
    if (curEl) curEl.textContent = timeStr;
    if (expCurrent) expCurrent.textContent = timeStr;
    if (dur && seekEl) {
      const pct = (ct / dur) * 100;
      seekEl.value = pct;
      if (expSeek) expSeek.value = pct;
      const durStr = _fmt(dur);
      if (durEl) durEl.textContent = durStr;
      if (expDuration) expDuration.textContent = durStr;
    }
  });

  audio.addEventListener('loadedmetadata', () => {
    const d = _fmt(audio.duration);
    if (durEl) durEl.textContent = d;
    if (expDuration) expDuration.textContent = d;
  });

  seekEl?.addEventListener('mousedown', () => {
    _seeking = true;
  });
  seekEl?.addEventListener('input', () => {
    if (audio.duration && curEl) curEl.textContent = _fmt((seekEl.value / 100) * audio.duration);
  });
  seekEl?.addEventListener('change', () => {
    if (audio.duration) audio.currentTime = (seekEl.value / 100) * audio.duration;
    _seeking = false;
  });

  volEl?.addEventListener('input', () => {
    audio.volume = Number(volEl.value);
    if (expVol) expVol.value = volEl.value;
  });

  window.espotifaiPlayer = player;
});
