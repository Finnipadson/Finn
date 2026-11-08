const { Chess } = require('./logic.js');
const fs=require('fs');
let bank=[];
for (const f of ['bank_mate1.json','bank_mate2.json','bank_mate3.json']) bank.push(...JSON.parse(fs.readFileSync(f)));
for (const f of fs.readdirSync('tac')) bank.push(...JSON.parse(fs.readFileSync('tac/'+f)));
const seen=new Set(); const good=[]; const bad={};
for (const e of bank){
  if(seen.has(e.f)) { bad.dup=(bad.dup||0)+1; continue; } seen.add(e.f);
  const pos=Chess.parseFEN(e.f);
  if(!Chess.validPosition(pos)) { bad.invalid=(bad.invalid||0)+1; continue; }
  if(e.k==='t'){
    const m1=Chess.findMove(pos,e.l[0]); if(!m1){bad.t=(bad.t||0)+1;continue;}
    const q1=Chess.make(pos,m1); const r=Chess.findMove(q1,e.l[1]); if(!r){bad.t=(bad.t||0)+1;continue;}
    const q2=Chess.make(q1,r); if(!Chess.findMove(q2,e.l[2])){bad.t=(bad.t||0)+1;continue;}
    good.push(e); continue;
  }
  const n=+e.k[1];
  let shorter=false; for(let k=1;k<n;k++) if(Chess.mates(pos,k)) shorter=true;
  const sols=Chess.mateSolutions(pos,n); const keys=new Set(sols.map(m=>m.f+'-'+m.t));
  if(shorter||keys.size!==1||!sols.some(m=>Chess.uci(m)===e.s)) { bad['m'+n]=(bad['m'+n]||0)+1; continue; }
  good.push(e);
}
const c={}; for(const e of good) c[e.k]=(c[e.k]||0)+1;
console.log('good', good.length, c, 'bad', bad);
fs.writeFileSync('bank.js', 'const CHESS_BANK = ' + JSON.stringify(good) + ';\n');
