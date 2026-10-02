/**
 * =====================================================================
 * Memory Matrix — Pair Matching Game (4x4 / 6x6 / 8x8)
 * =====================================================================
 *
 * Rules:
 *   - Cards with symbols appear face down
 *   - Flip two cards, if they match they stay open
 *   - If wrong, they flip back after delay
 *   - Fewer moves = higher score + time bonus
 *   - 4x4 (8 pairs), 6x6 (18 pairs), 8x8 (32 pairs)
 *   - High score saved per difficulty
 *
 * @author Aether
 */

MM.Games = MM.Games || {};

MM.Games.MemoryMatrix = (function () {
  'use strict';

  const SYMBOLS = [
    '★', '♦', '♥', '♣', '♠', '●', '▲', '■', '♦', '♥', '♣', '♠',
    '★', '♦', '♥', '♣', '♠', '●', '▲', '■', '♦', '♥', '♣', '♠',
    '★', '♦', '♥', '♣', '♠', '●', '▲', '■', '♦', '♥', '♣', '♠',
    '★', '♦', '♥', '♣', '♠', '●', '▲', '■', '♦', '♥', '♣', '♠',
  ];

  const COLORS = ['#00f3ff', '#bc13fe', '#00ff9d', '#ffaa00', '#ff2a6d', '#ffffff'];

  const state = {
    grid: [],          // 2D array of cell objects
    size: 4,           // 4, 6, or 8
    pairs: 8,
    flipped: [],       // Currently flipped cells (max 2)
    matched: 0,
    moves: 0,
    time: 0,
    score: 0,
    active: false,
    locked: false,
    difficulty: 'medium',
  };

  function getDifficultyConfig(difficulty) {
    return {
      easy: { size: 4, pairs: 8 },
      medium: { size: 6, pairs: 18 },
      hard: { size: 8, pairs: 32 },
    }[difficulty] || { size: 6, pairs: 18 };
  }

  function generateGrid() {
    const cfg = getDifficultyConfig(state.difficulty);
    state.size = cfg.size;
    state.pairs = cfg.pairs;

    // Create pairs and shuffle
    const symbols = SYMBOLS.slice(0, cfg.pairs);
    const cells = [];
    for (let i = 0; i < cfg.pairs; i++) {
      cells.push({ symbol: symbols[i], color: COLORS[i % COLORS.length], matched: false, flipped: false });
      cells.push({ symbol: symbols[i], color: COLORS[i % COLORS.length], matched: false, flipped: false });
    }
    state.grid = MM.Engine.shuffle(cells);

    state.matched = 0;
    state.moves = 0;
    state.time = 0;
    state.flipped = [];
    state.locked = false;
    state.score = 0;
    state.active = true;

    renderGrid();
  }

  function renderGrid() {
    const container = document.getElementById('mm-games-container');
    if (!container) return;

    const gridEl = container.querySelector('.mm-memory-grid');
    if (!gridEl) return;

    gridEl.innerHTML = '';
    gridEl.style.gridTemplateColumns = `repeat(${state.size}, 1fr)`;
    gridEl.style.maxWidth = `${state.size * 70}px`;

    state.grid.forEach((cell, idx) => {
      const card = document.createElement('div');
      card.className = 'mm-memory-card';
      card.dataset.index = idx;
      card.dataset.symbol = cell.symbol;
      card.dataset.color = cell.color;

      card.style.cssText = `
        aspect-ratio: 1;
        perspective: 1000px;
        cursor: pointer;
        position: relative;
        transition: transform 0.4s var(--ease-circ);
      `;

      card.innerHTML = `
        <div class="mm-memory-inner" style="
          position: relative; width: 100%; height: 100%;
          transform-style: preserve-3d; transition: transform 0.6s var(--ease-circ);
        ">
          <div class="mm-memory-front" style="
            position: absolute; inset: 0; backface-visibility: hidden;
            border-radius: 8px; display: flex; align-items: center; justify-content: center;
            font-size: ${state.size === 4 ? '2.5rem' : state.size === 6 ? '1.8rem' : '1.2rem'};
            font-weight: 800; color: #000;
            background: linear-gradient(135deg, ${cell.color}80, ${cell.color}40);
            box-shadow: 0 4px 12px ${cell.color}40;
            border: 1px solid ${cell.color}80;
          ">${cell.symbol}</div>
          <div class="mm-memory-back" style="
            position: absolute; inset: 0; backface-visibility: hidden;
            background: linear-gradient(135deg, #0d121d, #0a0f17);
            border-radius: 8px; display: flex; align-items: center; justify-content: center;
            border: 1px solid var(--border-glass-light);
          ">
            <div style="font-size: 1.5rem; color: var(--text-muted);">?</div>
          </div>
        </div>
      `;

      card.addEventListener('click', () => flipCard(idx, card));
      gridEl.appendChild(card);
    });
  }

  function flipCard(idx, card) {
    if (!state.active || state.locked) return;

    const cell = state.grid[idx];
    if (cell.matched || cell.flipped) return;

    // Flip animation
    const inner = card.querySelector('.mm-memory-inner');
    inner.style.transform = 'rotateY(180deg)';
    cell.flipped = true;

    state.flipped.push({ idx, card, inner, cell });

    if (state.flipped.length === 2) {
      state.moves++;
      checkMatch();
    }
  }

  function checkMatch() {
    state.locked = true;

    const [c1, c2] = state.flipped;

    if (c1.cell.symbol === c2.cell.symbol) {
      // Match!
      setTimeout(() => {
        c1.card.style.background = `linear-gradient(135deg, ${c1.cell.color}, ${c2.cell.color})`;
        c1.card.style.borderColor = 'var(--neon-green)';
        c2.card.style.background = `linear-gradient(135deg, ${c1.cell.color}, ${c2.cell.color})`;
        c2.card.style.borderColor = 'var(--neon-green)';

        c1.cell.matched = c2.cell.matched = true;
        c1.cell.flipped = c2.cell.flipped = false;
        state.matched++;

        MM.Audio.correct();
        MM.Haptics.trigger('success');

        state.flipped = [];
        state.locked = false;

        if (state.matched === state.pairs) {
          setTimeout(() => endGame(), 500);
        }
      }, 500);
    } else {
      // No match - flip back
      setTimeout(() => {
        c1.inner.style.transform = 'rotateY(0deg)';
        c2.inner.style.transform = 'rotateY(0deg)';
        c1.cell.flipped = false;
        c2.cell.flipped = false;
        state.flipped = [];
        state.locked = false;
        MM.Audio.wrong();
        MM.Haptics.trigger('error');
      }, 800);
    }
  }

  function updateHUD() {
    const container = document.getElementById('mm-games-container');
    if (!container) return;

    const movesEl = container.querySelector('.mm-memory-moves');
    const timeEl = container.querySelector('.mm-memory-time');
    const scoreEl = container.querySelector('.mm-memory-score');
    const progressEl = container.querySelector('.mm-memory-progress');

    if (movesEl) movesEl.textContent = state.moves;
    if (timeEl) timeEl.textContent = MM.Engine.formatTime(state.time);
    if (scoreEl) scoreEl.textContent = MM.Engine.formatScore(state.score);
    if (progressEl) {
      const pct = Math.floor((state.matched / state.pairs) * 100);
      progressEl.style.width = `${pct}%`;
    }
  }

  function newGame() {
    state.difficulty = MM.Engine.difficulty;
    generateGrid();

    state.timerInterval = setInterval(() => {
      state.time++;
      updateHUD();
    }, 1000);

    MM.Audio.select();
  }

  function endGame() {
    state.active = false;
    clearInterval(state.timerInterval);

    // Score calculation: base points for moves + time bonus
    const base = Math.floor(state.pairs * 50 - state.moves * 2);
    const timeBonus = Math.max(0, (60 - state.time) * 5);
    state.score = Math.max(0, base + timeBonus);

    MM.Engine.state.session = {
      ...MM.Engine.state.session,
      score: state.score,
      duration: state.time,
      moves: state.moves,
    };

    MM.Engine.endSession(true);
  }

  function reset() {
    clearInterval(state.timerInterval);
    state.active = false;
    state.grid = [];
    state.flipped = [];
    state.locked = false;
    const container = document.getElementById('mm-games-container');
    if (container) {
      container.querySelector('.mm-memory-grid').innerHTML = '';
    }
  }

  const game = {
    init() {
      return MM.Audio.init().then(() => { reset(); });
    },
    start() { newGame(); },
    end() { endGame(); },
    score() { return state.score; },
    reset,
  };

  MM.Engine.register('memory_matrix', game);
  return game;
})();
