/**
 * =====================================================================
 * MindMaster — Haptics & Visual Feedback Engine
 * =====================================================================
 *
 * PURPOSE
 *   Unified feedback system for touch devices and desktop. Provides:
 *   - Haptic vibration (vibrate API)
 *   - Screen flash / shake effects
 *   - Ripples on click (custom implementation)
 *   - Reduced-haptics respect
 *
 * @author Aether
 */

MM.Haptics = (function () {
  'use strict';

  const STATE = {
    supported: navigator.vibrate ? true : false,
    enabled: true,
    reduced: window.matchMedia('(prefers-reduced-motion: reduce)').matches,
  };

  /**
   * Vibrate with pattern support
   */
  function vibrate(pattern, repeat = false) {
    if (!STATE.supported || !STATE.enabled || STATE.reduced) return false;
    try {
      if (navigator.vibrate(pattern)) {
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  /**
   * Standard feedback patterns (adaptive to device)
   */
  const PATTERN = {
    soft: [20],
    medium: [30],
    heavy: [50, 20, 50],
    double: [20, 40, 20, 40],
    success: [10, 20, 10, 20, 10],
    error: [100],
    selection: [10],
    click: [10],
  };

  function trigger(type) {
    return vibrate(PATTERN[type] || PATTERN.medium);
  }

  /**
   * Screen shake effect
   */
  function shake(duration = 400) {
    if (STATE.reduced) return;

    const el = document.body;
    const keyframes = [
      { transform: 'translate3d(0, 0, 0)' },
      { transform: 'translate3d(-5px, -3px, 0)' },
      { transform: 'translate3d(5px, 3px, 0)' },
      { transform: 'translate3d(-5px, 3px, 0)' },
      { transform: 'translate3d(5px, -3px, 0)' },
      { transform: 'translate3d(0, 0, 0)' },
    ];
    el.animate(keyframes, {
      duration,
      easing: 'ease-in-out',
      fill: 'forwards',
    });
  }

  /**
   * Screen flash effect (flash of color)
   */
  function flash(color = '#00f3ff', intensity = 0.15) {
    if (STATE.reduced) return;

    const flash = document.createElement('div');
    flash.style.position = 'fixed';
    flash.style.inset = '0';
    flash.style.background = color;
    flash.style.opacity = intensity;
    flash.style.pointerEvents = 'none';
    flash.style.zIndex = '99999';
    flash.style.mixBlendMode = 'overlay';
    document.body.appendChild(flash);

    flash.animate(
      [{ opacity: intensity }, { opacity: 0 }],
      { duration: 300, easing: 'ease-out' }
    ).onfinish = () => flash.remove();
  }

  /**
   * Ripple effect at a point (CSS-only custom)
   */
  function ripple(x, y, color = '#00f3ff') {
    const ripple = document.createElement('div');
    ripple.style.position = 'absolute';
    ripple.style.left = `${x}px`;
    ripple.style.top = `${y}px`;
    ripple.style.width = '4px';
    ripple.style.height = '4px';
    ripple.style.background = color;
    ripple.style.borderRadius = '50%';
    ripple.style.transform = 'translate(-50%, -50%)';
    ripple.style.pointerEvents = 'none';
    ripple.style.zIndex = '99999';
    document.body.appendChild(ripple);

    ripple.animate(
      [
        { width: '4px', height: '4px', opacity: 1, transform: 'translate(-50%, -50%) scale(1)' },
        { width: '120px', height: '120px', opacity: 0, transform: 'translate(-50%, -50%) scale(1)' },
      ],
      { duration: 600, easing: 'ease-out' }
    ).onfinish = () => ripple.remove();
  }

  return {
    get state() { return { ...STATE }; },
    vibrate: vibrate,
    trigger: trigger,
    shake,
    flash,
    ripple,
    setEnabled(enabled) { STATE.enabled = enabled; },
    setReduced(reduced) { STATE.reduced = reduced; },
  };
})();