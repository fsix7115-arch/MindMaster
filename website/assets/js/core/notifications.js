/**
 * =====================================================================
 * MindMaster — Notification / Toast System
 * =====================================================================
 */

MM.Notifications = (function () {
  'use strict';

  let container = null;

  function ensureContainer() {
    if (!container) {
      container = document.createElement('div');
      container.className = 'toast-container';
      document.body.appendChild(container);
    }
    return container;
  }

  const TYPES = {
    success: { icon: '✓', color: '#00ff9d', title: 'Success' },
    error: { icon: '✕', color: '#ff2a6d', title: 'Error' },
    warning: { icon: '⚠', color: '#ffaa00', title: 'Warning' },
    info: { icon: 'ℹ', color: '#00f3ff', title: 'Info' },
  };

  function createToast(type, { title, message, duration = 3500 }) {
    const t = TYPES[type] || TYPES.info;
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `
      <div class="toast-icon" style="color: ${t.color}; font-weight: 700; font-size: 1.2rem;">${t.icon}</div>
      <div class="toast-content">
        <div class="toast-title" style="font-weight: 600; color: var(--text-primary);">${title}</div>
        <div class="toast-message" style="color: var(--text-secondary); font-size: 0.9rem;">${message}</div>
      </div>
    `;

    const close = () => {
      toast.style.animation = 'toastOut 0.3s var(--ease-out-expo) forwards';
      setTimeout(() => toast.remove(), 300);
    };

    toast.addEventListener('click', close);
    ensureContainer().appendChild(toast);

    // Auto dismiss
    let dismissed = false;
    setTimeout(() => {
      if (!dismissed) close();
    }, duration);

    // Pause on hover
    toast.addEventListener('mouseenter', () => { dismissed = true; });
    toast.addEventListener('mouseleave', () => { dismissed = false; });

    return toast;
  }

  // Add toastOut animation
  const style = document.createElement('style');
  style.textContent = `
    @keyframes toastOut {
      0% { transform: translateX(0); opacity: 1; }
      100% { transform: translateX(120%); opacity: 0; }
    }
  `;
  if (!document.getElementById('mm-toast-styles')) {
    style.id = 'mm-toast-styles';
    document.head.appendChild(style);
  }

  return {
    show(data) { return createToast(data.type, data); },
    success: (title, message, duration) => createToast('success', { title, message, duration }),
    error: (title, message, duration) => createToast('error', { title, message, duration }),
    warning: (title, message, duration) => createToast('warning', { title, message, duration }),
    info: (title, message, duration) => createToast('info', { title, message, duration }),
    clear: () => { while (container?.firstChild) container.firstChild.remove(); },
  };
})();