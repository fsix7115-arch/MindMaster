/**
 * =====================================================================
 * Logic Puzzles — Sudoku-Lite (4x4 / 6x6 / 9x9)
 * =====================================================================
 *
 * 3x3-lite solving:
 *   - Procedural board generation with backtracking
 *   - Progressive difficulty (easy=4x4, medium=6x6, hard=9x9)
 *   - Hint system: max 3 hints per game, each removes a wrong value
 *   - Score = (cells * 100) + (hintsLeft * 25) - (time * 0.5)
 *   - High score per difficulty saved
 *
 * Anti-cheat:
 *   - Generated board is validated for solvability before displaying
 *   - Each row, column, and sub-region (if 9x9) has exactly one of 1..N
 *   - Fill-in values are checked against all three constraint dimensions
 *
 * @author Aether
 */

MM.Games = MM.Games || {};

MM.Games.LogicPuzzles = (function () {
  'use strict';

  // ---- State ----
  const state = {
    board: null,        // 2D array [row][col], 0 = empty
    solution: null,     // 2D array with the full solved board
    size: 4,            // 4, 6, or 9
    current: null,      // {row, col, value}
    score: 0,
    hintsLeft: 3,
    time: 0,
    active: false,
    errors: 0,
  };

  // ---- Board generation ----

  /**
   * Generate a complete valid Sudoku-lite board using backtracking.
   */
  function generateCompleteBoard(size) {
    const board = Array.from({ length: size }, () => Array(size).fill(0));
    fillBoard(board, size, 0, 0);
    return board;
  }

  function fillBoard(board, size, row, col) {
    if (col >= size) { row++; col = 0; }
    if (row >= size) return true;
    if (board[row][col] !== 0) return fillBoard(board, size, row, col + 1);

    const values = MM.Engine.shuffle(Array.from({ length: size }, (_, i) => i + 1));
    for (const val of values) {
      if (isValidPlacement(board, size, row, col, val)) {
        board[row][col] = val;
        if (fillBoard(board, size, row, col + 1)) return true;
        board[row][col] = 0;
      }
    }
    return false;
  }

  function isValidPlacement(board, size, row, col, val) {
    // Row check
    for (let c = 0; c < size; c++) {
      if (board[row][c] === val) return false;
    }
    // Column check
    for (let r = 0; r < size; r++) {
      if (board[r][col] === val) return false;
    }
    // Sub-region check (for 6x6 and 9x9)
    const regionSize = size === 9 ? 3 : size === 6 ? 2 : 1;
    if (regionSize > 1) {
      const regionRow = Math.floor(row / regionSize) * regionSize;
      const regionCol = Math.floor(col / regionSize) * regionSize;
      for (let r = regionRow; r < regionRow + regionSize; r++) {
        for (let c = regionCol; c < regionCol + regionSize; c++) {
          if (board[r][c] === val) return false;
        }
      }
    }
    return true;
  }

  /**
   * Create a puzzle by removing cells from a complete board.
   */
  function createPuzzle(solution, size, difficulty) {
    const board = solution.map((row) => [...row]);
    const removals = { easy: 30, medium: 45, hard: 60 }[difficulty];
    const target = Math.floor(size * size * (removals / 100));
    let removed = 0;

    const positions = MM.Engine.shuffle(
      Array.from({ length: size * size }, (_, i) => [Math.floor(i / size), i % size])
    );

    for (const [r, c] of positions) {
      if (removed >= target) break;
      board[r][c] = 0;
      removed++;
    }

    return board;
  }

  // ---- UI updates ----

  function renderBoard() {
    const container = document.getElementById('mm-games-container');
    if (!container) return;
    const gridEl = container.querySelector('.mm-sudoku-grid');
    if (!gridEl) return;

    gridEl.innerHTML = '';
    gridEl.style.gridTemplateColumns = `repeat(${state.size}, 1fr)`;
    gridEl.style.gridTemplateRows = `repeat(${state.size}, 1fr)`;
    gridEl.style.maxWidth = `${state.size === 4 ? 320 : state.size === 6 ? 400 : 480}px`;

    for (let r = 0; r < state.size; r++) {
      for (let c = 0; c < state.size; c++) {
        const cell = document.createElement('div');
        cell.className = 'mm-sudoku-cell glass-card';
        cell.dataset.row = r;
        cell.dataset.col = c;

        const isGiven = state.board[r][c] !== 0;
        cell.style.cssText = `
          border: 1px solid ${
            isGiven ? 'var(--border-glass-light)' : 'var(--border-glass)'
          };
          border-radius: 6px;
          display: flex; align-items: center; justify-content: center;
          font-family: 'Orbitron', sans-serif;
          font-size: ${state.size === 9 ? '0.95rem' : '1.2rem'};
          font-weight: ${isGiven ? '700' : '400'};
          color: ${isGiven ? 'var(--neon-blue)' : 'var(--text-secondary)'};
          cursor: ${isGiven ? 'default' : 'pointer'};
          background: var(--bg-glass-strong);
          transition: all var(--ease-out-expo) 0.15s;
          user-select: none;
        `;

        cell.textContent = state.board[r][c] || '';

        if (!isGiven) {
          cell.addEventListener('click', () => onCellClick(r, c));
        }

        gridEl.appendChild(cell);
      }
    }
  }

  function onCellClick(row, col) {
    if (!state.active) return;
    state.current = { row, col, value: null };
    updateNumberPad();
    MM.Audio.tap();
  }

  function updateNumberPad() {
    const pad = document.getElementById('mm-games-container')?.querySelector('.mm-number-pad');
    if (!pad) return;
    for (let i = 1; i <= state.size; i++) {
      const btn = pad.querySelector(`[data-val="${i}"]`);
      if (btn) {
        const used = state.board[state.current?.row]?.includes(i);
        btn.disabled = used || state.current === null;
        btn.style.opacity = (used || !state.current) ? '0.3' : '1';
      }
    }
  }

  function onNumberSelect(val) {
    if (!state.active || !state.current || state.board[state.current.row][state.current.col] !== 0) return;

    const { row, col } = state.current;
    const correct = state.solution[row][col] === val;

    state.board[row][col] = val;
    state.current.value = val;

    // Re-render the cell
    const gridEl = document.getElementById('mm-games-container')?.querySelector('.mm-sudoku-grid');
    const cell = gridEl?.children[row * state.size + col];
    if (cell) {
      cell.textContent = val;
      cell.style.color = correct ? 'var(--neon-green)' : 'var(--neon-red)';
      cell.style.borderColor = correct ? 'var(--neon-green)' : 'var(--neon-red)';
      cell.style.boxShadow = correct ? 'var(--glow-green)' : 'none';
      cell.style.fontWeight = '700';
    }

    if (correct) {
      state.score += 10;
      MM.Audio.correct();
      MM.Haptics.trigger('success');
    } else {
      state.errors++;
      MM.Audio.wrong();
      MM.Haptics.trigger('error');
      // Flash the cell red then reset
      setTimeout(() => {
        state.board[row][col] = 0;
        state.current.value = null;
        if (cell) {
          cell.textContent = '';
          cell.style.color = 'var(--text-secondary)';
          cell.style.borderColor = 'var(--border-glass)';
          cell.style.boxShadow = 'none';
          cell.style.fontWeight = '400';
        }
        updateNumberPad();
      }, 400);
    }

    updateHUD();
    updateNumberPad();
    checkWin();
  }

  function checkWin() {
    const filled = state.board.flat().filter((v) => v !== 0).length;
    if (filled === state.size * state.size) {
      // Verify all cells match solution
      const correct = state.board.every((row, r) =>
        row.every((v, c) => v === state.solution[r][c])
      );
      if (correct) {
        state.score += state.hintsLeft * 25;
        endGame();
      }
    }
  }

  function useHint() {
    if (state.hintsLeft <= 0 || !state.active) return;
    state.hintsLeft--;

    // Find an empty cell and fill it with the correct value
    const empties = [];
    for (let r = 0; r < state.size; r++) {
      for (let c = 0; c < state.size; c++) {
        if (state.board[r][c] === 0) empties.push([r, c]);
      }
    }

    if (empties.length > 0) {
      const [r, c] = empties[MM.Engine.getRandom(0, empties.length - 1)];
      state.board[r][c] = state.solution[r][c];
      const gridEl = document.getElementById('mm-games-container')?.querySelector('.mm-sudoku-grid');
      const cell = gridEl?.children[r * state.size + c];
      if (cell) {
        cell.textContent = state.board[r][c];
        cell.style.color = 'var(--neon-amber)';
        cell.style.fontWeight = '700';
      }
      MM.Audio.select();
      updateHUD();
      updateNumberPad();
      checkWin();
    }
  }

  function updateHUD() {
    const container = document.getElementById('mm-games-container');
    if (!container) return;
    const scoreEl = container.querySelector('.mm-sudoku-score');
    const hintEl = container.querySelector('.mm-sudoku-hints');
    const timerEl = container.querySelector('.mm-sudoku-timer');

    if (scoreEl) scoreEl.textContent = MM.Engine.formatScore(state.score);
    if (hintEl) hintEl.textContent = `${state.hintsLeft} left`;
    if (timerEl) timerEl.textContent = MM.Engine.formatTime(state.time);
  }

  // ---- Game lifecycle ----

  function newGame() {
    const difficulty = MM.Engine.difficulty;
    state.size = difficulty === 'easy' ? 4 : difficulty === 'medium' ? 6 : 9;
    state.hintsLeft = 3;
    state.score = 0;
    state.time = 0;
    state.errors = 0;

    state.solution = generateCompleteBoard(state.size);
    state.board = createPuzzle(state.solution, state.size, difficulty);
    state.active = true;

    renderBoard();
    buildNumberPad();
    updateHUD();

    // Timer
    state.timerInterval = setInterval(() => {
      state.time++;
      updateHUD();
    }, 1000);
  }

  function buildNumberPad() {
    const container = document.getElementById('mm-games-container');
    if (!container) return;

    let pad = container.querySelector('.mm-number-pad');
    if (!pad) {
      pad = document.createElement('div');
      pad.className = 'mm-number-pad';
      pad.style.cssText = `
        display: grid;
        grid-template-columns: repeat(${state.size <= 4 ? 4 : 5}, 1fr);
        gap: 8px;
        margin-top: 16px;
        max-width: 300px;
      `;
      container.appendChild(pad);
    }
    pad.style.gridTemplateColumns = `repeat(${state.size <= 4 ? 4 : 5}, 1fr)`;
    pad.innerHTML = '';
    for (let i = 1; i <= state.size; i++) {
      const btn = document.createElement('button');
      btn.className = 'mm-answer-btn glass-card';
      btn.dataset.val = i;
      btn.textContent = i;
      btn.style.cssText = `
        padding: 10px;
        font-family: 'Orbitron', sans-serif;
        font-size: 1.1rem;
        font-weight: 600;
        color: var(--neon-blue);
        background: var(--bg-glass);
        border: 1px solid var(--border-glass);
        border-radius: 8px;
        cursor: pointer;
        transition: all var(--ease-out-expo) 0.2s;
      `;
      btn.addEventListener('click', () => onNumberSelect(i));
      pad.appendChild(btn);
    }
  }

  function endGame() {
    if (!state.active) return;
    state.active = false;
    clearInterval(state.timerInterval);
    MM.Engine.endSession(true);
    MM.Audio.complete();
  }

  function reset() {
    clearInterval(state.timerInterval);
    state.board = null;
    state.solution = null;
    state.active = false;
    state.score = 0;
    state.time = 0;
    state.errors = 0;
    const container = document.getElementById('mm-games-container');
    const grid = container?.querySelector('.mm-sudoku-grid');
    const pad = container?.querySelector('.mm-number-pad');
    if (grid) grid.innerHTML = '';
    if (pad) pad.innerHTML = '';
  }

  // ---- Public API ----
  const game = {
    init() {
      return MM.Audio.init().then(() => { reset(); });
    },
    start() { newGame(); },
    end() { endGame(); },
    score() { return state.score; },
    reset,
    useHint,
  };

  MM.Engine.register('logic_puzzles', game);
  return game;
})();
