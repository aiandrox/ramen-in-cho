(() => {
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)');
  const stage = document.querySelector('.stage');
  const book = document.querySelector('.book');
  const sticky = document.querySelector('.stage-sticky');

  // 開いた見開き（中の頁＋見返し）を画面の真ん中に置く位置と倍率
  const measure = () => {
    const w = book.offsetWidth;
    const h = book.offsetHeight;
    const vw = sticky.clientWidth;
    const vh = sticky.clientHeight;
    const s = Math.min(1.12, (vw - 32) / (2 * w), (vh - 48) / h);
    book.style.setProperty('--dx', `${vw / 2 - (book.offsetLeft + w)}px`);
    book.style.setProperty('--dy', `${vh / 2 - (book.offsetTop + h / 2)}px`);
    book.style.setProperty('--s', s.toFixed(3));
  };

  // 表紙: スクロールにあわせて開く（0〜1）
  let ticking = false;
  const update = () => {
    ticking = false;
    if (reduce.matches) {
      sticky.style.setProperty('--p', 0);
      return;
    }
    const range = stage.offsetHeight - window.innerHeight;
    const p = range > 0 ? Math.min(1, Math.max(0, -stage.getBoundingClientRect().top / range)) : 0;
    sticky.style.setProperty('--p', p.toFixed(3));
    book.style.setProperty('--p', p.toFixed(3));
  };
  const onScroll = () => {
    if (!ticking) {
      ticking = true;
      requestAnimationFrame(update);
    }
  };
  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', () => {
    measure();
    onScroll();
  });
  measure();
  update();
  document.fonts?.ready.then(measure);

  // 蛇腹: 頁が見えたら開き、印を押す
  const leaves = document.querySelectorAll('.leaf');
  if (!('IntersectionObserver' in window)) {
    leaves.forEach((leaf) => leaf.classList.add('is-open'));
    return;
  }
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-open');
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.2, rootMargin: '0px 0px -10% 0px' },
  );
  leaves.forEach((leaf) => observer.observe(leaf));
  // 印の見出しへ直接飛んだときも開いておく
  if (location.hash) {
    const target = document.querySelector(location.hash);
    if (target && target.classList.contains('leaf')) target.classList.add('is-open');
  }
})();
