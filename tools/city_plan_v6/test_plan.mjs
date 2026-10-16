import { stats, LOTS, BLOCKS, LANDMARKS } from './src/plan.js';
console.log(stats());
const byD = {}; for (const l of LOTS) byD[l.district] = (byD[l.district]||0)+1; console.log(byD);
console.log(LOTS.filter(l=>l.label).map(l=>l.label).join(','));
for (const b of BLOCKS) { const n = LOTS.filter(l=>l.block===b.id).length; if (b.use==='build' && n===0) console.log('EMPTY', b.id, b.district, b.landmarks); }
