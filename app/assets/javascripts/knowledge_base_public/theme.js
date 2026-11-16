(function() {
  'use strict';

  var root = document.documentElement;
  var button = document.querySelector('.js-kb-theme-toggle');
  var storageKey = 'knowledge-base-theme';
  var mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');

  function readStoredTheme() {
    try {
      var theme = localStorage.getItem(storageKey) || localStorage.getItem('theme');

      if(theme === 'dark' || theme === 'light') {
        return theme;
      }
    } catch(error) { }

    return null;
  }

  function automaticTheme() {
    return mediaQuery.matches ? 'dark' : 'light';
  }

  function updateButton(theme) {
    if(!button) {
      return;
    }

    var nextTheme = theme === 'dark' ? 'light' : 'dark';
    var label = nextTheme === 'dark' ? button.dataset.darkLabel : button.dataset.lightLabel;

    button.setAttribute('aria-label', label);
    button.setAttribute('title', label);
    button.setAttribute('aria-pressed', theme === 'dark' ? 'true' : 'false');
  }

  function applyTheme(theme, persist) {
    root.dataset.theme = theme;
    root.style.colorScheme = theme;

    if(persist) {
      try {
        localStorage.setItem(storageKey, theme);
      } catch(error) { }
    }

    updateButton(theme);
  }

  function handleSystemThemeChange() {
    if(!readStoredTheme()) {
      applyTheme(automaticTheme(), false);
    }
  }

  applyTheme(readStoredTheme() || automaticTheme(), false);

  if(button) {
    button.addEventListener('click', function() {
      applyTheme(root.dataset.theme === 'dark' ? 'light' : 'dark', true);
    });
  }

  if(typeof mediaQuery.addEventListener === 'function') {
    mediaQuery.addEventListener('change', handleSystemThemeChange);
  } else if(typeof mediaQuery.addListener === 'function') {
    mediaQuery.addListener(handleSystemThemeChange);
  }
})();
