/**
 * =====================================================================
 * MindMaster — Pattern Recall Game (Simplified Simon Says)
 * =====================================================================
 *
 * Game rules:
 *   - Sequence of colored buttons (green, red, blue, yellow)
 *   - User must repeat the sequence in correct order
 *   - Sequence length grows after each successful round (max 20)
 *   - Game ends on first mistake
 *   - Score = sequence length × multiplier (difficulty based)
 *   - Visual feedback, audio cues, haptic vibration
 *
 * Visual style:
 *   - Circular buttons arranged like a 2x2 grid
 *   - High-contrast neon colors with glow effects
 *   - Smooth transitions and animations
 *
 * Integration:
 *   - Uses MM.Engine for session, scoring, storage, and difficulty
 *   - MM.Audio for sound effects
 *   - MM.Haptics for vibration feedback
 *   - MM.UI components for in-game HUD
 *   - MM.Mouse for tilt interactions (if desired)
 *
 * @author Aether — Game built as part of MindMaster suite
 */

MM.Games = MM.Games || {};

MM.Games.PatternRecall = (function () {
  'use strict';

  // ---- Game state ----
  const state = {
    sequence: [],
    playerSequence: [],
    step: 0,
    level: 1,
    maxLevel: 20,
    active: false,
    speed: 700, // ms per flash
    highScore: 0,
    timer: null,
    finishTimeout: null,
    displayTime: 2000, // how long each step shows
    passed: false,
  };

  // ---- Color definitions ----
  const COLORS = [
    { id: 'green', element: null, bg: 'rgba(0, 255, 157, 0.9)', border: 'var(--neon-green)', sound: 'correct' },
    { id: 'red', element: null, bg: 'rgba(255, 42, 109, 0.9)', border: 'var(--neon-red)', sound: 'wrong' },
    { id: 'blue', element: null, bg: 'rgba(0, 243, 255, 0.9)', border: 'var(--neon-blue)', sound: 'select' },
    { id: 'yellow', element: null, bg: 'rgba(255, 170, 0, 0.9)', border: 'var(--neon-amber)', sound: 'hover' },
  ];

  // ---- Engine helpers ----

  function getHighScore() {
    return MM.Storage.getHighScore ? MM.Storage.getHighScore('pattern_recall', MM.Engine.state.difficulty) : 0;
  }

  async function saveHighScore(score, details) {
    return MM.Storage.saveHighScore('pattern_recall', MM.Engine.state.difficulty, score, details);
  }

  // ---- Sequence generation ----
  function generateStep() {
    const idx = MM.Engine.getRandom(0, COLORS.length - 1);
    state.sequence.push(COLORS[idx]);
  }

  // ---- Visual feedback ----
  function flashColor(color, on) {
    const el = color.element;
    if (!el) return;

    if (on) {
      el.style.background = color.bg;
      el.style.boxShadow = `0 0 20px ${color.border}, inset 0 0 10px rgba(255,255,255,0.3)`;
      MM.Audio.play(color.sound);
    } else {
      el.style.background = 'var(--bg-glass-strong)';
      el.style.boxShadow = 'var(--shadow-glass)';
    }
  }

  // ---- Animation for whole sequence ----
  async function showSequence() {
    state.playerSequence = [];
    state.step = 0;
    const gameEl = MM.Engine.getContainer();
    const statusEl = gameEl?.querySelector('.mm-sequence-status');

    for (let i = 0; i < state.sequence.length; i++) {
      if (statusEl) {
        statusEl.textContent = `WATCHING ${i + 1} / ${state.sequence.length}`;
        statusEl.style.color = COLORS[i].border;
      }
      const c = state.sequence[i];
      flashColor(c, true);
      await new Promise((res) => setTimeout(res, state.displayTime));
      flashColor(c, false);
      await new Promise((res) => setTimeout(res, 200));
    }

    if (statusEl) {
      statusEl.textContent = 'YOUR TURN';
      statusEl.style.color = 'var(--neon-white)';
    }
    state.active = true;
  }

  // ---- Player input ----
  function handleButton(color) {
    if (!state.active) return;
    state.playerSequence.push(color);
    flashColor(color, true);
    MM.Audio.play(color.sound);

    const expected = state.sequence[state.playerSequence.length - 1];
    if (color.id !== expected.id) {
      // wrong!
      state.active = false;
      flashColor(expected, false);
      flashColor(color, false);
      MM.Audio.error();
      MM.Haptics.trigger('error');
      MM.Notifications.error('Wrong!', `You pressed ${color.id} too early.`);
      endGame(false);
      return;
    }

    if (state.playerSequence.length === state.sequence.length) {
      // level complete
      MM.Audio.correct();
      MM.Haptics.trigger('success');
      MM.Notifications.success('Level Complete!', `Sequence memorized.`);
      setTimeout(() => {
        if (state.sequence.length < state.maxLevel) {
          generateStep();
          showSequence();
        } else {
          endGame(true);
        }
      }, 800);
    }
  }

  // ---- Game logic ----

  function reset() {
    state.sequence = [];
    state.playerSequence = [];
    state.step = 0;
    state.level = 1;
    state.active = false;
    clearTimeout(state.finishTimeout);
    const gameEl = MM.Engine.getContainer();
    const statusEl = gameEl?.querySelector('.mm-sequence-status');
    if (statusEl) statusEl.textContent = '';
  }

  function start() {
    if (state.active) return;
    reset();
    generateStep();
    showSequence();
  }

  function end(win) {
    state.active = false;
    clearTimeout(state.finishTimeout);

    // Save high score
    const score = win ? state.sequence.length * MM.Engine.state.difficultyMultiplier : state.sequence.length;
    saveHighScore(score, { level: state.level, steps: state.sequence.length, win, accuracy: win ? 1 : 0 });

    // Show end screen
    const gameEl = MM.Engine.getContainer();
    const endScreen = gameEl?.querySelector('.mm-end-screen');
    const finalScoreEl = endScreen?.querySelector('.mm-final-score');
    const accuracyEl = endScreen?.querySelector('.mm-accuracy');

    if (finalScoreEl) finalScoreEl.textContent = MM.Engine.formatScore(score);
    if (accuracyEl) {
      accuracyEl.textContent = win ? 'PERFECT!' : 'TRY AGAIN';
      accuracyEl.style.color = win ? 'var(--neon-green)' : 'var(--neon-red)';
    }
    if (endScreen) endScreen.style.display = 'flex';
    MM.Audio.complete();
    MM.Engine.endSession(win).then(() => {});
  }

  // ---- Public API ----
  const game = {
    init() {
      return new Promise((resolve) => {
        MM.Audio.init().then(() => {
          // Render buttons (called from UI)
          const gameEl = MM.Engine.getContainer();
          if (gameEl) {
            const grid = document.createElement('div');
            grid.className = 'mm-pattern-grid';
            grid.style.cssText = `
              display: grid;
              grid-template-columns: repeat(2, 1fr);
              grid-template-rows: repeat(2, 1fr);
              gap: 20px;
              width: 320px;
              height: 320px;
              margin: 30px auto;
            `;
            COLORS.forEach((c) => {
              const btn = document.createElement('button');
              btn.className = 'mm-pattern-btn';
              btn.dataset.color = c.id;
              btn.style.cssText = `
                background: var(--bg-glass-strong);
                border: 2px solid ${c.border};
                border-radius: 50%;
                cursor: pointer;
                transition: all var(--ease-out-expo) 0.2s;
                box-shadow: var(--shadow-glass);
                animation: pulse ${c.id === 'red' ? 2 : c.id === 'blue' ? 3 : c.id === 'yellow' ? 4 : 5}s infinite;
              `;
              btn.addEventListener('click', () => handleButton(c));
              btn.addEventListener('touchstart', (e) => {
                e.preventDefault();
                handleButton(c);
              }, { passive: true });
              grid.appendChild(btn);
              c.element = btn;
            });
            gameEl.appendChild(grid);
          }
          resolve();
        });
      });
    },

    start() {
      start();
    },

    end() {
      end(true);
    },

    score() {
      return state.score || state.sequence.length;
    },

    getStats() {
      return {
        level: state.level,
        sequenceLength: state.sequence.length,
        active: state.active,
        finished: state.finished,
      };
    },

    reset,
  };

  // Register game
  MM.Engine.register('pattern_recall', game);

  return game;
})();