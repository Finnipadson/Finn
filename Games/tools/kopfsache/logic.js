// ============================================================
// LOGIC (reine Spiellogik – ohne DOM, auch in Node testbar)
// ============================================================

// ---------- RNG ----------
function mulberry32(a) {
  return function () {
    a |= 0; a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
function hashSeed(...parts) {
  let h = 2166136261;
  for (const p of parts) {
    const s = String(p);
    for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
    h ^= 0x9e37; h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}
const Rnd = {
  int(rng, a, b) { return a + Math.floor(rng() * (b - a + 1)); },
  pick(rng, arr) { return arr[Math.floor(rng() * arr.length)]; },
  shuffle(rng, arr) {
    const a = arr.slice();
    for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(rng() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; }
    return a;
  },
  weighted(rng, items, weightFn) {
    let total = 0; const w = items.map(it => { const x = Math.max(0, weightFn(it)); total += x; return x; });
    if (total <= 0) return items[Math.floor(rng() * items.length)];
    let r = rng() * total;
    for (let i = 0; i < items.length; i++) { r -= w[i]; if (r <= 0) return items[i]; }
    return items[items.length - 1];
  }
};

// ---------- KOPFRECHNEN ----------
const MathGen = (() => {
  const fmt = n => n < 0 ? '−' + Math.abs(n) : String(n);

  function basic(rng, d) {
    const op = Rnd.pick(rng, d < 0.08 ? ['+', '−'] : ['+', '−', '×', '÷']);
    const max = Math.round(10 + 140 * Math.pow(d, 1.15));
    let a, b, ans;
    if (op === '+') { a = Rnd.int(rng, 2, max); b = Rnd.int(rng, 2, max); ans = a + b; }
    else if (op === '−') { a = Rnd.int(rng, 5, max + 5); b = Rnd.int(rng, 1, a - 1); ans = a - b; }
    else if (op === '×') { a = Rnd.int(rng, 2, Math.round(6 + 14 * d)); b = Rnd.int(rng, 2, Math.round(9 + 11 * d)); ans = a * b; }
    else { b = Rnd.int(rng, 2, Math.round(6 + 8 * d)); ans = Rnd.int(rng, 2, Math.round(9 + 11 * d)); a = b * ans; }
    return { text: `${a} ${op} ${b}`, answer: ans, kind: 'basic' };
  }

  function chain(rng, d) {
    for (let tries = 0; tries < 50; tries++) {
      const nTerms = 2 + (d > 0.45 ? 1 : 0) + (d > 0.8 ? 1 : 0);
      const terms = [];
      let hasProduct = false;
      for (let i = 0; i < nTerms; i++) {
        const r = rng();
        if (r < 0.45 || (i === nTerms - 1 && !hasProduct)) {
          hasProduct = true;
          if (rng() < 0.7) {
            const x = Rnd.int(rng, 2, Math.round(5 + 7 * d)), y = Rnd.int(rng, 2, 9);
            terms.push({ text: `${x} × ${y}`, val: x * y });
          } else {
            const y = Rnd.int(rng, 2, 9), q = Rnd.int(rng, 2, Math.round(5 + 6 * d));
            terms.push({ text: `${y * q} ÷ ${y}`, val: q });
          }
        } else {
          const v = Rnd.int(rng, 2, Math.round(15 + 60 * d));
          terms.push({ text: String(v), val: v });
        }
      }
      let text = terms[0].text, val = terms[0].val;
      for (let i = 1; i < terms.length; i++) {
        const plus = rng() < 0.55;
        text += plus ? ' + ' : ' − ';
        text += terms[i].text;
        val += plus ? terms[i].val : -terms[i].val;
      }
      if (val >= 0 && val <= 400) return { text, answer: val, kind: 'chain' };
    }
    return basic(rng, d);
  }

  function missing(rng, d) {
    const form = Rnd.int(rng, 0, d < 0.3 ? 1 : 3);
    const max = Math.round(12 + 90 * d);
    if (form === 0) { const a = Rnd.int(rng, 2, max), x = Rnd.int(rng, 2, max); return { text: `${a} + ? = ${a + x}`, answer: x, kind: 'missing' }; }
    if (form === 1) { const x = Rnd.int(rng, 10, max + 10), b = Rnd.int(rng, 1, x - 1); return { text: `? − ${b} = ${x - b}`, answer: x, kind: 'missing' }; }
    if (form === 2) { const a = Rnd.int(rng, 2 + Math.round(4 * d), Math.round(5 + 10 * d)), x = Rnd.int(rng, 2 + Math.round(3 * d), 12); return { text: `${a} × ? = ${a * x}`, answer: x, kind: 'missing' }; }
    const b = Rnd.int(rng, 2, 9), c = Rnd.int(rng, 2, Math.round(6 + 8 * d));
    return { text: `? ÷ ${b} = ${c}`, answer: b * c, kind: 'missing' };
  }

  function sequence(rng, d) {
    const kinds = ['arith'];
    if (d > 0.3) kinds.push('alt', 'square');
    if (d > 0.45) kinds.push('geo', 'fib');
    if (d > 0.65) kinds.push('grow');
    const k = Rnd.pick(rng, kinds);
    let seq = [];
    if (k === 'arith') {
      const s = Rnd.int(rng, 1, 30), step = Rnd.int(rng, 2, Math.round(4 + 10 * d)) * (rng() < 0.25 && d > 0.3 ? -1 : 1);
      const start = step < 0 ? s + 6 * -step : s;
      for (let i = 0; i < 6; i++) seq.push(start + i * step);
    } else if (k === 'alt') {
      const a = Rnd.int(rng, 3, 9), b = Rnd.int(rng, 1, a - 1); let v = Rnd.int(rng, 1, 15);
      for (let i = 0; i < 6; i++) { seq.push(v); v += (i % 2 === 0) ? a : -b; }
    } else if (k === 'square') {
      const s = Rnd.int(rng, 1, 6); for (let i = 0; i < 6; i++) seq.push((s + i) * (s + i));
    } else if (k === 'geo') {
      const f = Rnd.pick(rng, [2, 2, 3]), s = Rnd.int(rng, 1, f === 2 ? 6 : 3); let v = s;
      for (let i = 0; i < 6; i++) { seq.push(v); v *= f; }
    } else if (k === 'fib') {
      let a = Rnd.int(rng, 1, 5), b = Rnd.int(rng, a, a + 5);
      for (let i = 0; i < 6; i++) { seq.push(a); [a, b] = [b, a + b]; }
    } else {
      let v = Rnd.int(rng, 1, 10), step = Rnd.int(rng, 1, 4);
      for (let i = 0; i < 6; i++) { seq.push(v); v += step; step += Rnd.int(rng, 1, 2); }
    }
    const ans = seq.pop();
    return { text: seq.map(fmt).join(',  ') + ',  ?', answer: ans, kind: 'sequence' };
  }

  function task(rng, d) {
    const opts = [{ f: basic, w: 3 }];
    if (d > 0.1) opts.push({ f: missing, w: 2 });
    if (d > 0.15) opts.push({ f: chain, w: 1 + 3 * d });
    if (d > 0.22) opts.push({ f: sequence, w: 1 + 2 * d });
    return Rnd.weighted(rng, opts, o => o.w).f(rng, d);
  }

  function generate(rng, d) {
    const tasks = [];
    const seen = new Set();
    while (tasks.length < 5) {
      const t = task(rng, d);
      if (seen.has(t.text) && seen.size < 50) continue;
      seen.add(t.text); tasks.push(t);
    }
    return { type: 'math', tasks };
  }
  return { generate, fmt };
})();

// ---------- SUDOKU ----------
const SudokuGen = (() => {
  function dims(N) { return N === 4 ? [2, 2] : N === 6 ? [2, 3] : [3, 3]; }
  function peers(N) {
    const [br, bc] = dims(N), P = [];
    for (let i = 0; i < N * N; i++) {
      const r = Math.floor(i / N), c = i % N, s = new Set();
      for (let k = 0; k < N; k++) { s.add(r * N + k); s.add(k * N + c); }
      const r0 = Math.floor(r / br) * br, c0 = Math.floor(c / bc) * bc;
      for (let rr = r0; rr < r0 + br; rr++) for (let cc = c0; cc < c0 + bc; cc++) s.add(rr * N + cc);
      s.delete(i); P.push([...s]);
    }
    return P;
  }
  const peerCache = {};
  function getPeers(N) { return peerCache[N] || (peerCache[N] = peers(N)); }

  function candidates(g, i, N, P) {
    const used = new Array(N + 1).fill(false);
    for (const p of P[i]) used[g[p]] = true;
    const out = []; for (let v = 1; v <= N; v++) if (!used[v]) out.push(v);
    return out;
  }
  function fill(g, N, P, rng) {
    let best = -1, bestC = null;
    for (let i = 0; i < g.length; i++) if (!g[i]) {
      const c = candidates(g, i, N, P);
      if (c.length === 0) return false;
      if (!bestC || c.length < bestC.length) { best = i; bestC = c; }
    }
    if (best < 0) return true;
    for (const v of Rnd.shuffle(rng, bestC)) { g[best] = v; if (fill(g, N, P, rng)) return true; }
    g[best] = 0; return false;
  }
  function count(g, N, P, limit) {
    let best = -1, bestC = null;
    for (let i = 0; i < g.length; i++) if (!g[i]) {
      const c = candidates(g, i, N, P);
      if (c.length === 0) return 0;
      if (!bestC || c.length < bestC.length) { best = i; bestC = c; if (c.length === 1) break; }
    }
    if (best < 0) return 1;
    let n = 0;
    for (const v of bestC) { g[best] = v; n += count(g, N, P, limit - n); if (n >= limit) break; }
    g[best] = 0; return n;
  }
  function generate(rng, d) {
    let N, t;
    if (d < 0.2) { N = 4; t = d / 0.2; }
    else if (d < 0.48) { N = 6; t = (d - 0.2) / 0.28; }
    else { N = 9; t = Math.min(1, (d - 0.48) / 0.45); }
    const P = getPeers(N);
    const sol = new Array(N * N).fill(0);
    fill(sol, N, P, rng);
    const target = N === 4 ? Math.round(8 - 3 * t) : N === 6 ? Math.round(19 - 6 * t) : Math.round(38 - 10 * t);
    const puz = sol.slice();
    let clues = N * N;
    for (const i of Rnd.shuffle(rng, [...Array(N * N).keys()])) {
      if (clues <= target) break;
      const v = puz[i]; puz[i] = 0;
      if (count(puz.slice(), N, P, 2) !== 1) puz[i] = v; else clues--;
    }
    const [br, bc] = dims(N);
    return { type: 'sudoku', N, br, bc, puzzle: puz, solution: sol };
  }
  function countSolutions(puz, N) { return count(puz.slice(), N, getPeers(N), 2); }
  return { generate, countSolutions, dims };
})();

// ---------- FORM-PUZZLE (Polyominos) ----------
const ShapeGen = (() => {
  const key = (r, c) => r + ',' + c;
  const NB = [[1, 0], [-1, 0], [0, 1], [0, -1]];
  function normalize(cells) {
    let mr = Infinity, mc = Infinity;
    for (const [r, c] of cells) { mr = Math.min(mr, r); mc = Math.min(mc, c); }
    return cells.map(([r, c]) => [r - mr, c - mc]).sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  }
  function rotate(cells) { return normalize(cells.map(([r, c]) => [c, -r])); }
  function flip(cells) { return normalize(cells.map(([r, c]) => [r, -c])); }
  function sig(cells) { return normalize(cells).map(x => x.join(',')).join(';'); }

  function generate(rng, d) {
    const K = Math.min(9, 3 + Math.floor(d * 6.6));
    const irr = Math.min(1, d * 1.15);
    const maxDim = K <= 4 ? 6 : K <= 6 ? 7 : 8;
    for (let attempt = 0; attempt < 200; attempt++) {
      const shape = new Map();  // key -> piece index
      const pieces = [];
      const inB = (r, c) => r >= 0 && c >= 0 && r < maxDim && c < maxDim;
      const nbIn = (r, c, extra) => NB.reduce((n, [dr, dc]) => n + ((shape.has(key(r + dr, c + dc)) || (extra && extra.has(key(r + dr, c + dc)))) ? 1 : 0), 0);
      const wfn = (n) => irr < 0.5 ? Math.pow(n + 0.3, 2.2 - 3 * irr) : Math.pow(n + 0.3, -(irr - 0.5) * 2.4) ;
      let ok = true;
      for (let p = 0; p < K && ok; p++) {
        const size = Rnd.weighted(rng, [3, 4, 5], s => s === 3 ? 1.6 - d * 1.2 : s === 4 ? 2 : 0.3 + d * 1.5);
        let placed = false;
        for (let tries = 0; tries < 30 && !placed; tries++) {
          let seed;
          if (shape.size === 0) seed = [Math.floor(maxDim / 2), Math.floor(maxDim / 2)];
          else {
            const front = [];
            for (const k of shape.keys()) {
              const [r, c] = k.split(',').map(Number);
              for (const [dr, dc] of NB) { const rr = r + dr, cc = c + dc; if (inB(rr, cc) && !shape.has(key(rr, cc))) front.push([rr, cc]); }
            }
            if (!front.length) break;
            seed = Rnd.weighted(rng, front, ([r, c]) => wfn(nbIn(r, c)));
          }
          const piece = new Map([[key(...seed), seed]]);
          while (piece.size < size) {
            const fr = [];
            for (const [r, c] of piece.values())
              for (const [dr, dc] of NB) {
                const rr = r + dr, cc = c + dc, k = key(rr, cc);
                if (inB(rr, cc) && !shape.has(k) && !piece.has(k)) fr.push([rr, cc]);
              }
            if (!fr.length) break;
            const pickC = Rnd.weighted(rng, fr, ([r, c]) => wfn(nbIn(r, c, piece)));
            piece.set(key(...pickC), pickC);
          }
          if (piece.size === size) {
            for (const k of piece.keys()) shape.set(k, p);
            pieces.push([...piece.values()]);
            placed = true;
          }
        }
        if (!placed) ok = false;
      }
      if (!ok) continue;
      // Keine identischen Doppelteile bei wenigen Teilen (wirkt sonst langweilig)
      const sigs = pieces.map(sig);
      if (K <= 5 && new Set(sigs).size < sigs.length) continue;
      let mr = Infinity, mc = Infinity, Mr = -1, Mc = -1;
      for (const k of shape.keys()) { const [r, c] = k.split(',').map(Number); mr = Math.min(mr, r); mc = Math.min(mc, c); Mr = Math.max(Mr, r); Mc = Math.max(Mc, c); }
      const H = Mr - mr + 1, W = Mc - mc + 1;
      const cells = [...shape.keys()].map(k => { const [r, c] = k.split(',').map(Number); return [r - mr, c - mc]; });
      const solution = pieces.map(pc => pc.map(([r, c]) => [r - mr, c - mc]));
      const scrambled = pieces.map(pc => {
        let s = normalize(pc);
        const rots = Rnd.int(rng, 0, 3);
        for (let i = 0; i < rots; i++) s = rotate(s);
        return s;
      });
      const order = Rnd.shuffle(rng, scrambled.map((_, i) => i));
      return { type: 'shape', W, H, cells, pieces: order.map(i => scrambled[i]), solution };
    }
    throw new Error('ShapeGen failed');
  }
  return { generate, rotate, flip, normalize, sig };
})();

// ---------- SCHACH-ENGINE ----------
const Chess = (() => {
  const KN = [[-2, -1], [-2, 1], [-1, -2], [-1, 2], [1, -2], [1, 2], [2, -1], [2, 1]];
  const KG = [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]];
  const DIAG = [[-1, -1], [-1, 1], [1, -1], [1, 1]], ORTH = [[-1, 0], [1, 0], [0, -1], [0, 1]], ALL = DIAG.concat(ORTH);
  const VAL = { p: 100, n: 310, b: 330, r: 500, q: 900, k: 0 };
  const MATE = 100000;
  const colorOf = p => p ? (p < 'a' ? 'w' : 'b') : null;
  const typeOf = p => p.toLowerCase();
  const other = c => c === 'w' ? 'b' : 'w';
  const FILES = 'abcdefgh';
  const sqName = i => FILES[i & 7] + (8 - (i >> 3));
  const sqIdx = s => (8 - +s[1]) * 8 + FILES.indexOf(s[0]);

  function parseFEN(fen) {
    const [pl, turn] = fen.trim().split(/\s+/);
    const b = new Array(64).fill(null); let r = 0, c = 0;
    for (const ch of pl) {
      if (ch === '/') { r++; c = 0; }
      else if (ch >= '1' && ch <= '8') c += +ch;
      else { b[r * 8 + c] = ch; c++; }
    }
    return { b, turn: turn === 'b' ? 'b' : 'w' };
  }
  function toFEN(pos) {
    let s = '';
    for (let r = 0; r < 8; r++) {
      let e = 0;
      for (let c = 0; c < 8; c++) { const p = pos.b[r * 8 + c]; if (!p) e++; else { if (e) { s += e; e = 0; } s += p; } }
      if (e) s += e; if (r < 7) s += '/';
    }
    return s + ' ' + pos.turn + ' - - 0 1';
  }
  function attacked(b, sq, by) {
    const r = sq >> 3, c = sq & 7;
    if (by === 'w') {
      if (r < 7) { if (c > 0 && b[sq + 7] === 'P') return true; if (c < 7 && b[sq + 9] === 'P') return true; }
    } else {
      if (r > 0) { if (c > 0 && b[sq - 9] === 'p') return true; if (c < 7 && b[sq - 7] === 'p') return true; }
    }
    const w = by === 'w';
    const N = w ? 'N' : 'n', K = w ? 'K' : 'k', B = w ? 'B' : 'b', R = w ? 'R' : 'r', Q = w ? 'Q' : 'q';
    for (const [dr, dc] of KN) { const rr = r + dr, cc = c + dc; if (rr >= 0 && rr < 8 && cc >= 0 && cc < 8 && b[rr * 8 + cc] === N) return true; }
    for (const [dr, dc] of KG) { const rr = r + dr, cc = c + dc; if (rr >= 0 && rr < 8 && cc >= 0 && cc < 8 && b[rr * 8 + cc] === K) return true; }
    for (const [dr, dc] of DIAG) {
      let rr = r + dr, cc = c + dc;
      while (rr >= 0 && rr < 8 && cc >= 0 && cc < 8) { const p = b[rr * 8 + cc]; if (p) { if (p === B || p === Q) return true; break; } rr += dr; cc += dc; }
    }
    for (const [dr, dc] of ORTH) {
      let rr = r + dr, cc = c + dc;
      while (rr >= 0 && rr < 8 && cc >= 0 && cc < 8) { const p = b[rr * 8 + cc]; if (p) { if (p === R || p === Q) return true; break; } rr += dr; cc += dc; }
    }
    return false;
  }
  const kingSq = (b, col) => b.indexOf(col === 'w' ? 'K' : 'k');
  function inCheck(pos) { const k = kingSq(pos.b, pos.turn); return k >= 0 && attacked(pos.b, k, other(pos.turn)); }

  function pseudo(pos) {
    const { b, turn } = pos, out = [];
    for (let sq = 0; sq < 64; sq++) {
      const p = b[sq]; if (!p || colorOf(p) !== turn) continue;
      const r = sq >> 3, c = sq & 7, t = typeOf(p);
      const tryTo = (rr, cc) => {
        if (rr < 0 || rr > 7 || cc < 0 || cc > 7) return false;
        const to = rr * 8 + cc, q = b[to];
        if (q && colorOf(q) === turn) return false;
        out.push({ f: sq, t: to, promo: null, cap: q });
        return !q;
      };
      if (t === 'p') {
        const dir = turn === 'w' ? -1 : 1, start = turn === 'w' ? 6 : 1, last = turn === 'w' ? 0 : 7;
        const push = (to) => {
          if ((to >> 3) === last) { for (const pr of 'qnrb') out.push({ f: sq, t: to, promo: pr, cap: b[to] }); }
          else out.push({ f: sq, t: to, promo: null, cap: b[to] });
        };
        const r1 = r + dir;
        if (r1 >= 0 && r1 < 8) {
          if (!b[r1 * 8 + c]) { push(r1 * 8 + c); if (r === start && !b[(r + 2 * dir) * 8 + c]) push((r + 2 * dir) * 8 + c); }
          for (const dc of [-1, 1]) { const cc = c + dc; if (cc < 0 || cc > 7) continue; const q = b[r1 * 8 + cc]; if (q && colorOf(q) !== turn) push(r1 * 8 + cc); }
        }
      } else if (t === 'n') { for (const [dr, dc] of KN) tryTo(r + dr, c + dc); }
      else if (t === 'k') { for (const [dr, dc] of KG) tryTo(r + dr, c + dc); }
      else {
        const dirs = t === 'b' ? DIAG : t === 'r' ? ORTH : ALL;
        for (const [dr, dc] of dirs) { let rr = r + dr, cc = c + dc; while (tryTo(rr, cc)) { rr += dr; cc += dc; } }
      }
    }
    return out;
  }
  function make(pos, m) {
    const b = pos.b.slice(); const p = b[m.f];
    b[m.t] = m.promo ? (pos.turn === 'w' ? m.promo.toUpperCase() : m.promo) : p;
    b[m.f] = null;
    return { b, turn: other(pos.turn) };
  }
  function legal(pos) {
    const res = [];
    for (const m of pseudo(pos)) {
      const q = make(pos, m); const k = kingSq(q.b, pos.turn);
      if (k >= 0 && !attacked(q.b, k, q.turn)) res.push(m);
    }
    return res;
  }
  function isMate(pos) { return inCheck(pos) && legal(pos).length === 0; }
  function isStalemate(pos) { return !inCheck(pos) && legal(pos).length === 0; }
  const uci = m => sqName(m.f) + sqName(m.t) + (m.promo || '');
  function findMove(pos, u) { return legal(pos).find(m => uci(m) === u) || null; }

  // ----- Mattsuche -----
  function orderForAttack(pos, ms) {
    const scored = ms.map(m => { const q = make(pos, m); return { m, q, s: (inCheck(q) ? 1000 : 0) + (m.cap ? VAL[typeOf(m.cap)] : 0) + (m.promo === 'q' ? 800 : 0) }; });
    scored.sort((a, b) => b.s - a.s);
    return scored;
  }
  // Kann die Seite am Zug in <= n Zügen mattsetzen?
  function mates(pos, n) {
    if (n <= 0) return false;
    const ms = legal(pos);
    if (n === 1) {
      for (const m of ms) { const q = make(pos, m); if (inCheck(q) && legal(q).length === 0) return true; }
      return false;
    }
    for (const { q } of orderForAttack(pos, ms)) if (forcedLoss(q, n - 1)) return true;
    return false;
  }
  // Wird die Seite am Zug spätestens nach n gegnerischen Zügen mattgesetzt?
  function forcedLoss(pos, n) {
    const ms = legal(pos);
    if (ms.length === 0) return inCheck(pos);
    if (n <= 0) return false;
    for (const m of ms) if (!mates(make(pos, m), n)) return false;
    return true;
  }
  function mateSolutions(pos, n) {
    return legal(pos).filter(m => forcedLoss(make(pos, m), n - 1));
  }
  // Beste Verteidigung: Zug, nach dem der Angreifer am längsten braucht
  function bestDefense(pos, n) {
    const ms = legal(pos);
    if (!ms.length) return null;
    let best = null, bestLen = -1;
    for (const m of ms) {
      const q = make(pos, m);
      // Alle Züge verlieren spätestens in n – nur kürzere Matts prüfen (spart Rechenzeit)
      let len = n;
      for (let k = 1; k < n; k++) if (mates(q, k)) { len = k; break; }
      const sc = len * 10 + (m.cap ? 1 : 0);
      if (sc > bestLen) { bestLen = sc; best = m; }
    }
    return best;
  }

  // ----- Materialsuche (für Taktik) -----
  function evalMat(pos) {
    let s = 0;
    for (const p of pos.b) if (p) s += (colorOf(p) === pos.turn ? 1 : -1) * VAL[typeOf(p)];
    return s;
  }
  function mvv(m) { return (m.cap ? VAL[typeOf(m.cap)] * 10 : 0) + (m.promo === 'q' ? 8000 : 0); }
  function qs(pos, alpha, beta, depth) {
    const chk = inCheck(pos);
    const ms = legal(pos);
    if (!ms.length) return chk ? -MATE + 50 : 0;
    let stand = evalMat(pos);
    if (!chk) {
      if (stand >= beta) return stand;
      if (stand > alpha) alpha = stand;
    }
    if (depth > 5) return stand;
    const cand = chk ? ms : ms.filter(m => m.cap || m.promo === 'q');
    cand.sort((a, b) => mvv(b) - mvv(a));
    let best = chk ? -MATE : stand;
    for (const m of cand) {
      if (m.promo && m.promo !== 'q') continue;
      const sc = -qs(make(pos, m), -beta, -alpha, depth + 1);
      if (sc > best) best = sc;
      if (sc > alpha) alpha = sc;
      if (alpha >= beta) break;
    }
    return best;
  }
  function search(pos, depth, alpha, beta, ply) {
    if (depth <= 0) return qs(pos, alpha, beta, 0);
    const ms = legal(pos);
    if (!ms.length) return inCheck(pos) ? -(MATE - ply) : 0;
    ms.sort((a, b) => mvv(b) - mvv(a));
    let best = -Infinity;
    for (const m of ms) {
      if (m.promo && m.promo !== 'q' && m.promo !== 'n') continue;
      const sc = -search(make(pos, m), depth - 1, -beta, -alpha, ply + 1);
      if (sc > best) best = sc;
      if (sc > alpha) alpha = sc;
      if (alpha >= beta) break;
    }
    return best;
  }
  function rootScores(pos, depth) {
    const res = [];
    for (const m of legal(pos)) {
      if (m.promo && m.promo !== 'q' && m.promo !== 'n') continue;
      res.push({ m, s: -search(make(pos, m), depth - 1, -Infinity, Infinity, 1) });
    }
    res.sort((a, b) => b.s - a.s);
    return res;
  }

  // ----- Stellungsprüfung -----
  function validPosition(pos) {
    const b = pos.b;
    if (b.filter(p => p === 'K').length !== 1 || b.filter(p => p === 'k').length !== 1) return false;
    for (let c = 0; c < 8; c++) { if (b[c] && typeOf(b[c]) === 'p') return false; if (b[56 + c] && typeOf(b[56 + c]) === 'p') return false; }
    // Seite, die NICHT am Zug ist, darf nicht im Schach stehen
    const k = kingSq(b, other(pos.turn));
    if (attacked(b, k, pos.turn)) return false;
    return true;
  }
  function mirror(pos) { // Farben tauschen + Brett spiegeln
    const b = new Array(64).fill(null);
    for (let i = 0; i < 64; i++) {
      const p = pos.b[i]; if (!p) continue;
      const r = i >> 3, c = i & 7;
      b[(7 - r) * 8 + c] = p < 'a' ? p.toLowerCase() : p.toUpperCase();
    }
    return { b, turn: other(pos.turn) };
  }

  // ----- Matt-Generator (dünn besetzte Stellungen) -----
  function randomMatePos(rng, n) {
    // Weiß greift an, Schwarz verteidigt; ggf. später gespiegelt
    for (let tries = 0; tries < 4000; tries++) {
      const b = new Array(64).fill(null);
      const free = i => !b[i];
      const put = (p, rMin, rMax, cMin = 0, cMax = 7) => {
        for (let k = 0; k < 40; k++) {
          const i = Rnd.int(rng, rMin, rMax) * 8 + Rnd.int(rng, cMin, cMax);
          if (free(i)) { b[i] = p; return i; }
        }
        return -1;
      };
      const bk = put('k', 0, 1);
      const bkc = bk & 7, bkr = bk >> 3;
      // Bauernschild vor dem schwarzen König
      const shield = Rnd.int(rng, 0, 3);
      for (let s = 0; s < shield; s++) {
        const c = Math.max(0, Math.min(7, bkc + Rnd.int(rng, -1, 1)));
        const r = Math.min(6, bkr + 1 + (rng() < 0.3 ? 1 : 0));
        if (free(r * 8 + c) && r >= 1) b[r * 8 + c] = 'p';
      }
      const defenders = Rnd.int(rng, 0, n >= 2 ? 3 : 2);
      for (let s = 0; s < defenders; s++) put(Rnd.pick(rng, ['r', 'n', 'b', 'p', 'q', 'r', 'b']), 0, 4);
      put('K', 5, 7);
      const wp = Rnd.int(rng, 0, 3);
      for (let s = 0; s < wp; s++) put('P', 2, 6);
      const att = Rnd.int(rng, 1, n === 1 ? 3 : 3);
      const pool = ['Q', 'R', 'R', 'B', 'N', 'N', 'B', 'Q'];
      for (let s = 0; s < att; s++) put(Rnd.pick(rng, pool), 0, 7);
      if (b.some((p, i) => p === 'p' && (i >> 3) === 7)) continue;
      const pos = { b, turn: 'w' };
      if (!validPosition(pos)) continue;
      if (inCheck(pos)) continue;
      // Material darf nicht absurd sein
      let wm = 0, bm = 0; for (const p of b) if (p && p.toLowerCase() !== 'k') { if (p < 'a') wm += VAL[typeOf(p)]; else bm += VAL[typeOf(p)]; }
      if (wm > 2400) continue;
      // Kürzere Matts ausschließen, genau eine Lösung (Umwandlungen zusammengefasst)
      let shorter = false;
      for (let k = 1; k < n; k++) if (mates(pos, k)) { shorter = true; break; }
      if (shorter) continue;
      const sols = mateSolutions(pos, n);
      const keys = new Set(sols.map(m => m.f + '-' + m.t));
      if (keys.size !== 1) continue;
      // Verteidiger soll noch Züge haben und nicht völlig erstarrt sein
      if (legal({ b, turn: 'b' }).length < 2) continue;
      const sol = sols.find(m => m.promo === 'q') || sols[0];
      return { pos, sol };
    }
    return null;
  }
  function generateMate1(rng) {
    const r = randomMatePos(rng, 1);
    if (!r) return null;
    let pos = r.pos, sol = r.sol;
    if (rng() < 0.5) {
      pos = mirror(pos);
      sol = { f: (7 - (sol.f >> 3)) * 8 + (sol.f & 7), t: (7 - (sol.t >> 3)) * 8 + (sol.t & 7), promo: sol.promo };
    }
    return { kind: 'mate', n: 1, fen: toFEN(pos), sol: uci(sol) };
  }

  return {
    parseFEN, toFEN, legal, make, inCheck, isMate, isStalemate, uci, findMove, sqName, sqIdx, colorOf, typeOf, other,
    mates, forcedLoss, mateSolutions, bestDefense, evalMat, qs, search, rootScores, validPosition, mirror,
    randomMatePos, generateMate1, VAL, MATE
  };
})();

if (typeof module !== 'undefined') module.exports = { mulberry32, hashSeed, Rnd, MathGen, SudokuGen, ShapeGen, Chess };
