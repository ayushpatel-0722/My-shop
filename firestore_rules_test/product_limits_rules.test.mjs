import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc } from 'firebase/firestore';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const here = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(here, 'firestore.rules'), 'utf8');
const env = await initializeTestEnvironment({projectId:'demo-rules', firestore:{rules, host:'127.0.0.1', port:8085}});
const C = 'shop1';
await env.clearFirestore();
await env.withSecurityRulesDisabled(async ctx => {
  const db = ctx.firestore();
  await setDoc(doc(db, `companies/${C}`), {name: 'Shop', max_products: 50});
  await setDoc(doc(db, `companies/${C}/admins/boss`), {id: 'boss', companyId: C});
});
const boss = () => env.authenticatedContext('boss').firestore();
const company = (db) => doc(db, `companies/${C}`);

const results = [];
async function check(name, p, expectOk) {
  try { if (expectOk) await assertSucceeds(p); else await assertFails(p); results.push(['PASS', name]); }
  catch (e) { results.push(['FAIL', name, String(e.message).slice(0, 120)]); }
}

await check('shop admin can edit other company fields', updateDoc(company(boss()), {details: 'new'}), true);
await check('shop admin keeps max_products unchanged', updateDoc(company(boss()), {details: 'again', max_products: 50}), true);
await check('shop admin cannot raise max_products', updateDoc(company(boss()), {max_products: 5000}), false);
await check('shop admin cannot remove max_products', updateDoc(company(boss()), {max_products: null}), false);
await check('shop admin cannot change its plan', updateDoc(company(boss()), {plan: 'diamond'}), false);
await check('a new shop cannot start with its own plan',
  setDoc(doc(env.authenticatedContext('newbie3').firestore(), 'companies/fresh3'),
    {name: 'Fresh', companyPassword: 'x', plan: 'diamond'}), false);
await check('shop admin cannot add the plan on a shop without one',
  (async () => {
    await env.withSecurityRulesDisabled(async ctx => setDoc(doc(ctx.firestore(), 'companies/nolimit'), {name: 'N'}));
    await updateDoc(doc(boss(), 'companies/nolimit'), {max_products: 999});
  })(), false);
await check('a new shop cannot start with its own max_products',
  setDoc(doc(env.authenticatedContext('newbie').firestore(), 'companies/fresh'),
    {name: 'Fresh', companyPassword: 'x', max_products: 100000}), false);
await check('a new shop without max_products is created',
  setDoc(doc(env.authenticatedContext('newbie2').firestore(), 'companies/fresh2'),
    {name: 'Fresh', companyPassword: 'x'}), true);

await env.cleanup();
for (const r of results) console.log(r.join(' | '));
if (results.some(r => r[0] === 'FAIL')) process.exit(1);
