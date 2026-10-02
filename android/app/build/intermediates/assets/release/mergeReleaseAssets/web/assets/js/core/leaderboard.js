/**
 * MindMaster — Global Leaderboard
 * Version: 1.1.0
 *
 * Reads all sessions from MM.Storage and renders per-game and
 * overall leaderboards. Data is local (IndexedDB) — no network,
 * no tracking. "Global" = across all six games in this app.
 */

MM.Leaderboard = (function () {
  'use strict';

  const GAME_META = {
    math_sprint:    { name: 'Math Sprint',    icon: '🔢', url: 'math-sprint.html' },
    logic_puzzles:  { name: 'Logic Puzzles',  icon: '🧩', url: 'logic-puzzles.html' },
    color_match:    { name: 'Color Match',    icon: '🎨', url: 'color-match.html' },
    focus_grid:     { name: 'Focus Grid',     icon: '🎯', url: 'focus-grid.html' },
    memory_matrix:  { name: 'Memory Matrix',  icon: '🧠', url: 'memory-matrix.html' },
    pattern_recall: { name: 'Pattern Recall', icon: '💫', url: 'pattern-recall.html' },
  };

  /** Fetch sessions, grouped by game. Returns { perGame: {gameId: [sessions]}, all: [...] } */
  async function collect() {
    const sessions = (await MM.Storage.getters.getAll('gameSessions')) || [];
    const perGame = {};
    for (const s of sessions) {
      if (!s || !s.game) continue;
      (perGame[s.game] = perGame[s.game] || []).push(s);
    }
    for (const k of Object.keys(perGame)) {
      perGame[k].sort((a, b) => (b.score || 0) - (a.score || 0));
    }
    const all = sessions
      .filter((s) => s && typeof s.score === 'number')
      .sort((a, b) => b.score - a.score);
    return { perGame, all };
  }

  function fmtDate(ts) {
    if (!ts) return '—';
    try {
      return new Date(ts).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
    } catch { return '—'; }
  }

  function gameRow(gameId, sessions) {
    const meta = GAME_META[gameId] || { name: gameId, icon: '🎮', url: '#' };
    const best = sessions[0];
    const plays = sessions.length;
    const total = sessions.reduce((sum, s) => sum + (s.score || 0), 0);
    const last = sessions[sessions.length - 1];
    return `
      <a href="${meta.url}" class="leaderboard-row" style="text-decoration:none; color:inherit;">
        <div class="glass-panel" style="display:grid; grid-template-columns:auto 1fr auto; gap:16px; align-items:center; padding:16px 20px; border-radius:14px;">
          <div style="font-size:2rem;">${meta.icon}</div>
          <div>
            <div style="font-family:'Orbitron',sans-serif; font-weight:700; font-size:1.05rem;">${meta.name}</div>
            <div style="color:var(--text-muted); font-size:0.85rem; margin-top:4px;">
              ${plays} session${plays === 1 ? '' : 's'} · last played ${fmtDate(last && last.timestamp)}
            </div>
          </div>
          <div style="text-align:right;">
            <div class="text-gradient" style="font-family:'Orbitron',sans-serif; font-weight:800; font-size:1.4rem;">
              ${best ? best.score.toLocaleString() : '0'}
            </div>
            <div style="color:var(--text-muted); font-size:0.8rem;">best · ${total.toLocaleString()} total</div>
          </div>
        </div>
      </a>`;
  }

  function overallRow(rank, s, i) {
    const meta = GAME_META[s.game] || { name: s.game, icon: '🎮' };
    const medals = ['🥇', '🥈', '🥉'];
    const medal = rank <= 3 ? medals[rank - 1] : `<span style="color:var(--text-muted)">#${rank}</span>`;
    return `
      <div class="glass-panel" style="display:grid; grid-template-columns:auto auto 1fr auto; gap:14px; align-items:center; padding:12px 20px; border-radius:14px;">
        <div style="width:44px; text-align:center; font-size:1.15rem;">${medal}</div>
        <div style="font-size:1.6rem;">${meta.icon}</div>
        <div>
          <div style="font-weight:600;">${meta.name}</div>
          <div style="color:var(--text-muted); font-size:0.8rem;">
            ${(s.difficulty || 'medium').toUpperCase()} · ${fmtDate(s.timestamp)}
          </div>
        </div>
        <div class="text-gradient" style="font-family:'Orbitron',sans-serif; font-weight:800; font-size:1.2rem;">
          ${(s.score || 0).toLocaleString()}
        </div>
      </div>`;
  }

  /** Render the full leaderboard into #leaderboard-content (or create it). */
  async function render() {
    let host = document.getElementById('leaderboard-content');
    if (!host) {
      host = document.createElement('div');
      host.id = 'leaderboard-content';
      const landing = document.querySelector('.games-grid');
      if (landing && landing.parentNode) landing.parentNode.insertBefore(host, landing);
      else document.body.appendChild(host);
    }

    const { perGame, all } = await collect();

    const gameIds = Object.keys(GAME_META).filter((id) => perGame[id]);
    const totalPlays = all.length;
    const totalScore = all.reduce((sum, s) => sum + (s.score || 0), 0);
    const gamesPlayed = gameIds.length;

    host.innerHTML = `
      <div style="max-width:1000px; margin:24px auto; padding:0 20px;">
        <h2 style="font-family:'Orbitron',sans-serif; text-align:center; margin-bottom:8px;" class="text-gradient">
          LEADERBOARD
        </h2>
        <div class="stats-bar glass-panel" style="gap:28px; border-radius:14px;">
          <div class="stat-item"><span class="stat-value text-gradient-green">${totalPlays}</span><br><span class="stat-label">Sessions</span></div>
          <div class="stat-item"><span class="stat-value text-gradient-purple">${gamesPlayed}<span style="font-size:1rem;">/6</span></span><br><span class="stat-label">Games Played</span></div>
          <div class="stat-item"><span class="stat-value text-gradient">${totalScore.toLocaleString()}</span><br><span class="stat-label">Total Score</span></div>
        </div>

        <h3 style="font-family:'Orbitron',sans-serif; margin:36px 0 16px; font-size:1.1rem;">PER GAME</h3>
        <div style="display:flex; flex-direction:column; gap:12px;">
          ${gameIds.length ? gameIds.map((id) => gameRow(id, perGame[id])).join('')
            : `<p style="text-align:center; color:var(--text-muted); padding:24px;">No sessions yet — play a game to light up the board.</p>`}
        </div>

        ${all.length ? `
        <h3 style="font-family:'Orbitron',sans-serif; margin:36px 0 16px; font-size:1.1rem;">TOP SCORES — ALL GAMES</h3>
        <div style="display:flex; flex-direction:column; gap:10px;">
          ${all.slice(0, 10).map((s, i) => overallRow(i + 1, s, i)).join('')}
        </div>` : ''}
      </div>`;

    // Re-enable tilt on the new panels
    host.querySelectorAll('.glass-panel').forEach((card) => {
      card.addEventListener('mouseenter', () => {
        if (MM?.Mouse?.trackElement) MM.Mouse.trackElement(card, { depth: 6, tilt: 4 });
      });
    });

    return host;
  }

  return { render, collect, GAME_META };
})();
