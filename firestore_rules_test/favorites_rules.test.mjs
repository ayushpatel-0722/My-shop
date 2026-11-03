import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, deleteDoc } from 'firebase/firestore';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const here = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(here, 'firestore.rules'), 'utf8');
const env = await initializeTestEnvironment({projectId:'demo-rules', firestore:{rules, host:'127.0.0.1', port:8085}});
const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();
const items = (n) => Array.from({length:n}, (_, i) => ({productId:`p${i}`, companyId:'c1', addedAt:'2026-01-01T00:00:00'}));
const body = (uid, n) => ({userId:uid, items:items(n), updatedAt:'2026-01-01T00:00:00'});
const ref = (db, uid) => doc(db, `favorites/${uid}`);

await env.clearFirestore();
await env.withSecurityRulesDisabled(async ctx => {
  await setDoc(doc(ctx.firestore(), 'favorites/alice'), body('alice', 3));
});

const results = [];
async function check(name, p, expectOk) {
  try { if (expectOk) await assertSucceeds(p); else await assertFails(p); results.push(['PASS', name]); }
  catch (e) { results.push(['FAIL', name, String(e.message).slice(0, 120)]); }
}

await check('owner reads own favourites', getDoc(ref(as('alice'), 'alice')), true);
await check('other user cannot read', getDoc(ref(as('bob'), 'alice')), false);
await check('guest cannot read', getDoc(ref(anon(), 'alice')), false);
await check('owner writes 25 items', setDoc(ref(as('alice'), 'alice'), body('alice', 25)), true);
await check('owner cannot write 26 items', setDoc(ref(as('alice'), 'alice'), body('alice', 26)), false);
await check('owner creates own doc', setDoc(ref(as('bob'), 'bob'), body('bob', 1)), true);
await check("cannot write another user's doc", setDoc(ref(as('bob'), 'alice'), body('alice', 1)), false);
await check('cannot claim another userId in own doc', setDoc(ref(as('bob'), 'bob'), body('alice', 1)), false);
await check('items must be a list', setDoc(ref(as('bob'), 'bob'), {userId:'bob', items:'x'}), false);
await check('guest cannot write', setDoc(ref(anon(), 'alice'), body('alice', 1)), false);
await check('other user cannot delete', deleteDoc(ref(as('bob'), 'alice')), false);
await check('owner deletes own doc', deleteDoc(ref(as('bob'), 'bob')), true);

await env.cleanup();
for (const r of results) console.log(r.join(' | '));
if (results.some(r => r[0] === 'FAIL')) process.exit(1);
