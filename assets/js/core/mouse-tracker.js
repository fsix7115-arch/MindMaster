/**
 * =====================================================================
 * MindMaster — Mouse Tracker & Motion Engine
 * =====================================================================
 *
 * PURPOSE
 *   Real-time mouse/pointer tracking with parallax depth, element following,
 *   and reactive CSS state. Every interactive element can react to cursor
 *   position, creating the 2040 "living interface" feel.
 *
 * FEATURES
 *   - Sub-pixel accurate mouse coordinates with smoothing
 *   - Parallax: layers move at different speeds based on depth value
 *   - Element follower: any DOM node gains mouse-reactive behavior
 *   - Raycast system: detect which element is under cursor
 *   - Tilt effect: cards 3D-rotate toward the pointer
 *   - Smooth dampening (no jitter)
 *   - Touch/pointer fallback support
 *   - Reduced-motion respect
 *
 * USAGE
 *   // Track mouse (global state)
 *   MM.Mouse.tracker.update({ x, y, z });
 *
 *   // Make an element reactive to the mouse
 *   MM.Mouse.trackElement('.card', { depth: 20, tilt: 15 });
 *
 *   // Parallax a layer
 *   MM.Mouse.trackLayer('.layer', { speed: 0.15 });
 *
 *   // Query what's under the cursor
 *   MM.Mouse.raycast('.interactive') // returns closest matching element
 *
 * @author Aether
 */

MM.Mouse = (function () {
  'use strict';

  // ---- State ----
  const state = {
    x: window.innerWidth / 2,
    y: window.innerHeight / 2,
    rawX: window.innerWidth / 2,
    rawY: window.innerHeight / 2,
    z: 0,
    vx: 0,
    vy: 0,
    vxRaw: 0,
    vyRaw: 0,
    isMoving: false,
    movingUntil: 0,
    reducedMotion: window.matchMedia('(prefers-reduced-motion: reduce)').matches,
  };

  const config = {
    smoothness: 0.08,           // LERP factor for smoothing (0.01-1)
    tiltMax: 12,                // max degrees of card tilt
    parallaxBound: 1.5,         // max scroll offset for parallax
    deactivateAfter: 800,       // ms of inactivity before "isMoving" ends
  };

  const domElements = new Map();   // element -> { depth, tilt, current }
  const layers = [];               // { element, speed, startOffset }

  // ---- Event listeners ----
  function onMouseMove(e) {
    const { clientX, clientY, pressure } = e;
    state.rawX = clientX;
    state.rawY = clientY;
    state.z = (pressure ?? 0.5) * 2 - 1;  // -1 .. 1 based on touch pressure

    state.isMoving = true;
    state.movingUntil = Date.now() + config.deactivateAfter;

    // Velocity
    state.vxRaw = clientX - state.rawX;
    state.vyRaw = clientY - state.rawY;
  }

  function onTouchMove(e) {
    if (e.touches.length) {
      state.rawX = e.touches[0].clientX;
      state.rawY = e.touches[0].clientY;
      state.isMoving = true;
      state.movingUntil = Date.now() + config.deactivateAfter;
    }
  }

  // ---- Main loop (animation frame) ----
  function tick() {
    if (state.reducedMotion) {
      state.x = state.rawX;
      state.y = state.rawY;
      state.vx = state.vxRaw;
      state.vy = state.vyRaw;
    } else {
      // Smooth position (LERP)
      state.x += (state.rawX - state.x) * config.smoothness;
      state.y += (state.rawY - state.y) * config.smoothness;

      // Smooth velocity
      state.vx += (state.vxRaw - state.vx) * 0.2;
      state.vy += (state.vyRaw - state.vy) * 0.2;

      // Stop moving flag
      state.isMoving = Date.now() < state.movingUntil;
    }

    // Update tracked elements
    domElements.forEach(updateElement);
    layers.forEach(updateLayer);

    requestAnimationFrame(tick);
  }

  function updateElement(element, cfg) {
    const rect = element.getBoundingClientRect();
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;

    const dx = (state.x - cx) / (rect.width / 2);
    const dy = (state.y - cy) / (rect.height / 2);

    // Clamp
    const clampedDx = Math.max(-1, Math.min(1, dx));
    const clampedDy = Math.max(-1, Math.min(1, dy));

    // Tilt: rotate based on pointer offset
    const rotateX = -clampedDy * cfg.tilt * 0.5;
    const rotateY = clampedDx * cfg.tilt * 0.5;

    // Parallax translation based on depth
    const px = clampedDx * cfg.depth * 0.6;
    const py = clampedDy * cfg.depth * 0.6;

    element.style.transform = `
      perspective(1000px)
      rotateX(${rotateX}deg)
      rotateY(${rotateY}deg)
      translate3d(${px}px, ${py}px, 0)
      translateZ(0)
    `;

    // Subtle brightness shift toward pointer
    const brightness = 100 + (state.z + 1) * 3 * cfg.depth;
    element.style.filter = `brightness(${brightness}%)`;
  }

  function updateLayer(entry) {
    const { element, speed, startOffset } = entry;
    const rect = element.getBoundingClientRect();
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;

    const dx = state.x - cx;
    const dy = state.y - cy;

    const offset = {
      x: dx * speed + startOffset.x,
      y: dy * speed + startOffset.y,
    };

    // Clamp parallax to avoid element flying off screen
    offset.x = Math.max(-config.parallaxBound, Math.min(config.parallaxBound, offset.x));
    offset.y = Math.max(-config.parallaxBound, Math.min(config.parallaxBound, offset.y));

    element.style.transform = `translate3d(${offset.x}px, ${offset.y}px, 0)`;
  }

  // ---- Public API ----
  const tracker = {
    update(pos) {
      state.rawX = pos.x ?? state.rawX;
      state.rawY = pos.y ?? state.rawY;
    },
    get state() { return { ...state }; },
    getX() { return state.x; },
    getY() { return state.y; },
    getZ() { return state.z; },
    getVelocity() { return { x: state.vx, y: state.vy }; },
    isMouseMoving() { return state.isMoving; },
    setReducedMotion(reduced) { state.reducedMotion = reduced; },
    toggleReducedMotion() {
      state.reducedMotion = !state.reducedMotion;
      return state.reducedMotion;
    },
  };

  // ---- Element tracking ----
  const trackElement = function (selectorOrElement, options = {}) {
    const element = typeof selectorOrElement === 'string'
      ? document.querySelector(selectorOrElement)
      : selectorOrElement;

    if (!element) return null;

    const cfg = {
      depth: options.depth ?? 15,
      tilt: options.tilt ?? config.tiltMax,
      current: { x: 0, y: 0 },
    };

    domElements.set(element, cfg);
    element.classList.add('mm-tracked');

    // Initial transform
    const rect = element.getBoundingClientRect();
    element.style.transform = `
      perspective(1000px)
      rotateX(0deg)
      rotateY(0deg)
      translate3d(0, 0, 0)
      translateZ(0)
    `;

    return { element, cfg };
  };

  // ---- Layer (parallax) tracking ----
  const trackLayer = function (selectorOrElement, options = {}) {
    const element = typeof selectorOrElement === 'string'
      ? document.querySelector(selectorOrElement)
      : selectorOrElement;

    if (!element) return null;

    const cfg = {
      speed: options.speed ?? 0.15,
      startOffset: { x: 0, y: 0 },
    };

    layers.push({ element, ...cfg });
    element.classList.add('mm-parallax');

    return { element, cfg };
  };

  // ---- Raycast: what element is under cursor ----
  const raycast = function (selector = '*') {
    // Temporarily hide tracked elements to find the true element beneath
    const tracked = document.querySelectorAll('.mm-tracked');
    tracked.forEach((el) => el.style.pointerEvents = 'none');

    const el = document.elementFromPoint(state.x, state.y);

    tracked.forEach((el) => el.style.pointerEvents = '');

    if (!el) return null;

    let node = el;
    while (node && node !== document) {
      if (node.matches(selector)) return node;
      node = node.parentElement;
    }
    return el.closest(selector) || null;
  };

  // ---- Event registration ----
  function bindEvents() {
    document.addEventListener('mousemove', onMouseMove, { passive: true });
    document.addEventListener('touchmove', onTouchMove, { passive: true });
    window.addEventListener('resize', () => {});
    window.addEventListener('orientationchange', () => {});
  }

  // ---- Public ----
  return {
    tracker,
    trackElement,
    trackLayer,
    raycast,
    tick,
    bindEvents,
    getConfig() { return { ...config }; },
    setState(key, value) {
      if (key in state) state[key] = value;
    },
  };
})();