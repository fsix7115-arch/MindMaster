/**
 * =====================================================================
 * MindMaster — Shared Game UI Components
 * =====================================================================
 *
 * Reusable high-quality components for all games:
 *   - GameCard        — game selector card on home screen
 *   - DifficultyToggle — easy/medium/hard selector
 *   - StatsPanel      — score/time/accuracy HUD
 *   - Modal           — overlay dialogs (end game, settings)
 *   - ProgressBar     — energy/life timer
 *   - NumberGrid      — 3x3 to 6x6 interactive grid
 *   - RippleButton    — animated button
 *
 * All components support mouse-reactive tilt + haptic feedback.
 *
 * @author Aether
 */

MM.UI = (function () {
  'use strict';

  const NS = 'mm-';

  // ---- Game Card ----
  class GameCard {
    constructor({ title, subtitle, icon, color, onClick, selected }) {
      this.title = title;
      this.subtitle = subtitle;
      this.icon = icon;
      this.color = color;
      this.onClick = onClick;
      this.selected = selected ?? false;

      this.element = this.render();
    }

    render() {
      const el = document.createElement('div');
      el.className = `${NS}game-card glass-card ${this.selected ? 'selected' : ''}`;
      el.style.cursor = 'pointer';
      el.style.padding = '20px';
      el.style.height = '200px';
      el.style.display = 'flex';
      el.style.flexDirection = 'column';
      el.style.justifyContent = 'center';
      el.style.alignItems = 'center';
      el.style.textAlign = 'center';
      el.style.transition = 'all var(--ease-out-expo) 0.3s';

      // Mouse tilt effect via global tracker
      if (window.MM && MM.Mouse) {
        MM.Mouse.trackElement(el, { depth: 12, tilt: 8 });
      }

      el.innerHTML = `
        <div class="${NS}card-icon" style="
          width: 64px; height: 64px; border-radius: 16px;
          background: linear-gradient(135deg, ${this.color}, ${this.adjustColor(this.color, -30)});
          display: flex; align-items: center; justify-content: center;
          font-size: 28px; margin-bottom: 14px;
          box-shadow: 0 8px 24px ${this.color}40;
          transition: transform var(--ease-out-expo) 0.3s;
        ">
          ${this.icon}
        </div>
        <h3 class="${NS}card-title" style="
          font-family: 'Orbitron', sans-serif;
          font-size: 1.3rem; font-weight: 700;
          color: var(--text-primary); margin-bottom: 6px;
        ">${this.title}</h3>
        <p class="${NS}card-subtitle" style="
          font-family: 'Rajdhani', sans-serif;
          font-size: 0.9rem; color: var(--text-secondary);
          line-height: 1.4;
        ">${this.subtitle}</p>
        ${this.selected ? `
          <div class="${NS}card-badge" style="
            margin-top: 12px; padding: 4px 12px;
            background: linear-gradient(135deg, ${this.color}, ${this.adjustColor(this.color, -20)});
            color: var(--text-inverted);
            border-radius: 20px;
            font-size: 0.75rem; font-weight: 700;
            letter-spacing: 0.05em; text-transform: uppercase;
          ">${this.selectedLabel || 'SELECTED'}</div>
        ` : ''}
      `;

      el.addEventListener('mouseenter', () => this.hover());
      el.addEventListener('mouseleave', () => this.leave());
      el.addEventListener('click', () => this.click());
      el.addEventListener('touchstart', () => this.hover(), { passive: true });

      return el;
    }

    adjustColor(hex, amount) {
      const num = parseInt(hex.slice(1), 16);
      const r = Math.max(0, Math.min(255, (num >> 16) + amount));
      const g = Math.max(0, Math.min(255, ((num >> 8) & 0xff) + amount));
      const b = Math.max(0, Math.min(255, (num & 0xff) + amount));
      return `#${(r << 16 | g << 8 | b).toString(16).padStart(6, '0')}`;
    }

    hover() {
      this.element.style.transform = 'translateY(-6px) scale(1.03)';
      MM.Audio.hover();
    }

    leave() {
      this.element.style.transform = 'translateY(0) scale(1)';
    }

    click() {
      this.element.classList.add('selected');
      MM.Audio.select();
      MM.Haptics.trigger('selection');
      if (this.onClick) this.onClick(this);
    }

    setSelected(selected) {
      this.selected = selected;
      if (selected) this.element.classList.add('selected');
      else this.element.classList.remove('selected');
    }
  }

  // ---- Difficulty Toggle ----
  class DifficultyToggle {
    constructor(onChange) {
      this.selected = 'medium';
      this.onChange = onChange;
      this.element = this.render();
    }

    render() {
      const modes = [
        { key: 'easy', label: 'EASY', icon: '🌱', color: 'var(--neon-green)' },
        { key: 'medium', label: 'MEDIUM', icon: '⚡', color: 'var(--neon-amber)' },
        { key: 'hard', label: 'HARD', icon: '🔥', color: 'var(--neon-red)' },
      ];

      const el = document.createElement('div');
      el.className = `${NS}difficulty-toggle`;
      el.innerHTML = `
        <div class="btn-group">
          ${modes.map((m) => `
            <button class="${NS}btn-toggle" data-mode="${m.key}"
              style="${this.selected === m.key ? `background: ${m.color}; color: #000;` : ''}">
              ${m.icon} ${m.label}
            </button>
          `).join('')}
        </div>
      `;

      el.querySelectorAll(`.${NS}btn-toggle`).forEach((btn) => {
        btn.addEventListener('click', () => this.select(btn.dataset.mode));
      });

      return el;
    }

    select(mode) {
      this.selected = mode;
      MM.Audio.select();
      this.element.querySelectorAll(`.${NS}btn-toggle`).forEach((btn) => {
        btn.classList.toggle('active', btn.dataset.mode === mode);
      });
      if (this.onChange) this.onChange(mode);
    }

    get() { return this.selected; }
  }

  // ---- Stats Panel (HUD) ----
  class StatsPanel {
    constructor({ onRestart, onBack }) {
      this.onRestart = onRestart;
      this.onBack = onBack;
      this.element = this.render();
    }

    render() {
      const el = document.createElement('nav');
      el.className = `${NS}stats-hud glass-panel`;
      el.style.padding = '14px 20px';
      el.style.display = 'flex';
      el.style.alignItems = 'center';
      el.style.justifyContent = 'space-between';
      el.style.flexWrap = 'wrap';
      el.style.gap = '16px';
      el.style.marginBottom = '20px';

      el.innerHTML = `
        <div class="${NS}hud-left" style="display: flex; align-items: center; gap: 16px;">
          ${this.onBack ? `
            <button class="${NS}btn-icon glass-card" aria-label="Back"
              style="padding: 8px;">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="color: var(--neon-blue);">
                <path d="M19 12H5M12 19l-7-7 7-7"/>
              </svg>
            </button>
          ` : ''}
          <div class="${NS}hud-stat">
            <span class="${NS}hud-label">SCORE</span>
            <span class="${NS}hud-value" id="${NS}score">0</span>
          </div>
          <div class="${NS}hud-stat">
            <span class="${NS}hud-label">TIME</span>
            <span class="${NS}hud-value blue" id="${NS}time">00:00</span>
          </div>
          <div class="${NS}hud-stat">
            <span class="${NS}hud-label">DIFFICULTY</span>
            <span class="${NS}hud-value amber" id="${NS}difficulty">MEDIUM</span>
          </div>
        </div>
        <div class="${NS}hud-right" style="display: flex; align-items: center; gap: 12px;">
          ${this.onRestart ? `
            <button class="${NS}btn btn-primary" id="${NS}restartBtn" style="padding: 10px 20px;">
              RESTART
            </button>
          ` : ''}
          <div class="${NS}xp-stat hud-stat" style="min-width: 60px;">
            <span class="${NS}hud-label">XP</span>
            <span class="${NS}hud-value green" id="${NS}xp">0</span>
          </div>
        </div>
      `;

      if (this.onRestart) {
        const btn = el.querySelector(`#${NS}restartBtn`);
        btn.addEventListener('click', () => {
          MM.Audio.select();
          MM.Haptics.trigger('click');
          if (this.onRestart) this.onRestart();
        });
      }

      return el;
    }

    update({ score = 0, time = 0, difficulty = 'medium', xp = 0 } = {}) {
      const el = this.element;
      if (score !== undefined) el.querySelector(`#${NS}score`).textContent = MM.Engine.formatScore(score);
      if (time !== undefined) el.querySelector(`#${NS}time`).textContent = MM.Engine.formatTime(time);
      if (difficulty !== undefined) {
        el.querySelector(`#${NS}difficulty`).textContent = MM.Engine.getDifficultySettings()[difficulty]?.label ?? difficulty.toUpperCase();
        el.querySelector(`#${NS}difficulty`).style.color = MM.Engine.getDifficultySettings()[difficulty]?.color || 'var(--text-primary)';
      }
      if (xp !== undefined) el.querySelector(`#${NS}xp`).textContent = xp;
    }

    getElement() { return this.element; }
  }

  // ---- Modal ----
  class Modal {
    constructor(title, bodyHtml, actions = []) {
      this.title = title;
      this.actions = actions;
      this.element = this.render();
    }

    render() {
      const overlay = document.createElement('div');
      overlay.className = `${NS}modal-overlay`;
      overlay.innerHTML = `
        <div class="glass-panel modal-content" style="width: 100%; max-width: 520px; max-height: 90vh; overflow-y: auto;">
          <div class="modal-header">
            <h2 class="modal-title">${this.title}</h2>
            <button class="${NS}btn-icon" id="${NS}modalClose" aria-label="Close">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M18 6L6 18M6 6l12 12"/>
              </svg>
            </button>
          </div>
          <div class="modal-body" id="${NS}modalBody"></div>
          <div class="modal-footer" id="${NS}modalFooter" style="display: flex; gap: 12px; justify-content: flex-end;">
            ${this.actions.map((a) => `
              <button class="${a.type === 'primary' ? `${NS}btn btn-primary` : `${NS}btn btn-secondary'}`}
                data-action="${a.action || ''}">${a.label}</button>
            `).join('')}
          </div>
        </div>
      `;

      overlay.querySelector(`#${NS}modalClose`).addEventListener('click', () => this.close());
      overlay.addEventListener('click', (e) => {
        if (e.target === overlay) this.close();
      });

      overlay.querySelectorAll('[data-action]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const action = this.actions.find((a) => a.action === btn.dataset.action);
          if (action && action.onClick) action.onClick();
          if (action?.close !== false) this.close();
        });
      });

      return overlay;
    }

    open() {
      document.body.appendChild(this.element);
      requestAnimationFrame(() => this.element.classList.add('active'));
      MM.Audio.select();
    }

    close() {
      this.element.classList.remove('active');
      setTimeout(() => this.element.remove(), 300);
      MM.Audio.click();
    }

    setBody(html) {
      this.element.querySelector(`#${NS}modalBody`).innerHTML = html;
    }

    getTitle() { return this.title; }
  }

  // ---- Progress Bar ----
  class ProgressBar {
    constructor({ initial = 0, color = 'blue', onComplete } = {}) {
      this.initial = initial;
      this.color = color;
      this.onComplete = onComplete;
      this.value = initial;
      this.element = this.render();
      this.bar = this.element.querySelector(`.${NS}progress-bar`);
      this.update(initial);
    }

    render() {
      const el = document.createElement('div');
      el.className = `${NS}progress-wrap`;
      el.innerHTML = `
        <div class="${NS}progress-bar ${this.color}" style="width: ${this.initial}%;"></div>
      `;
      return el;
    }

    update(percent, duration = 500) {
      this.value = Math.max(0, Math.min(100, percent));
      this.bar.style.width = `${this.value}%`;
      if (this.value >= 100 && this.onComplete) this.onComplete();
    }

    reset() { this.update(this.initial); }
  }

  // ---- Number Grid (3x3 to 6x6) ----
  class NumberGrid {
    constructor(rows, cols, opts = {}) {
      this.rows = rows;
      this.cols = cols;
      this.cells = [];
      this.selected = null;
      this.onSelect = opts.onSelect || (() => {});
      this.onClick = opts.onClick || (() => {});
      this.element = this.render();
    }

    render() {
      const el = document.createElement('div');
      el.className = `${NS}number-grid`;
      el.style.cssText = `
        display: grid;
        grid-template-columns: repeat(${this.cols}, 1fr);
        grid-template-rows: repeat(${this.rows}, 1fr);
        gap: 8px;
        width: 100%;
        max-width: 420px;
        aspect-ratio: ${this.cols}/${this.rows};
      `;

      for (let r = 0; r < this.rows; r++) {
        this.cells[r] = [];
        for (let c = 0; c < this.cols; c++) {
          const cell = document.createElement('div');
          cell.className = `${NS}grid-cell glass-card`;
          cell.dataset.row = r;
          cell.dataset.col = c;
          cell.style.cssText = `
            background: var(--bg-glass-strong);
            border: 1px solid var(--border-glass);
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-family: 'Orbitron', sans-serif;
            font-size: ${Math.max(14, 32 - (this.rows * 4))}px;
            font-weight: 600;
            color: var(--text-primary);
            cursor: pointer;
            transition: all var(--ease-out-expo) 0.2s;
            user-select: none;
            -webkit-tap-highlight-color: transparent;
          `;

          cell.addEventListener('click', () => this.handleClick(r, c, cell));
          cell.addEventListener('mouseenter', () => this.hoverCell(cell));
          cell.addEventListener('mouseleave', () => this.leaveCell(cell));
          el.appendChild(cell);
          this.cells[r][c] = cell;
        }
      }

      return el;
    }

    handleClick(row, col, cell) {
      if (this.selected) {
        this.clearSelection();
      }
      this.selectCell(row, col, cell);
    }

    selectCell(row, col, cell) {
      this.selected = { row, col, element: cell };
      cell.style.borderColor = 'var(--neon-blue)';
      cell.style.boxShadow = 'var(--glow-blue)';
      cell.style.transform = 'scale(1.1)';
      MM.Audio.tap();
      MM.Haptics.trigger('selection');
      this.onSelect(row, col, cell);
    }

    clearSelection() {
      if (this.selected) {
        this.selected.element.style.borderColor = 'var(--border-glass)';
        this.selected.element.style.boxShadow = 'var(--shadow-glass)';
        this.selected.element.style.transform = 'scale(1)';
        this.selected = null;
      }
    }

    hoverCell(cell) {
      if (!cell.classList.contains('mm-selected')) {
        cell.style.transform = 'scale(1.05)';
      }
    }

    leaveCell(cell) {
      if (!cell.classList.contains('mm-selected')) {
        cell.style.transform = 'scale(1)';
      }
    }

    reveal(row, col, value, correct) {
      const cell = this.cells[row][col];
      cell.textContent = value;
      cell.style.background = correct
        ? 'linear-gradient(135deg, var(--neon-green), #00cc7a)'
        : 'linear-gradient(135deg, var(--neon-red), #ff0055)';
      cell.style.borderColor = correct ? 'var(--neon-green)' : 'var(--neon-red)';
      cell.style.boxShadow = correct ? 'var(--glow-green)' : 'var(--glow-red)';
      cell.style.color = '#000';
      MM.Audio.correct();
      MM.Haptics.trigger(correct ? 'success' : 'error');
      this.onSelect(row, col, cell);
    }

    reset() {
      this.clearSelection();
      for (let r = 0; r < this.rows; r++) {
        for (let c = 0; c < this.cols; c++) {
          const cell = this.cells[r][c];
          cell.textContent = '';
          cell.style.background = 'var(--bg-glass-strong)';
          cell.style.borderColor = 'var(--border-glass)';
          cell.style.boxShadow = 'var(--shadow-glass)';
          cell.style.color = 'var(--text-primary)';
          cell.style.transform = 'scale(1)';
        }
      }
    }

    getElement() { return this.element; }
  }

  // ---- Ripple Button ----
  class RippleButton extends HTMLButtonElement {
    constructor(label, opts = {}) {
      super();
      this.textContent = label;
      this.className = opts.className || `${NS}btn btn-primary`;
      this.type = opts.type || 'button';
      this.addEventListener('click', (e) => this.ripple(e));
    }

    ripple(e) {
      const rect = this.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      const ripple = document.createElement('span');
      ripple.style.position = 'absolute';
      ripple.style.left = `${x}px`;
      ripple.style.top = `${y}px`;
      ripple.style.width = '4px';
      ripple.style.height = '4px';
      ripple.style.background = 'rgba(255, 255, 255, 0.6)';
      ripple.style.borderRadius = '50%';
      ripple.style.transform = 'translate(-50%, -50%)';
      ripple.style.pointerEvents = 'none';
      ripple.style.animation = 'ripple 0.6s ease-out';
      this.appendChild(ripple);
      setTimeout(() => ripple.remove(), 600);
    }
  }

  // Register custom element
  if (typeof customElements !== 'undefined' && !customElements.get(`${NS}ripple-btn`)) {
    customElements.define(`${NS}ripple-btn`, RippleButton);
  }

  // Add ripple keyframes if not present
  if (!document.getElementById(`${NS}ripple-keyframes`)) {
    const style = document.createElement('style');
    style.id = `${NS}ripple-keyframes`;
    style.textContent = `
      @keyframes ripple {
        0% { transform: translate(-50%, -50%) scale(1); opacity: 0.8; }
        100% { transform: translate(-50%, -50%) scale(25); opacity: 0; }
      }
    `;
    document.head.appendChild(style);
  }

  // ---- Sound Toggle (music + SFX on/off with live indicator) ----
  class SoundToggle {
    constructor({ music = true, sfx = true, onChange } = {}) {
      this.musicOn = music;
      this.sfxOn = sfx;
      this.onChange = onChange;
      this.element = this.render();
    }

    render() {
      const el = document.createElement('div');
      el.className = `${NS}sound-toggle glass-panel`;
      el.style.cssText = `
        display: flex; align-items: center; gap: 10px;
        padding: 8px 14px;
      `;
      el.innerHTML = `
        <button class="${NS}sound-btn" data-target="music"
          aria-label="Toggle background music" aria-pressed="${this.musicOn}"
          style="
            width: 42px; height: 42px; border-radius: 50%;
            background: var(--bg-glass); border: 1px solid var(--border-glass-light);
            color: ${this.musicOn ? 'var(--neon-blue)' : 'var(--text-muted)'};
            cursor: pointer; display: flex; align-items: center; justify-content: center;
            transition: all var(--ease-out-expo) 0.25s;
          ">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
            <path d="M9 18V6l7-4v16z"/>
            ${this.musicOn
              ? '<path d="M16 8.5a4 4 0 0 1 0 7M19 5.5a8 8 0 0 1 0 13"/>'
              : '<line x1="21" y1="3" x2="4" y2="21"/>'}
          </svg>
        </button>
        <button class="${NS}sound-btn" data-target="sfx"
          aria-label="Toggle sound effects" aria-pressed="${this.sfxOn}"
          style="
            width: 42px; height: 42px; border-radius: 50%;
            background: var(--bg-glass); border: 1px solid var(--border-glass-light);
            color: ${this.sfxOn ? 'var(--neon-green)' : 'var(--text-muted)'};
            cursor: pointer; display: flex; align-items: center; justify-content: center;
            transition: all var(--ease-out-expo) 0.25s;
          ">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
            <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5" fill="currentColor" stroke="none"/>
            ${this.sfxOn
              ? '<path d="M15.5 8.5a5 5 0 0 1 0 7"/>'
              : '<line x1="22" y1="2" x2="14" y2="22"/>'}
          </svg>
        </button>
      `;

      el.querySelectorAll(`.${NS}sound-btn`).forEach((btn) => {
        btn.addEventListener('click', () => this.toggle(btn.dataset.target));
      });

      return el;
    }

    toggle(target) {
      if (target === 'music') {
        this.musicOn = !this.musicOn;
        MM.Audio.musicToggle();
      } else {
        this.sfxOn = !this.sfxOn;
        MM.Audio.setMuted(!this.sfxOn);
        if (this.sfxOn) MM.Audio.click();
      }
      this.updateButtons();
      if (this.onChange) this.onChange({ music: this.musicOn, sfx: this.sfxOn });
    }

    updateButtons() {
      this.element.querySelectorAll(`.${NS}sound-btn`).forEach((btn) => {
        const on = btn.dataset.target === 'music' ? this.musicOn : this.sfxOn;
        btn.setAttribute('aria-pressed', String(on));
        btn.style.color = on
          ? (btn.dataset.target === 'music' ? 'var(--neon-blue)' : 'var(--neon-green)')
          : 'var(--text-muted)';
        btn.style.boxShadow = on ? (btn.dataset.target === 'music' ? 'var(--glow-blue)' : 'var(--glow-green)') : 'none';
      });
    }

    set({ music, sfx }) {
      if (music !== undefined) this.musicOn = music;
      if (sfx !== undefined) this.sfxOn = sfx;
      this.updateButtons();
    }

    getElement() { return this.element; }
  }

  return {
    GameCard,
    DifficultyToggle,
    StatsPanel,
    Modal,
    ProgressBar,
    NumberGrid,
    RippleButton,
    SoundToggle,
  };
})();