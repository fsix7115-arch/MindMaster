/**
 * =====================================================================
 * MindMaster — Audio Engine (Synthesizer SFX + Music Manager)
 * =====================================================================
 *
 * PURPOSE
 *   Generate all sound effects in real-time using the Web Audio API
 *   (no asset files needed). Includes procedural SFX for game events,
 *   UI feedback, win/loss, and a background music sequencer.
 *
 * DESIGN
 *   - Oscillator-based synthesis: crisp, modern, zero download size
 *   - Reverb/delay chains for atmosphere
 *   - Volume envelopes (attack/decay/sustain/release)
 *   - Music sequencer with step-based patterns
 *   - Automatic gain handling + ducking when SFX plays
 *   - Reduced-audio respect for accessibility
 *
 * API
 *   MM.Audio.init()                 — initialize (user gesture required)
 *   MM.Audio.play('sfxName', opts)  — play an SFX
 *   MM.Audio.music.play() / pause()
 *   MM.Audio.setMasterVolume(v)
 *
 * @author Aether
 */

MM.Audio = (function () {
  'use strict';

  const STATE = {
    ctx: null,
    masterGain: null,
    musicGain: null,
    sfxGain: null,
    reverb: null,
    musicActive: false,
    musicVolume: 0.4,
    sfxVolume: 0.7,
    muted: false,
    initDone: false,
  };

  const CONFIG = {
    musicBpm: 110,
    musicNotes: [
      [261.63, 0], [311.13, 0], [392.00, 0], [493.88, 0],  // Am7
      [349.23, 0], [415.30, 0], [523.25, 0], [622.25, 0],  // Dm7
      [293.66, 0], [349.23, 0], [440.00, 0], [554.37, 0],  // G7
      [220.00, 0], [261.63, 0], [329.63, 0], [440.00, 0],  // Am7
    ],
  };

  // ---- SFX synthesis functions ----

  /**
   * Create an oscillator with ADSR envelope
   */
  function createOscillator(type, freq, duration, options = {}) {
    const ctx = STATE.ctx;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();

    osc.type = type;
    osc.frequency.setValueAtTime(freq, ctx.currentTime);

    // Frequency modulation (optional)
    if (options.modFreq) {
      const lfo = ctx.createOscillator();
      const lfoGain = ctx.createGain();
      lfo.frequency.value = options.modFreq;
      lfoGain.gain.value = options.modDepth ?? 50;
      lfo.connect(lfoGain).connect(osc.frequency);
      lfo.start();
      lfo.stop(ctx.currentTime + duration);
    }

    // ADSR envelope
    const now = ctx.currentTime;
    gain.gain.setValueAtTime(0, now);
    gain.gain.linearRampToValueAtTime(1, now + (options.attack ?? 0.01));
    gain.gain.exponentialRampToValueAtTime(
      options.decayLevel ?? 0.3,
      now + (options.attack ?? 0.01) + (options.decay ?? 0.2)
    );
    gain.gain.exponentialRampToValueAtTime(
      0.001,
      now + (options.attack ?? 0.01) + (options.decay ?? 0.2) + (options.sustain ?? duration)
    );

    osc.connect(gain);
    return { osc, gain };
  }

  /**
   * Noise buffer for impacts/explosions
   */
  function createNoise(duration) {
    const ctx = STATE.ctx;
    const bufferSize = ctx.sampleRate * duration;
    const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < bufferSize; i++) {
      data[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / bufferSize, 2);
    }
    return buffer;
  }

  // ---- SFX library ----
  const SFX = {
    // UI sounds
    click() {
      const { osc, gain } = createOscillator('sine', 800, 0.08, {
        attack: 0.005, decay: 0.06, sustain: 0.05,
        modFreq: 1200, modDepth: 800,
      });
      gain.connect(STATE.sfxGain);
      osc.start();
      osc.stop(STATE.ctx.currentTime + 0.08);
    },

    hover() {
      const { osc, gain } = createOscillator('sine', 1200, 0.05, {
        attack: 0.003, decay: 0.04, sustain: 0.03,
      });
      gain.connect(STATE.sfxGain);
      osc.start();
      osc.stop(STATE.ctx.currentTime + 0.05);
    },

    select() {
      const { osc, gain } = createOscillator('triangle', 600, 0.12, {
        attack: 0.01, decay: 0.08, sustain: 0.06,
      });
      const osc2 = STATE.ctx.createOscillator();
      const gain2 = STATE.ctx.createGain();
      osc2.type = 'square';
      osc2.frequency.setValueAtTime(600, STATE.ctx.currentTime);
      gain2.gain.setValueAtTime(0.3, STATE.ctx.currentTime);
      gain2.gain.exponentialRampToValueAtTime(0.001, STATE.ctx.currentTime + 0.12);
      osc2.connect(gain2);
      gain2.connect(STATE.sfxGain);
      osc2.start();
      osc2.stop(STATE.ctx.currentTime + 0.12);

      gain.connect(STATE.sfxGain);
      osc.start();
      osc.stop(STATE.ctx.currentTime + 0.12);
    },

    // Game sounds
    correct() {
      const now = STATE.ctx.currentTime;
      [523.25, 659.25, 783.99, 1046.50].forEach((freq, i) => {
        const { osc, gain } = createOscillator('sine', freq, 0.25, {
          attack: 0.01, decay: 0.2, sustain: 0.3,
        });
        osc.frequency.setValueAtTime(freq, now + i * 0.08);
        gain.connect(STATE.sfxGain);
        osc.start(now + i * 0.08);
        osc.stop(now + i * 0.08 + 0.25);
      });
    },

    wrong() {
      const { osc, gain } = createOscillator('sawtooth', 150, 0.3, {
        attack: 0.02, decay: 0.25, sustain: 0.2,
        modFreq: 200, modDepth: 150,
      });
      gain.gain.setValueAtTime(0.6, STATE.ctx.currentTime);
      gain.connect(STATE.sfxGain);
      osc.start();
      osc.stop(STATE.ctx.currentTime + 0.3);
    },

    complete() {
      const now = STATE.ctx.currentTime;
      [329.63, 392.00, 493.88, 523.25, 659.25, 783.99].forEach((freq, i) => {
        const { osc, gain } = createOscillator('sine', freq, 0.35, {
          attack: 0.02, decay: 0.25, sustain: 0.4,
        });
        osc.frequency.setValueAtTime(freq, now + i * 0.1);
        gain.connect(STATE.sfxGain);
        osc.start(now + i * 0.1);
        osc.stop(now + i * 0.1 + 0.35);
      });
    },

    levelUp() {
      const now = STATE.ctx.currentTime;
      for (let i = 0; i < 8; i++) {
        const freq = 200 + i * 120;
        const { osc, gain } = createOscillator('sawtooth', freq, 0.2, {
          attack: 0.02, decay: 0.15, sustain: 0.3,
        });
        gain.connect(STATE.sfxGain);
        osc.start(now + i * 0.08);
        osc.stop(now + i * 0.08 + 0.2);
      }
    },

    tap() {
      const { osc, gain } = createOscillator('sine', 900, 0.06, {
        attack: 0.005, decay: 0.05, sustain: 0.04,
      });
      gain.connect(STATE.sfxGain);
      osc.start();
      osc.stop(STATE.ctx.currentTime + 0.06);
    },

    error() {
      const { osc, gain } = createOscillator('square', 100, 0.35, {
        attack: 0.03, decay: 0.3, sustain: 0.25,
      });
      gain.connect(STATE.sfxGain);
      osc.start();
      osc.stop(STATE.ctx.currentTime + 0.35);
    },

    win() {
      const now = STATE.ctx.currentTime;
      [523.25, 659.25, 783.99, 1046.50, 1318.51].forEach((freq, i) => {
        const { osc, gain } = createOscillator('sine', freq, 0.4, {
          attack: 0.02, decay: 0.3, sustain: 0.5,
        });
        osc.frequency.setValueAtTime(freq, now + i * 0.1);
        gain.connect(STATE.sfxGain);
        osc.start(now + i * 0.1);
        osc.stop(now + i * 0.1 + 0.4);
      });
    },

    achievement() {
      MM.Audio.complete();
      setTimeout(() => MM.Audio.levelUp(), 400);
    },

    // Background ambience helper
    background() {
      const { osc, gain } = createOscillator('sine', 220, 2.0, {
        attack: 1.0, decay: 1.0, sustain: 0.1,
      });
      gain.connect(STATE.sfxGain);
      osc.start();
      osc.stop(STATE.ctx.currentTime + 2.0);
    },
  };

  // ---- Music sequencer ----
  let musicInterval = null;
  let musicNoteIndex = 0;
  let musicTime = 0;

  function playMusicNote(note, time) {
    const duration = 60 / CONFIG.musicBpm / 4;
    const { osc, gain } = createOscillator('sine', note, duration, {
      attack: 0.05, decay: 0.15, sustain: 0.4,
    });
    gain.connect(STATE.musicGain);
    osc.start(STATE.ctx.currentTime + time);
    osc.stop(STATE.ctx.currentTime + time + duration);
  }

  function musicStep() {
    if (!STATE.musicActive) return;
    const pattern = CONFIG.musicNotes;
    const note = pattern[musicNoteIndex % pattern.length];
    playMusicNote(note[0], 0);
    musicNoteIndex++;
  }

  function startMusic() {
    if (STATE.musicActive) return;
    STATE.musicActive = true;
    musicNoteIndex = 0;
    musicInterval = setInterval(musicStep, 60000 / CONFIG.musicBpm / 4);
  }

  function stopMusic() {
    STATE.musicActive = false;
    if (musicInterval) {
      clearInterval(musicInterval);
      musicInterval = null;
    }
  }

  // ---- Initialization ----
  function init() {
    if (STATE.initDone) return Promise.resolve();

    return new Promise((resolve) => {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      STATE.ctx = new AudioContext();

      // Master chain
      STATE.masterGain = STATE.ctx.createGain();
      STATE.masterGain.gain.value = STATE.muted ? 0 : 1;

      STATE.sfxGain = STATE.ctx.createGain();
      STATE.sfxGain.gain.value = STATE.sfxVolume;

      STATE.musicGain = STATE.ctx.createGain();
      STATE.musicGain.gain.value = STATE.musicVolume;

      // Reverb (convolver)
      const convolver = STATE.ctx.createConvolver();
      const impulse = createReverbImpulse(STATE.ctx);
      convolver.buffer = impulse;
      convolver.connect(STATE.masterGain);

      STATE.sfxGain.connect(convolver);
      STATE.musicGain.connect(convolver);

      STATE.sfxGain.connect(STATE.masterGain);
      STATE.musicGain.connect(STATE.masterGain);
      STATE.masterGain.connect(STATE.ctx.destination);

      STATE.initDone = true;
      if (STATE.ctx.state === 'suspended') {
        STATE.ctx.resume().then(resolve);
      } else {
        resolve();
      }
    });
  }

  function createReverbImpulse(ctx) {
    const length = ctx.sampleRate * 2.5;
    const buffer = ctx.createBuffer(2, length, ctx.sampleRate);
    for (let c = 0; c < 2; c++) {
      const data = buffer.getChannelData(c);
      for (let i = 0; i < length; i++) {
        data[i] = (Math.random() * 2 - 1) * Math.exp(-i / (length * 0.001));
      }
    }
    return buffer;
  }

  // ---- Public API ----
  return {
    async init() {
      await init();
      return true;
    },

    play(name, options = {}) {
      if (!STATE.initDone) return Promise.resolve();
      if (STATE.muted) return Promise.resolve();

      return new Promise((resolve) => {
        const now = STATE.ctx.currentTime;

        // Duck music when SFX plays
        const musicVol = STATE.musicGain.gain.value;
        STATE.musicGain.gain.setTargetAtTime(0.1, now, 0.05);
        setTimeout(() => {
          STATE.musicGain.gain.setTargetAtTime(musicVol, now + 0.15, 0.1);
        }, 150);

        SFX[name]?.();
        if (options.haptic) {
          MM.Haptics.vibrate(50);
        }
        resolve();
      });
    },

    playSequence(names, delay = 100) {
      return new Promise((resolve) => {
        let i = 0;
        function playNext() {
          if (i >= names.length) {
            setTimeout(resolve, delay);
            return;
          }
          MM.Audio.play(names[i]).then(playNext);
          i++;
        }
        playNext();
      });
    },

    async click() { await this.play('click'); },
    async hover() { await this.play('hover'); },
    async select() { await this.play('select'); },
    async correct() { await this.play('correct'); },
    async wrong() { await this.play('wrong'); },
    async complete() { await this.play('complete'); },
    async levelUp() { await this.play('levelUp'); },
    async tap() { await this.play('tap'); },
    async error() { await this.play('error'); },
    async win() { await this.play('win'); },
    async achievement() { await this.play('achievement'); },

    get state() { return { ...STATE }; },

    setMuted(muted) {
      STATE.muted = muted;
      if (STATE.masterGain) STATE.masterGain.gain.value = muted ? 0 : 1;
    },

    setMasterVolume(v) {
      STATE.masterGain.gain.value = Math.max(0, Math.min(1, v));
    },

    getMusicVolume() { return STATE.musicVolume; },
    setMusicVolume(v) {
      STATE.musicVolume = Math.max(0, Math.min(1, v));
      if (STATE.musicGain) STATE.musicGain.gain.value = STATE.musicVolume;
    },

    toggleMusic() {
      if (STATE.musicActive) stopMusic();
      else startMusic();
      return STATE.musicActive;
    },

    musicPlay() { startMusic(); },
    musicStop() { stopMusic(); },
    musicToggle() { return this.toggleMusic(); },
  };
})();