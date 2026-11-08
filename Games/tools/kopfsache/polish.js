const { Chess } = require('./logic.js');
const fs = require('fs');
const src = fs.readFileSync('bank.js', 'utf8');
const bank = JSON.parse(src.slice(src.indexOf('['), src.lastIndexOf(']') + 1));
let changed = 0;
for (const e of bank) {
  if (e.k !== 't') continue;
  let pos = Chess.parseFEN(e.f);
  pos = Chess.make(pos, Chess.findMove(pos, e.l[0]));
  pos = Chess.make(pos, Chess.findMove(pos, e.l[1]));
  const rs = Chess.rootScores(pos, 2);
  const best = rs[0].s;
  const cands = rs.filter(x => x.s >= best - 30);
  const val = x => (x.m.cap ? Chess.VAL[x.m.cap.toLowerCase()] : 0) + (Chess.isMate(Chess.make(pos, x.m)) ? 10000 : 0);
  cands.sort((a, b) => val(b) - val(a));
  const u = Chess.uci(cands[0].m);
  if (u !== e.l[2]) { changed++; e.l[2] = u; }
}
fs.writeFileSync('bank.js', 'const CHESS_BANK = ' + JSON.stringify(bank) + ';\n');
console.log('tactics', bank.filter(e => e.k === 't').length, 'follow-ups changed', changed);
const ex = bank.find(e => e.f.startsWith('1rbqk1nr/1p1p3p')); console.log(ex && ex.l);
