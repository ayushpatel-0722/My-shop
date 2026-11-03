import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, deleteDoc } from 'firebase/firestore';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const here = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(here, 'firestore.rules'), 'utf8');
const env = await initializeTestEnvironment({projectId:'demo-rules', firestore:{rules, host:'127.0.0.1', port:8085}});
const admin = () => env.authenticatedContext('boss', {role: 'admin'}).firestore();
const shopper = () => env.authenticatedContext('shopper').firestore();
const anon = () => env.unauthenticatedContext().firestore();
const lock = (db) => doc(db, 'storefront_config/lock');

await env.clearFirestore();
await env.withSecurityRulesDisabled(async ctx => {
  // A made-up value: only the shape matters to the rules.
  await setDoc(doc(ctx.firestore(), 'storefront_config/lock'), {passwordHash: 'pbkdf2-sha256$1$c2FsdA==$aGFzaA=='});
});

const results = [];
async function check(name, p, expectOk) {
  try { if (expectOk) await assertSucceeds(p); else await assertFails(p); results.push(['PASS', name]); }
  catch (e) { results.push(['FAIL', name, String(e.message).slice(0, 120)]); }
}

await check('admin reads the lock setting', getDoc(lock(admin())), true);
await check('shopper cannot read it', getDoc(lock(shopper())), false);
await check('guest cannot read it', getDoc(lock(anon())), false);
await check('admin cannot overwrite it from the app', setDoc(lock(admin()), {passwordHash: 'x'}), false);
await check('admin cannot delete it from the app', deleteDoc(lock(admin())), false);
await check('shopper cannot write it', setDoc(lock(shopper()), {passwordHash: 'x'}), false);
await check('guest cannot write it', setDoc(lock(anon()), {passwordHash: 'x'}), false);

await env.cleanup();
for (const r of results) console.log(r.join(' | '));
if (results.some(r => r[0] === 'FAIL')) process.exit(1);
