/**
 * =====================================================================
 * Focus Grid — Number Tap Challenge (1-25)
 * =====================================================================
 *
 * Rules:
 *   - 5x5 grid of numbers 1-25 shuffled
 *   - Tap numbers in ascending order as FAST as possible
 *   - Time is the score (lower = better)
 *   - Wrong tap = +2 seconds penalty
 *   - Difficulty: easy=6x6 (1-36), medium=5x5 (1-25), hard=4x4 (1-16)
 *   - High score = fastest time
 *
 * 3D Element: Grid rotates slightly on mouse move, numbers have parallax
 *
 * @author Aether
 */

MM.Games = MM.Games || {};

MM.Games.FocusGrid = (function () {
  'use strict';

  const state = {
    size: 5,
    numbers: [],
    current: 1,
    time: 0,
    errors: 0,
    bestTime: Infinity,
    active: false,
    difficulty: 'medium',
  };

  function getDifficultyConfig(difficulty) {
    return {
      easy: { size: 6, maxNum: 36 },
      medium: { size: 5, maxNum: 25 },
      hard: { size: 4, maxNum: 16 },
    }[difficulty] || { size: 5, maxNum: 25 };
  }

  function generateGrid() {
    const cfg = getDifficultyConfig(state.difficulty);
    state.size = cfg.size;
    const numbers = Array.from({ length: cfg.maxNum }, (_, i) => i + 1);
    state.numbers = MM.Engine.shuffle(numbers);
    state.current = 1;
    state.errors = 0;
    state.time = 0;
    renderGrid();
  }

  function renderGrid() {
    const container = MM.Engine.getContainer();
    if (!container) return;

    const gridEl = container.querySelector('.mm-focus-grid');
    if (!gridEl) return;

    gridEl.innerHTML = '';
    gridEl.style.gridTemplateColumns = `repeat(${state.size}, 1fr)`;
    gridEl.style.gridTemplateRows = `repeat(${state.size}, 1fr)`;
    gridEl.style.maxWidth = `${state.size === 6 ? 420 : state.size === 5 ? 360 : 280}px`;

    state.numbers.forEach((num) => {
      const cell = document.createElement('button');
      cell.className = 'mm-focus-cell glass-card';
      cell.textContent = num;
      cell.dataset.num = num;

      const isNext = num === state.current;
      cell.style.cssText = `
        aspect-ratio: 1;
        border-radius: 8px;
        font-family: 'Orbitron', sans-serif;
        font-size: ${state.size === 6 ? '1rem' : '1.3rem'};
        font-weight: 700;
        color: ${isNext ? 'var(--neon-green)' : 'var(--text-secondary)'};
        background: ${isNext ? 'linear-gradient(135deg, var(--neon-green-dim), var(--neon-blue-dim))' : 'var(--bg-glass-strong)'};
        border: ${isNext ? '2px solid var(--neon-green)' : '1px solid var(--border-glass)'};
        cursor: pointer;
        transition: all var(--ease-out-expo) 0.2s;
        user-select: none;
        box-shadow: ${isNext ? 'var(--glow-green)' : 'none'};
      `;

      cell.addEventListener('click', () => handleTap(num, cell));
      cell.addEventListener('mouseenter', () => {
        if (!isNext) return;
        cell.style.transform = 'scale(1.08)';
      });
      cell.addEventListener('mouseleave', () => {
        if (!isNext) return;
        cell.style.transform = 'scale(1)';
      });

      // Mouse tracker for 3D tilt
      if (MM.Mouse) {
        MM.Mouse.trackElement(cell, { depth: 6, tilt: 4 });
      }

      gridEl.appendChild(cell);
    });
  }

  function handleTap(num, cell) {
    if (!state.active) return;

    if (num === state.current) {
      state.current++;
      cell.style.background = 'linear-gradient(135deg, var(--neon-green), #00cc7a)';
      cell.style.color = '#000';
      cell.style.fontWeight = '900';
      cell.style.pointerEvents = 'none';
      cell.style.opacity = '0.6';

      MM.Audio.correct();
      MM.Haptics.trigger('selection');

      if (state.current > (state.size * state.size)) {
        // Win!
        state.active = false;
        clearInterval(state.timerInterval);
        MM.Audio.complete();
        endGame();
      } else {
        // Update next target
        renderGrid();
      }
    } else {
      // Wrong tap
      state.errors++;
      state.time += 2; // Penalty

      cell.style.background = 'linear-gradient(135deg, var(--neon-red), #ff0055)';
      cell.style.color = '#fff';
      cell.style.borderColor = 'var(--neon-red)';

      MM.Audio.wrong();
      MM.Haptics.trigger('error');

      setTimeout(() => {
        cell.style.background = 'var(--bg-glass-strong)';
        cell.style.color = 'var(--text-secondary)';
        cell.style.borderColor = 'var(--border-glass)';
      }, 400);

      const errorEl = MM.Engine.getContainer()?.querySelector('.mm-error-display');
      if (errorEl) errorEl.textContent = state.errors;
    }
  }

  function updateHUD() {
    const timerEl = MM.Engine.getContainer()?.querySelector('.mm-timer-display');
    if (timerEl) timerEl.textContent = MM.Engine.formatTime(state.time);
  }

  function newGame() {
    state.difficulty = MM.Engine.difficulty;
    state.active = true;
    state.bestTime = Infinity;
    generateGrid();

    state.timerInterval = setInterval(() => {
      state.time++;
      updateHUD();
    }, 100);
  }

  function endGame() {
    if (state.time < state.bestTime) {
      state.bestTime = state.time;
    }

    const score = Math.max(0, (state.size * state.size * 1000) - (state.time * 10) - (state.errors * 50));
    MM.Engine.state.session = {
      ...MM.Engine.state.session,
      score,
      duration: state.time,
      errors: state.errors,
    };

    MM.Engine.endSession(true);
  }

  function reset() {
    clearInterval(state.timerInterval);
    state.active = false;
    const container = MM.Engine.getContainer();
    if (container) {
      container.querySelector('.mm-focus-grid').innerHTML = '';
    }
  }

  const game = {
    init() {
      return MM.Audio.init().then(() => { reset(); });
    },
    start() { newGame(); },
    end() { endGame(); },
    score() { return state.bestTime === Infinity ? 0 : Math.floor((state.size * state.size * 1000) - (state.bestTime * 10)); },
    reset,
  };

  MM.Engine.register('focus_grid', game);
  return game;
})();
