const { Chess, mulberry32, Rnd } = require('./logic.js');
const fs = require('fs');
const [,, kind, count, seedStart] = process.argv;
const target = +count; let seed = +seedStart; const out = [];
const t0 = Date.now();
function mirrorMove(u){ const f=s=>s[0]+(9-+s[1]); return f(u.slice(0,2))+f(u.slice(2,4))+u.slice(4); }
if (kind === 'mate2' || kind === 'mate3') {
  const n = kind === 'mate2' ? 2 : 3;
  while (out.length < target) {
    const rng = mulberry32(seed++);
    const r = Chess.randomMatePos(rng, n);
    if (!r) continue;
    let fen = Chess.toFEN(r.pos), sol = Chess.uci(r.sol);
    if (rng() < 0.5) { fen = Chess.toFEN(Chess.mirror(r.pos)); sol = mirrorMove(sol); }
    out.push({ k: 'm' + n, f: fen.split(' ').slice(0,2).join(' '), s: sol });
    process.stderr.write(`${kind} ${out.length} (${((Date.now()-t0)/1000)|0}s)\n`);
  }
} else if (kind === 'tactic') {
  // Selbstspiel mit Rauschen, Stellungen auf Taktiken prüfen
  while (out.length < target) {
    const rng = mulberry32(seed++);
    let pos = Chess.parseFEN('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w');
    const plies = Rnd.int(rng, 16, 70);
    let alive = true;
    for (let i = 0; i < plies; i++) {
      const ms = Chess.legal(pos); if (!ms.length) { alive = false; break; }
      let m;
      if (rng() < 0.12) m = Rnd.pick(rng, ms);
      else {
        const sc = ms.filter(x=>!x.promo||x.promo==='q').map(x => ({ x, s: -Chess.qs(Chess.make(pos, x), -1e9, 1e9, 0) + rng() * 60 }));
        sc.sort((a, b) => b.s - a.s); m = sc[Math.min(sc.length-1, Math.floor(rng()*rng()*3))].x;
      }
      pos = Chess.make(pos, m);
      if (i < 12) continue;
      if (i % 2 === 0 && rng() > 0.5) continue;
      // Kandidat prüfen
      if (Chess.inCheck(pos)) continue;
      const ms2 = Chess.legal(pos); if (ms2.length < 6) continue;
      const base = Chess.qs(pos, -1e9, 1e9, 0);
      if (Math.abs(base) > 400) continue; // Stellung schon entschieden
      const rs = Chess.rootScores(pos, 3);
      if (rs.length < 2) continue;
      const best = rs[0], second = rs[1];
      if (best.s > 50000) continue; // Matt -> eigene Kategorie
      if (best.s - base < 250 || best.s - second.s < 220) continue;
      // Lösung soll kein simples Schlagen einer ungedeckten Figur sein (qs würde das finden) -> base filtert
      const q1 = Chess.make(pos, best.m);
      const def = Chess.rootScores(q1, 2)[0]; if (!def) continue;
      const q2 = Chess.make(q1, def.m);
      const fol = Chess.rootScores(q2, 2); if (!fol.length) continue;
      if (fol.length > 1 && fol[0].s - fol[1].s < 40 && !(fol[0].m.cap)) {} // ok, mehrere Fortsetzungen erlaubt
      out.push({ k: 't', f: Chess.toFEN(pos).split(' ').slice(0,2).join(' '), l: [Chess.uci(best.m), Chess.uci(def.m), Chess.uci(fol[0].m)], g: best.s - base });
      process.stderr.write(`tactic ${out.length} seed ${seed} (${((Date.now()-t0)/1000)|0}s)\n`);
      break; // eine Taktik pro Partie
    }
  }
} else if (kind === 'mate1') {
  while (out.length < target) {
    const rng = mulberry32(seed++);
    const r = Chess.generateMate1(rng); if (r) out.push({ k: 'm1', f: r.fen.split(' ').slice(0,2).join(' '), s: r.sol });
  }
}
fs.writeFileSync(process.argv[5] || `bank_${kind}.json`, JSON.stringify(out));
console.log(kind, out.length, 'done in', (Date.now()-t0)/1000, 's');
