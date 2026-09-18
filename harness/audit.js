/* Live-page skin audit.
 *
 * Paste into devtools on a LOGGED-IN LibreNMS page with a skin active. Reports
 * anything rendering as a broken light surface, and any text below WCAG AA.
 *
 * Why this exists: reading stylesheets is not enough. Two coverage blind spots
 * in this project were found only by inspecting what the browser actually
 * computed -- 123 styles.css classes tw_dark.css never overrides, and three
 * cluster classes written in rgba() that a #hex-matching audit could not see.
 *
 * Notes on the two easy ways to get this wrong, both of which bit me:
 *  - Colours must be normalised through a canvas. getComputedStyle happily
 *    returns oklch(), and a naive rgb() regex reads oklch(0.637 0.237 25.331)
 *    as near-black, flagging a perfectly legible red.
 *  - A light background is not automatically a bug. Status chips are SUPPOSED
 *    to be bright fills with dark text, so size is used to tell a broken
 *    surface from an intentional chip, and contrast is measured separately.
 */
(() => {
  const cv = document.createElement('canvas');
  cv.width = cv.height = 1;
  const ctx = cv.getContext('2d', { willReadFrequently: true });

  // Normalise any CSS colour -- oklch, rgba, hsl, named -- to [r,g,b,a].
  const toRGB = (c) => {
    try {
      ctx.clearRect(0, 0, 1, 1);
      ctx.fillStyle = '#000000';
      ctx.fillStyle = c;
      ctx.fillRect(0, 0, 1, 1);
      const d = ctx.getImageData(0, 0, 1, 1).data;
      return [d[0], d[1], d[2], d[3] / 255];
    } catch { return null; }
  };

  const lin = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; };
  const L = (c) => 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2]);
  const ratio = (a, b) => {
    const [x, y] = [L(a), L(b)];
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
  };

  // Walk up for the first ancestor with an opaque background.
  const bgOf = (el) => {
    let n = el;
    while (n && n !== document.documentElement) {
      const c = toRGB(getComputedStyle(n).backgroundColor);
      if (c && c[3] > 0.5) return c;
      n = n.parentElement;
    }
    return [17, 17, 17, 1];
  };

  const sig = (el) => {
    const raw = el.className;
    const c = (raw && raw.baseVal !== undefined) ? raw.baseVal : raw;
    const cls = (typeof c === 'string' && c.trim())
      ? '.' + c.trim().split(/\s+/).slice(0, 2).join('.') : '';
    return el.tagName.toLowerCase() + cls;
  };

  const surfaces = {}, chips = {}, low = {};
  const bump = (o, k) => { o[k] = (o[k] || 0) + 1; };

  for (const el of document.querySelectorAll('body *')) {
    const r = el.getBoundingClientRect();
    if (r.width < 4 || r.height < 4) continue;
    if (['IMG', 'CANVAS', 'SVG'].includes(el.tagName)) continue;

    const cs = getComputedStyle(el);
    const bg = toRGB(cs.backgroundColor);
    if (bg && bg[3] > 0.5 && L(bg) > 0.5) {
      bump(r.width * r.height > 6000 ? surfaces : chips, sig(el));
    }

    if (el.children.length === 0 && el.textContent.trim()) {
      const fg = toRGB(cs.color);
      if (fg) {
        const cr = ratio(fg, bgOf(el));
        if (cr < 4.5) bump(low, `${sig(el)} (${cr.toFixed(1)}:1)`);
      }
    }
  }

  const top = (o) => Object.entries(o).sort((a, b) => b[1] - a[1])
    .slice(0, 12).map(([k, v]) => `${v}x ${k}`);

  const out = {
    page: location.pathname,
    lightSurfaces: top(surfaces),   // real problems
    brightChips: top(chips),        // usually intentional - check contrast below
    belowAA: top(low),              // real problems
  };
  console.table(out.belowAA.map((s) => ({ finding: s })));
  return out;
})();
