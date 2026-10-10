(() => {
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  if (reduceMotion) {
    document.querySelectorAll('.video-frame video').forEach((v) => {
      v.removeAttribute('autoplay'); v.pause(); v.controls = true;
    });
  }

  document.querySelectorAll('[data-tabs]').forEach((box) => {
    const tabs = [...box.querySelectorAll('[role="tab"]')];
    const select = (tab) => {
      tabs.forEach((t) => {
        const on = t === tab;
        t.setAttribute('aria-selected', on);
        t.tabIndex = on ? 0 : -1;
        document.getElementById(t.getAttribute('aria-controls')).hidden = !on;
      });
    };
    tabs.forEach((t, i) => {
      t.addEventListener('click', () => select(t));
      t.addEventListener('keydown', (e) => {
        if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
        const next = tabs[(i + (e.key === 'ArrowRight' ? 1 : tabs.length - 1)) % tabs.length];
        select(next); next.focus();
      });
    });
    if (/Mac|Win/.test(navigator.platform || '')) select(tabs[1]);
  });

  document.querySelectorAll('.copy').forEach((btn) => {
    btn.addEventListener('click', async () => {
      try { await navigator.clipboard.writeText(btn.dataset.copy); } catch {
        const ta = Object.assign(document.createElement('textarea'), { value: btn.dataset.copy });
        document.body.append(ta); ta.select(); document.execCommand('copy'); ta.remove();
      }
      btn.textContent = 'Copied'; btn.classList.add('done');
      setTimeout(() => { btn.textContent = 'Copy'; btn.classList.remove('done'); }, 1600);
    });
  });

  // draw the hero chart's lines once it scrolls into view
  const charts = document.querySelectorAll('[data-chart]');
  if (reduceMotion || !('IntersectionObserver' in window)) {
    charts.forEach((c) => c.classList.add('is-drawn'));
  } else {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('is-drawn');
        io.unobserve(entry.target);
      });
    }, { threshold: 0.3 });
    charts.forEach((c) => io.observe(c));
  }

  // examples: flip cards inside a two-slide carousel
  const track = document.querySelector('.carousel-track');
  if (track) {
    const slides = document.querySelectorAll('.flip-card');
    const dots = document.querySelectorAll('.carousel-dot');
    let current = 0;
    track.style.setProperty('--carousel-count', slides.length);
    const goTo = (index) => {
      current = (index + slides.length) % slides.length;
      track.style.setProperty('--carousel-index', current);
      dots.forEach((dot, i) => dot.classList.toggle('is-active', i === current));
    };
    document.addEventListener('click', (e) => {
      const flipBtn = e.target.closest('.flip-btn');
      if (flipBtn) { flipBtn.closest('.flip-card').classList.toggle('is-flipped'); return; }
      if (e.target.closest('.carousel-prev')) goTo(current - 1);
      else if (e.target.closest('.carousel-next')) goTo(current + 1);
      else {
        const dot = e.target.closest('.carousel-dot');
        if (dot) goTo(Number(dot.dataset.goto));
      }
    });
  }
})();
