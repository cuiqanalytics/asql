(function () {
  'use strict';

  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function initScrollReveal() {
    var nodes = Array.from(document.querySelectorAll('.reveal'));
    if (reduceMotion || !('IntersectionObserver' in window)) {
      nodes.forEach(function (n) { n.classList.add('is-visible'); });
      return;
    }
    nodes.forEach(function (n, i) {
      n.style.transitionDelay = (i % 4) * 70 + 'ms';
    });
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          io.unobserve(entry.target);
        }
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
    nodes.forEach(function (n) { io.observe(n); });
    setTimeout(function () {
      nodes.forEach(function (n) { n.classList.add('is-visible'); });
    }, 2500);
  }

  function initChartDraw() {
    var charts = document.querySelectorAll('[data-chart]');
    if (!charts.length) return;
    if (reduceMotion) {
      charts.forEach(function (c) { c.classList.add('is-drawn'); });
      return;
    }
    var cio = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('is-drawn');
        cio.unobserve(entry.target);
      });
    }, { threshold: 0.3 });
    charts.forEach(function (c) { cio.observe(c); });
  }

  function initCopyButtons() {
    document.querySelectorAll('[data-copy]').forEach(function (btn) {
      var defaultLabel = btn.textContent;
      var timer;
      btn.addEventListener('click', function () {
        var cmd = btn.getAttribute('data-copy');
        if (navigator.clipboard) navigator.clipboard.writeText(cmd).catch(function () {});
        btn.textContent = 'Copied';
        clearTimeout(timer);
        timer = setTimeout(function () { btn.textContent = defaultLabel; }, 1600);
      });
    });
  }

  function initFlipCardsAndCarousel() {
    var track = document.querySelector('.carousel-track');
    if (!track) return;
    var slides = document.querySelectorAll('.flip-card');
    var dots = document.querySelectorAll('.carousel-dot');
    track.style.setProperty('--carousel-count', slides.length);

    function goTo(index) {
      var next = (index + slides.length) % slides.length;
      track.style.setProperty('--carousel-index', next);
      dots.forEach(function (dot, i) {
        dot.classList.toggle('is-active', i === next);
      });
    }

    document.addEventListener('click', function (e) {
      var flipBtn = e.target.closest('.flip-btn');
      if (flipBtn) {
        var card = flipBtn.closest('.flip-card');
        if (card) card.classList.toggle('is-flipped');
        return;
      }
      var prevBtn = e.target.closest('.carousel-prev');
      var nextBtn = e.target.closest('.carousel-next');
      var dotBtn = e.target.closest('.carousel-dot');
      if (!prevBtn && !nextBtn && !dotBtn) return;
      var current = parseInt(track.style.getPropertyValue('--carousel-index') || '0', 10);
      if (prevBtn) goTo(current - 1);
      else if (nextBtn) goTo(current + 1);
      else goTo(parseInt(dotBtn.getAttribute('data-goto'), 10));
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    initScrollReveal();
    initChartDraw();
    initCopyButtons();
    initFlipCardsAndCarousel();
  });
})();
