/**
 * =====================================================================
 * Color Match — Stroop Test Game
 * =====================================================================
 *
 * Rules:
 *   - Word displays a color name, but text is a DIFFERENT color
 *   - Tap the ACTUAL color of the text (not the word meaning)
 *   - 60 second timer, difficulty scales speed
 *   - Score = correct × difficulty multiplier
 *   - Easy: 4 choices, 2s per round
 *   - Medium: 6 choices, 1.5s per round
 *   - Hard: 8 choices, 1s per round
 *
 * Psychology: Tests cognitive control vs. automatic reading
 *
 * @author Aether
 */

MM.Games = MM.Games || {};

MM.Games.ColorMatch = (function () {
  'use strict';

  const COLORS = ['red', 'blue', 'green', 'yellow', 'purple', 'orange', 'pink', 'cyan'];
  const COLOR_MAP = {
    red: '#ff2a6d', blue: '#00f3ff', green: '#00ff9d', yellow: '#ffaa00',
    purple: '#bc13fe', orange: '#ff8800', pink: '#ff69b4', cyan: '#00ffff'
  };

  const state = {
    score: 0,
    correct: 0,
    total: 0,
    time: 60,
    active: false,
    current: null,
    difficulty: 'medium',
    numChoices: 6,
    roundTime: 1.5,
  };

  function getDifficultyConfig(difficulty) {
    return {
      easy: { numChoices: 4, roundTime: 2.0, multiplier: 1 },
      medium: { numChoices: 6, roundTime: 1.5, multiplier: 1.5 },
      hard: { numChoices: 8, roundTime: 1.0, multiplier: 2.2 },
    }[difficulty] || { numChoices: 6, roundTime: 1.5, multiplier: 1.5 };
  }

  function generateRound() {
    const cfg = getDifficultyConfig(state.difficulty);
    state.numChoices = cfg.numChoices;
    state.roundTime = cfg.roundTime;

    // Pick a random color for the TEXT
    const textColorName = COLORS[Math.floor(Math.random() * COLORS.length)];
    const textColor = COLOR_MAP[textColorName];

    // Pick a different color for the WORD meaning
    let wordColorName;
    do {
      wordColorName = COLORS[Math.floor(Math.random() * COLORS.length)];
    } while (wordColorName === textColorName);

    // Generate choices (including correct answer)
    const choices = new Set([textColorName]);
    while (choices.size < state.numChoices) {
      choices.add(COLORS[Math.floor(Math.random() * COLORS.length)]);
    }

    state.current = {
      wordColorName,
      textColorName,
      textColor,
      choices: MM.Engine.shuffle([...choices]),
      answered: false,
    };

    renderRound();
  }

  function renderRound() {
    const container = document.getElementById('mm-games-container');
    if (!container) return;

    const wordEl = container.querySelector('.mm-color-word');
    const choicesEl = container.querySelector('.mm-color-choices');

    if (!wordEl || !choicesEl) return;

    // Display the word in the wrong color
    wordEl.textContent = state.current.wordColorName.toUpperCase();
    wordEl.style.color = state.current.textColor;
    wordEl.style.fontSize = '3rem';
    wordEl.style.fontWeight = '800';
    wordEl.style.textShadow = `0 0 20px ${state.current.textColor}`;
    wordEl.style.fontFamily = "'Orbitron', sans-serif";
    wordEl.style.letterSpacing = '0.1em';

    choicesEl.innerHTML = '';
    const cfg = getDifficultyConfig(state.difficulty);

    state.current.choices.forEach((colorName, idx) => {
      const btn = document.createElement('button');
      btn.className = 'mm-color-choice glass-card';
      btn.style.cssText = `
        width: 70px; height: 70px;
        border-radius: 50%;
        background: ${COLOR_MAP[colorName]};
        border: 2px solid transparent;
        cursor: pointer;
        transition: all var(--ease-out-expo) 0.2s;
        box-shadow: 0 4px 16px ${COLOR_MAP[colorName]}40;
        display: flex; align-items: center; justify-content: center;
        font-weight: 700;
        color: #000;
        font-size: 0.8rem;
        text-transform: uppercase;
      `;
      btn.addEventListener('click', () => handleChoice(colorName));
      btn.addEventListener('mouseenter', () => {
        btn.style.transform = 'scale(1.1)';
        btn.style.boxShadow = `0 8px 24px ${COLOR_MAP[colorName]}60`;
      });
      btn.addEventListener('mouseleave', () => {
        btn.style.transform = 'scale(1)';
        btn.style.boxShadow = `0 4px 16px ${COLOR_MAP[colorName]}40`;
      });
      choicesEl.appendChild(btn);
    });
  }

  function handleChoice(colorName) {
    if (!state.active || state.current.answered) return;

    state.current.answered = true;
    state.total++;

    const correct = colorName === state.current.textColorName;

    if (correct) {
      state.correct++;
      const cfg = getDifficultyConfig(state.difficulty);
      const points = Math.floor((state.current.roundTime * 100) * cfg.multiplier);
      state.score += points;
      MM.Audio.correct();
      MM.Haptics.trigger('success');
    } else {
      MM.Audio.wrong();
      MM.Haptics.trigger('error');
    }

    updateHUD();

    setTimeout(() => {
      if (state.active && state.time > 0) {
        generateRound();
      }
    }, 600);
  }

  function updateHUD() {
    const container = document.getElementById('mm-games-container');
    if (!container) return;
    const scoreEl = container.querySelector('.mm-score-display');
    const accuracyEl = container.querySelector('.mm-accuracy-display');
    if (scoreEl) scoreEl.textContent = MM.Engine.formatScore(state.score);
    if (accuracyEl) {
      const acc = state.total > 0 ? (state.correct / state.total * 100).toFixed(0) : '0';
      accuracyEl.textContent = `${acc}%`;
    }
  }

  function newGame() {
    state.difficulty = MM.Engine.difficulty;
    state.score = 0;
    state.correct = 0;
    state.total = 0;
    state.time = 60;
    state.active = true;

    generateRound();

    state.timerInterval = setInterval(() => {
      state.time--;
      const timeEl = document.getElementById('mm-games-container')?.querySelector('.mm-timer-display');
      if (timeEl) timeEl.textContent = MM.Engine.formatTime(state.time);
      if (state.time <= 0) endGame();
    }, 1000);
  }

  function endGame() {
    state.active = false;
    clearInterval(state.timerInterval);
    MM.Engine.endSession(true);
    MM.Audio.complete();
  }

  function reset() {
    clearInterval(state.timerInterval);
    state.active = false;
    const container = document.getElementById('mm-games-container');
    if (container) {
      container.querySelector('.mm-color-word').textContent = '';
      container.querySelector('.mm-color-choices').innerHTML = '';
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

  MM.Engine.register('color_match', game);
  return game;
})();
