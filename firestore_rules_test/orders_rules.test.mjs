import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, getDoc } from 'firebase/firestore';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const here = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(here, 'firestore.rules'), 'utf8');
const env = await initializeTestEnvironment({projectId:'demo-rules', firestore:{rules, host:'127.0.0.1', port:8085}});
const C='comp1';
await env.withSecurityRulesDisabled(async ctx=>{
  const db=ctx.firestore();
  await setDoc(doc(db,`companies/${C}`),{name:'X'});
  await setDoc(doc(db,`companies/${C}/employees/pk`),{id:'pk',companyId:C,permissions:{canPack:true,canDispatch:false}});
  await setDoc(doc(db,`companies/${C}/employees/dp`),{id:'dp',companyId:C,permissions:{canPack:false,canDispatch:true}});
  await setDoc(doc(db,`companies/${C}/employees/none`),{id:'none',companyId:C,permissions:{canPack:false,canDispatch:false}});
  await setDoc(doc(db,`companies/${C}/employees/legacy`),{id:'legacy',companyId:C});
  await setDoc(doc(db,`companies/${C}/employees/mg`),{id:'mg',companyId:C,permissions:{canPack:true,canDispatch:true,canManageOrders:true}});
  await setDoc(doc(db,`companies/${C}/reviews/o_deliv_p1`),{userId:'cust',orderId:'o_deliv',companyId:C,rating:5});
  await setDoc(doc(db,`companies/${C}/admins/ad`),{id:'ad',companyId:C});
  for (const [id,st] of [['o_conf','confirmed'],['o_conf2','confirmed'],['o_conf3','confirmed'],['o_conf4','confirmed'],['o_pack','packing'],['o_ready','ready'],['o_way','on_the_way'],['o_pend','pending'],['o_pend2','pending'],['o_pend3','pending'],['o_deliv','delivered'],['o_deliv2','delivered']])
    await setDoc(doc(db,`companies/${C}/orders/${id}`),{userId:'cust',companyId:C,orderStatus:st,paymentStatus:'pending',statusHistory:[],items:[],totalAmount:10});
});
const as=(uid,claims={})=>env.authenticatedContext(uid,claims).firestore();
const upd=(db,id,data)=>updateDoc(doc(db,`companies/${C}/orders/${id}`),data);
const now='2026-01-01T00:00:00';
const results=[];
async function check(name, p, expectOk){
  try{ if(expectOk) await assertSucceeds(p); else await assertFails(p); results.push(['PASS',name]);}
  catch(e){ results.push(['FAIL',name, String(e.message).slice(0,120)]);}
}
const step=(status,extra={})=>({orderStatus:status,updatedAt:now,statusHistory:[{status,note:'x',timestamp:now}],...extra});
await check('packer: confirmed->packing', upd(as('pk'),'o_conf',step('packing')), true);
await check('packer: packing->ready', upd(as('pk'),'o_pack',step('ready')), true);
await check('packer: ready->on_the_way DENIED', upd(as('pk'),'o_ready',step('on_the_way')), false);
await check('packer: pending->confirmed DENIED', upd(as('pk'),'o_pend2',step('confirmed')), false);
await check('packer: cancel DENIED', upd(as('pk'),'o_pend',step('cancelled')), false);
await check('packer: change payment DENIED', upd(as('pk'),'o_pend',{paymentStatus:'done'}), false);
await check('packer: assign DENIED', upd(as('pk'),'o_pend',{assignedEmployeeId:'pk'}), false);
await check('dispatcher: ready->on_the_way', upd(as('dp'),'o_ready',step('on_the_way')), true);
await check('dispatcher: on_the_way->delivered', upd(as('dp'),'o_way',step('delivered')), true);
await check('dispatcher: delivered->completed DENIED', upd(as('dp'),'o_deliv2',step('completed')), false);
await check('dispatcher: confirmed->packing DENIED', upd(as('dp'),'o_conf2',step('packing')), false);
await check('dispatcher: pending->confirmed DENIED', upd(as('dp'),'o_pend3',step('confirmed')), false);
await check('no-permission: confirmed->packing DENIED', upd(as('none'),'o_conf3',step('packing')), false);
await check('legacy (no perms): confirmed->packing', upd(as('legacy'),'o_conf4',step('packing')), true);
await check('manager: pending->confirmed', upd(as('mg'),'o_pend2',step('confirmed')), true);
await check('manager: cancel pending', upd(as('mg'),'o_pend3',step('cancelled')), true);
await check('customer: delivered->completed with own review', upd(as('cust'),'o_deliv',{orderStatus:'completed',reviewId:'o_deliv_p1',updatedAt:now,statusHistory:[{status:'completed',note:'x',timestamp:now}]}), true);
await check('customer: delivered->completed w/o review DENIED', upd(as('cust'),'o_deliv2',{orderStatus:'completed',reviewId:'nope',updatedAt:now,statusHistory:[]}), false);
await check('admin: any step', upd(as('ad'),'o_pack',step('ready')), true);
await check('outsider: DENIED', upd(as('stranger'),'o_conf2',step('packing')), false);
await check('employee read orders', getDoc(doc(as('pk'),`companies/${C}/orders/o_conf`)), true);
await env.cleanup();
for (const r of results) console.log(r.join(' | '));
if (results.some(r => r[0] === 'FAIL')) process.exit(1);
