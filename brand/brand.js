// cuiqanalytics brand script: shared by cuiqanalytics.com, rgen, qdata and asql (copied by sync-brand.sh).
// Load it in <head> without defer so the saved theme applies before first paint. Pages that redraw on
// theme change listen for the 'cq-themechange' event; window.cqIsDark() tells the current theme.
(() => {
  const root = document.documentElement;
  const KEY = 'cq-theme';
  const get = (k) => { try { return localStorage.getItem(k); } catch { return null; } };
  const set = (k, v) => { try { localStorage.setItem(k, v); } catch { /* private mode */ } };
  const saved = get(KEY) || get(`${root.dataset.product || ''}-theme`);
  if (saved === 'light' || saved === 'dark') root.dataset.theme = saved;
  const isDark = () => root.dataset.theme ? root.dataset.theme === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches;
  window.cqIsDark = isDark;
  document.addEventListener('click', (e) => {
    if (!e.target.closest('.theme-toggle')) return;
    root.dataset.theme = isDark() ? 'light' : 'dark';
    set(KEY, root.dataset.theme);
    document.dispatchEvent(new CustomEvent('cq-themechange', { detail: { dark: isDark() } }));
  });
})();
