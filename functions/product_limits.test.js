'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { limitsFor, limitsForCompany, enforce } = require('./product_limits');

const docs = (published, unpublished) => [
  ...Array.from({ length: published }, (_, i) => ({ id: `p${i}`, published: true })),
  ...Array.from({ length: unpublished }, (_, i) => ({ id: `u${i}`, published: false })),
];

test('limits come from max_products, +20% rounded down', () => {
  assert.deepStrictEqual(limitsFor(50), { max: 50, cap: 60 });
  assert.deepStrictEqual(limitsFor('25'), { max: 25, cap: 30 });
  assert.deepStrictEqual(limitsFor(33), { max: 33, cap: 39 });
  assert.strictEqual(limitsFor(undefined), null);
  assert.strictEqual(limitsFor(0), null);
  assert.strictEqual(limitsFor('abc'), null);
});

test('no limit set: nothing to enforce', () => {
  assert.strictEqual(
    enforce({ limits: null, docs: docs(500, 0), productId: 'p1', createdNow: true, wasPublished: false }),
    'none');
});

test('the 51st published product is unpublished', () => {
  const all = docs(51, 0); // p50 is the new one
  assert.strictEqual(
    enforce({ limits: limitsFor(50), docs: all, productId: 'p50', createdNow: true, wasPublished: false }),
    'unpublish');
});

test('the 50th is fine', () => {
  assert.strictEqual(
    enforce({ limits: limitsFor(50), docs: docs(50, 0), productId: 'p49', createdNow: true, wasPublished: false }),
    'none');
});

test('products 51-60 may exist unpublished, the 61st is deleted', () => {
  assert.strictEqual(
    enforce({ limits: limitsFor(50), docs: docs(50, 10), productId: 'u9', createdNow: true, wasPublished: false }),
    'none');
  assert.strictEqual(
    enforce({ limits: limitsFor(50), docs: docs(50, 11), productId: 'u10', createdNow: true, wasPublished: false }),
    'delete');
});

test('publishing an existing unpublished product over the limit is undone', () => {
  const all = docs(50, 3).map((d) => (d.id === 'u0' ? { ...d, published: true } : d));
  assert.strictEqual(
    enforce({ limits: limitsFor(50), docs: all, productId: 'u0', createdNow: false, wasPublished: false }),
    'unpublish');
});

test('editing an already published product never unpublishes it', () => {
  // The shop is over the limit for some other reason (e.g. the plan was
  // lowered): existing published products are left alone.
  assert.strictEqual(
    enforce({ limits: limitsFor(50), docs: docs(55, 0), productId: 'p3', createdNow: false, wasPublished: true }),
    'none');
});

test('unpublishing or editing an unpublished product is always fine', () => {
  assert.strictEqual(
    enforce({ limits: limitsFor(50), docs: docs(50, 5), productId: 'u1', createdNow: false, wasPublished: false }),
    'none');
});

test('a plan decides the limit, whatever max_products says', () => {
  assert.deepStrictEqual(limitsForCompany({ plan: 'basic' }), { max: 50, cap: 60 });
  assert.deepStrictEqual(limitsForCompany({ plan: 'Golden', max_products: 5 }), { max: 80, cap: 96 });
  assert.deepStrictEqual(limitsForCompany({ plan: 'diamond' }), { max: 120, cap: 144 });
});

test('no (or unknown) plan: max_products is used', () => {
  assert.deepStrictEqual(limitsForCompany({ max_products: 50 }), { max: 50, cap: 60 });
  assert.deepStrictEqual(limitsForCompany({ plan: 'platinum', max_products: 70 }), { max: 70, cap: 84 });
  assert.strictEqual(limitsForCompany({}), null);
  assert.strictEqual(limitsForCompany(undefined), null);
});
