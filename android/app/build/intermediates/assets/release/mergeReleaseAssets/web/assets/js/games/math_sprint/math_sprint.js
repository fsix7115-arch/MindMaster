/**
 * =====================================================================
 * Math Sprint — Speed Math Game (Core Restored from v1.0.2)
 * =====================================================================
 *
 * Game rules:
 *   - 60 second timer per session
 *   - 20 questions per round, difficulty scales as score rises
 *   - 4 answer choices (one correct, three realistic distractors)
 *   - Streak bonus: +1 multiplier for every 3 consecutive correct answers
 *   - Score = correct answers × difficulty × streak
 *   - High score saved per difficulty (easy/medium/hard)
 *
 * Math operation generation (clean, integer results guaranteed):
 *   - Addition: a + b, a,b ∈ [1, 50]
 *   - Subtraction: a - b where a > b (no negatives)
 *   - Multiplication: a × b where a ∈ [2, 12], b ∈ [1, 12]
 *   - Division: a ÷ b where a is divisible by b, result ∈ [2, 20]
 *
 * Scoring formulas (matches v1.0.2 exactly for continuity):
 *   basePoints = 10 + Math.floor(score / 3)
 *   streakBonus = streak >= 3 ? streak : 1
 *   score += basePoints * streakBonus
 *   accuracy = correct / 20 (truncated to 2 decimals)
 *
 * @author Aether — Core restored & upgraded for 2040 aesthetic
 */

MM.Games = MM.Games || {};

MM.Games.MathSprint = (function () {
  'use strict';

  const OPS = [
    { symbol: '+', name: 'addition', min: 1, max: 50 },
    { symbol: '-', name: 'subtraction', min: 2, max: 40 },
    { symbol: '×', name: 'multiplication', min: 2, max: 12 },
    { symbol: '÷', name: 'division', min: 4, max: 20 },
  ];

  // ---- State ----
  const state = {
    score: 0,
    correct: 0,
    total: 0,
    streak: 0,
    timeLeft: 60,
    questions: [],
    current: null,
    timer: null,
    active: false,
    finished: false,
  };

  // ---- Question generation ----

  function generateQuestion(difficulty) {
    const opIndex = MM.Engine.getRandom(0, OPS.length - 1);
    const op = OPS[opIndex];

    let a, b, answer, display;

    switch (op.name) {
      case 'addition':
        a = MM.Engine.getRandom(op.min, op.max);
        b = MM.Engine.getRandom(op.min, op.max);
        answer = a + b;
        display = `${a} + ${b}`;
        break;

      case 'subtraction':
        a = MM.Engine.getRandom(op.min, op.max);
        b = MM.Engine.getRandom(op.min, a - 1);
        answer = a - b;
        display = `${a} - ${b}`;
        break;

      case 'multiplication':
        a = MM.Engine.getRandom(2, 12);
        b = MM.Engine.getRandom(1, 12);
        answer = a * b;
        display = `${a} × ${b}`;
        break;

      case 'division':
        b = MM.Engine.getRandom(op.min, op.max);
        answer = MM.Engine.getRandom(2, 20);
        a = b * answer;
        display = `${a} ÷ ${b}`;
        break;

      default:
        return generateQuestion(difficulty);
    }

    // Difficulty adjustment: add harder operations at higher difficulty
    if (difficulty === 'hard' && MM.Engine.getRandom(1, 100) <= 40) {
      // 40% chance of a two-digit operation
      a = MM.Engine.getRandom(10, 99);
      if (op.name === 'addition') {
        b = MM.Engine.getRandom(10, 99);
        answer = a + b;
      } else if (op.name === 'subtraction') {
        b = MM.Engine.getRandom(5, a - 5);
        answer = a - b;
      } else if (op.name === 'multiplication') {
        b = MM.Engine.getRandom(2, 15);
        answer = a * b;
      } else {
        answer = MM.Engine.getRandom(3, 15);
        b = MM.Engine.getRandom(2, 9);
        a = b * answer;
      }
      display = `${a} ${op.symbol} ${b}`;
    }

    // Generate distractors (wrong answers that look plausible)
    const distractors = new Set();
    distractors.add(answer);

    while (distractors.size < 4) {
      const variant = MM.Engine.getRandom(1, 5);
      let distractor;
      switch (variant) {
        case 1: distractor = answer + MM.Engine.getRandom(1, 5); break;
        case 2: distractor = answer - MM.Engine.getRandom(1, 5); break;
        case 3: distractor = answer + MM.Engine.getRandom(-8, 8); break;
        case 4: distractor = a + b; break; // common mistake (subtraction)
        case 5: distractor = Math.abs(a - b); break;
        default: distractor = answer + 1;
      }
      if (distractor >= 0 && distractor !== answer) {
        distractors.add(distractor);
      }
    }

    const options = MM.Engine.shuffle([...distractors]);

    return {
      display,
      answer,
      options,
      operation: op.name,
    };
  }

  // ---- Game loop ----

  function newQuestion() {
    state.current = generateQuestion();
    state.questions.push(state.current);
    state.total++;

    // Update UI
    const gameEl = MM.Engine.getContainer();
    if (!gameEl) return;

    const questionEl = gameEl.querySelector('.mm-question-text');
    const answersEl = gameEl.querySelector('.mm-answers-grid');
    const streakEl = gameEl.querySelector('.mm-streak-display');
    const progressEl = gameEl.querySelector('.mm-progress-text');

    if (questionEl) questionEl.textContent = state.current.display;

    if (answersEl) {
      answersEl.innerHTML = '';
      state.current.options.forEach((opt) => {
        const btn = document.createElement('button');
        btn.className = 'mm-answer-btn glass-card';
        btn.textContent = MM.Engine.formatScore(opt);
        btn.style.cssText = `
          padding: 16px 24px;
          font-size: 1.4rem;
          font-family: 'Orbitron', sans-serif;
          font-weight: 600;
          color: var(--text-primary);
          cursor: pointer;
          transition: all var(--ease-out-expo) 0.2s;
          user-select: none;
          border: 1px solid var(--border-glass);
        `;
        btn.addEventListener('click', () => handleAnswer(opt));
        answersEl.appendChild(btn);
      });
    }

    if (streakEl) {
      const stars = '★'.repeat(Math.min(state.streak, 5));
      streakEl.textContent = state.streak > 0 ? `STREAK ${stars}` : '';
    }

    if (progressEl) {
      progressEl.textContent = `QUESTION ${state.questions.length}/20`;
    }
  }

  function handleAnswer(selected) {
    if (!state.active || !state.current) return;

    const correct = selected === state.current.answer;
    state.total++;

    if (correct) {
      state.correct++;
      state.streak++;

      // Scoring formula (matches v1.0.2)
      const basePoints = 10 + Math.floor(state.score / 3);
      const streakBonus = state.streak >= 3 ? state.streak : 1;
      const points = basePoints * streakBonus;
      state.score += points;

      MM.Audio.correct();
      MM.Haptics.trigger('success');
      MM.Notifications.info('Correct!', `+${MM.Engine.formatScore(points)} XP`);
    } else {
      state.streak = 0;
      state.score = Math.max(0, state.score - 5);

      MM.Audio.wrong();
      MM.Haptics.trigger('error');
      MM.Notifications.error('Wrong', `Correct answer: ${MM.Engine.formatScore(state.current.answer)}`);
    }

    // Update score display
    const scoreEl = MM.Engine.getContainer()?.querySelector('.mm-score-display');
    if (scoreEl) scoreEl.textContent = MM.Engine.formatScore(state.score);

    if (state.total >= 20 || state.timeLeft <= 0) {
      endGame();
    } else {
      newQuestion();
    }
  }

  function endGame() {
    state.active = false;
    state.finished = true;

    clearInterval(state.timer);
    state.timer = null;

    // Show end screen
    const gameEl = MM.Engine.getContainer();
    if (!gameEl) return;

    const endScreen = gameEl.querySelector('.mm-end-screen');
    if (endScreen) endScreen.style.display = 'flex';

    const finalScoreEl = endScreen?.querySelector('.mm-final-score');
    const accuracyEl = endScreen?.querySelector('.mm-accuracy');
    const bestEl = endScreen?.querySelector('.mm-best-score');

    const accuracy = state.correct / state.total;

    if (finalScoreEl) finalScoreEl.textContent = MM.Engine.formatScore(state.score);
    if (accuracyEl) {
      accuracyEl.textContent = `ACCURACY ${(accuracy * 100).toFixed(0)}% (${state.correct}/${state.total})`;
      accuracyEl.style.color = accuracy >= 0.8 ? 'var(--neon-green)' : accuracy >= 0.5 ? 'var(--neon-amber)' : 'var(--neon-red)';
    }

    // Save high score (difficulty set by engine)
    MM.Engine.endSession(true).then(() => {
      // Session already saved via engine
    });

    MM.Audio.complete();
  }

  function reset() {
    clearInterval(state.timer);
    state.timer = null;
    state.score = 0;
    state.correct = 0;
    state.total = 0;
    state.streak = 0;
    state.timeLeft = 60;
    state.questions = [];
    state.current = null;
    state.active = false;
    state.finished = false;

    const gameEl = MM.Engine.getContainer();
    if (!gameEl) return;

    const startScreen = gameEl.querySelector('.mm-start-screen');
    const endScreen = gameEl.querySelector('.mm-end-screen');
    const gameArea = gameEl.querySelector('.mm-game-area');
    if (startScreen) startScreen.style.display = 'none';
    if (endScreen) endScreen.style.display = 'none';
    if (gameArea) gameArea.style.display = 'none';
  }

  // ---- Public API (matches engine interface) ----

  const game = {
    init() {
      return new Promise((resolve) => {
        MM.Audio.init().then(() => {
          reset();
          resolve();
        });
      });
    },

    start() {
      if (state.active) return;

      state.active = true;
      state.score = 0;
      state.correct = 0;
      state.total = 0;
      state.streak = 0;
      state.timeLeft = 60;

      const gameEl = MM.Engine.getContainer();
      if (!gameEl) return;

      const startScreen = gameEl.querySelector('.mm-start-screen');
      const gameArea = gameEl.querySelector('.mm-game-area');
      const endScreen = gameEl.querySelector('.mm-end-screen');
      if (startScreen) startScreen.style.display = 'none';
      if (gameArea) gameArea.style.display = 'block';
      if (endScreen) endScreen.style.display = 'none';

      newQuestion();
      MM.Audio.select();

      // Timer
      state.timer = setInterval(() => {
        state.timeLeft--;

        const timeEl = gameEl?.querySelector('.mm-timer-display');
        if (timeEl) {
          timeEl.textContent = MM.Engine.formatTime(state.timeLeft);
          timeEl.style.color = state.timeLeft <= 10 ? 'var(--neon-red)' : 'var(--neon-blue)';
        }

        if (state.timeLeft <= 0) {
          endGame();
        }
      }, 1000);

      // Update score display
      const scoreEl = gameEl?.querySelector('.mm-score-display');
      if (scoreEl) scoreEl.textContent = '0';
    },

    end() {
      endGame();
    },

    score() {
      return state.score;
    },

    getStats() {
      return {
        score: state.score,
        correct: state.correct,
        total: state.total,
        accuracy: state.total > 0 ? state.correct / state.total : 0,
        streak: state.streak,
        timeLeft: state.timeLeft,
      };
    },

    reset,
  };

  // Register with engine
  MM.Engine.register('math_sprint', game);

  return game;
})();