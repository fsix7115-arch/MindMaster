/**
 * =====================================================================
 * MindMaster — Game Engine Core
 * =====================================================================
 *
 * PURPOSE
 *   Central game manager that coordinates all games. Handles:
 *   - Game registration & lifecycle
 *   - Session tracking & scoring
 *   - Difficulty configuration
 *   - Win/loss state management
 *   - XP & achievement propagation
 *
 * DESIGN
 *   - Each game registers itself and implements a standard interface
 *   - Engine is agnostic to game mechanics
 *   - Full session recording to storage
 *   - Achievement system integration
 *
 * GAME INTERFACE (must be implemented by each game)
 *   init()        — set up the game board/state
 *   start()       — begin the game session
 *   end(win)      — end session, report score
 *   score()       — current score
 *   reset()       — reset to initial state
 *
 * @author Aether
 */

MM.Engine = (function () {
  'use strict';

  const STATE = {
    games: {},
    currentGame: null,
    session: null,
    difficulty: 'medium',
    mode: 'classic',
    paused: false,
    loading: false,
  };

  const DIFFICULTY_SETTINGS = {
    easy: { multiplier: 1.0, timeBonus: 0, penalty: 0, label: 'EASY' },
    medium: { multiplier: 1.5, timeBonus: 0.3, penalty: 0, label: 'MEDIUM' },
    hard: { multiplier: 2.2, timeBonus: 0.6, penalty: 0.5, label: 'HARD' },
  };

  // ---- Registration ----

  const register = (name, game) => {
    if (STATE.games[name]) {
      console.warn(`Game "${name}" already registered`);
    }
    STATE.games[name] = game;
    return game;
  };

  const getGame = (name) => STATE.games[name];

  const listGames = () => Object.keys(STATE.games);

  // ---- Session management ----

  const startSession = async (gameName, difficulty = null) => {
    const game = getGame(gameName);
    if (!game) {
      MM.Notifications.error('Game Not Found', `Game "${gameName}" is not available.`);
      return null;
    }

    if (STATE.currentGame) {
      await STATE.currentGame.reset();
    }

    STATE.difficulty = difficulty || STATE.difficulty;
    STATE.paused = false;

    const session = {
      id: crypto.randomUUID(),
      game: gameName,
      difficulty: STATE.difficulty,
      mode: STATE.mode,
      startedAt: new Date().toISOString(),
      score: 0,
      steps: 0,
      errors: 0,
      completed: false,
      xpEarned: 0,
      duration: 0,
      details: {},
    };

    STATE.session = session;
    STATE.currentGame = game;

    await game.init();
    await game.start();

    // Start session timer
    session.timerInterval = setInterval(() => {
      session.duration = Math.floor(
        (Date.now() - new Date(session.startedAt).getTime()) / 1000
      );
    }, 1000);

    return session;
  };

  const pauseSession = () => {
    STATE.paused = true;
    if (STATE.session?.timerInterval) {
      clearInterval(STATE.session.timerInterval);
    }
  };

  const resumeSession = async () => {
    STATE.paused = false;
    const session = STATE.session;
    session.startedAt = new Date(Date.now() - session.duration * 1000).toISOString();
    session.timerInterval = setInterval(() => {
      session.duration = Math.floor(
        (Date.now() - new Date(session.startedAt).getTime()) / 1000
      );
    }, 1000);
  };

  const endSession = async (win) => {
    const session = STATE.session;
    const game = STATE.currentGame;

    if (session.timerInterval) {
      clearInterval(session.timerInterval);
    }

    session.completed = true;
    session.endScore = game?.score?.() ?? 0;
    session.won = win;
    session.endedAt = new Date().toISOString();

    const difficulty = DIFFICULTY_SETTINGS[session.difficulty];
    let score = session.endScore;

    // Apply difficulty multiplier & time bonus
    if (difficulty.multiplier !== 1) {
      score = Math.floor(score * difficulty.multiplier);
    }
    if (difficulty.timeBonus > 0 && session.duration > 0) {
      const timeBonus = Math.floor((60 - session.duration) * difficulty.timeBonus);
      score += Math.max(0, timeBonus);
    }

    // Penalty for errors (hard mode)
    let xpEarned = Math.floor(score / 10) + 1;
    if (difficulty.penalty > 0 && session.errors > 0) {
      score = Math.floor(score * (1 - difficulty.penalty * session.errors * 0.05));
      score = Math.max(0, score);
      xpEarned = Math.floor(xpEarned * 0.8);
    }

    session.score = Math.floor(score);
    session.xpEarned = xpEarned;

    // Save to storage
    try {
      await MM.Storage.saveHighScore(
        session.game,
        session.difficulty,
        session.score,
        {
          steps: session.steps,
          errors: session.errors,
          accuracy: session.steps > 0
            ? Math.max(0, 1 - session.errors / session.steps)
            : null,
          duration: session.duration,
          streakBonus: session.details.streakBonus || 0,
        }
      );

      await MM.Storage.recordSession({
        ...session,
        completed: win,
      });

      if (win) {
        await MM.Storage.unlockAchievement(`first_${session.game}_${session.difficulty}`);
        MM.Audio.achievement();
      }
    } catch (err) {
      console.error('Failed to save session:', err);
      MM.Notifications.warning('Save Failed', 'Session data could not be saved locally.');
    }

    // Trigger achievements
    if (win) {
      await checkGameAchievements(session);
    }

    // Cleanup
    if (game) await game.reset();
    STATE.session = null;
    STATE.currentGame = null;

    return { session, win };
  };

  // ---- Achievements ----

  const ACHIEVEMENTS = {
    first_play: { id: 'first_play', title: 'First Steps', desc: 'Complete your first game' },
    easy_master: { id: 'easy_master', title: 'Easy Peasy', desc: 'Score 1000+ on easy' },
    medium_champ: { id: 'medium_champ', title: 'Middle Ground', desc: 'Score 2500+ on medium' },
    hard_king: { id: 'hard_king', title: 'Difficulty King', desc: 'Score 5000+ on hard' },
    perfect: { id: 'perfect', title: 'Flawless', desc: 'Complete a game with no errors' },
    streak_3: { id: 'streak_3', title: 'On a Roll', desc: 'Play 3 games in a row' },
    streak_7: { id: 'streak_7', title: 'Unstoppable', desc: 'Play 7 games in a row' },
  };

  const checkGameAchievements = async (session) => {
    const { game, difficulty, score, errors, steps } = session;
    const unlock = async (key) => {
      if (ACHIEVEMENTS[key]) {
        await MM.Storage.unlockAchievement(ACHIEVEMENTS[key].id);
      }
    };

    if (score >= 1000) await unlock('easy_master');
    if (difficulty === 'medium' && score >= 2500) await unlock('medium_champ');
    if (difficulty === 'hard' && score >= 5000) await unlock('hard_king');
    if (errors === 0 && steps > 0) await unlock('perfect');
  };

  const getAchievementsList = () => Object.values(ACHIEVEMENTS);

  // ---- Utility ----

  const formatTime = (seconds) => {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  const formatScore = (score) => {
    return score.toLocaleString();
  };

  const getRandom = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;

  const shuffle = (array) => {
    const arr = [...array];
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
  };

  return {
    register,
    getGame,
    listGames,
    startSession,
    pauseSession,
    resumeSession,
    endSession,
    get state() { return { ...STATE }; },
    get currentGame() { return STATE.currentGame; },
    get difficulty() { return STATE.difficulty; },
    setDifficulty(d) { STATE.difficulty = d; },
    getDifficultySettings() { return { ...DIFFICULTY_SETTINGS }; },
    formatTime,
    formatScore,
    getRandom,
    shuffle,
    getAchievementsList,
  };
})();