'use strict';

// Plan limits for a shop's products, kept free of Firebase so it can be tested
// on its own. Mirrors lib/core/domain/product_limits.dart:
//   - at most `max` products published;
//   - at most `cap` = max + 20% (whole products, rounded down) in total, the
//     extra ones staying unpublished.

const EXTRA_PERCENT = 20;

// Same table as lib/core/domain/subscription_plans.dart. A shop with a `plan`
// gets that plan's product limit whatever its `max_products` says.
const PLANS = {
  basic: { maxProducts: 50, maxCategories: 4 },
  golden: { maxProducts: 80, maxCategories: 5 },
  diamond: { maxProducts: 120, maxCategories: 7 },
};

/** Limits for a company document: its plan's number, else `max_products`. */
function limitsForCompany(company) {
  const data = company || {};
  const plan = PLANS[String(data.plan == null ? '' : data.plan).trim().toLowerCase()];
  return limitsFor(plan ? plan.maxProducts : data.max_products);
}

/** Limits for the plan's `max_products`, or null when none is set. */
function limitsFor(maxProducts) {
  const n = typeof maxProducts === 'number' ? Math.trunc(maxProducts)
    : parseInt(String(maxProducts == null ? '' : maxProducts).trim(), 10);
  if (!Number.isFinite(n) || n <= 0) return null;
  return { max: n, cap: n + Math.floor((n * EXTRA_PERCENT) / 100) };
}

/**
 * What to do with the product that was just written.
 *
 * @param limits      result of limitsFor
 * @param docs        every product of the shop right now: [{id, published}]
 * @param productId   the product that was written
 * @param createdNow  it did not exist before this write
 * @param wasPublished it was published before this write
 * @returns 'delete' (over the total limit), 'unpublish' (over the published
 *          limit) or 'none'.
 */
function enforce({ limits, docs, productId, createdNow, wasPublished }) {
  if (!limits) return 'none';
  if (createdNow && docs.length > limits.cap) return 'delete';

  const mine = docs.find((d) => d.id === productId);
  if (!mine || !mine.published) return 'none';
  const published = docs.filter((d) => d.published).length;
  const justPublished = createdNow || !wasPublished;
  if (justPublished && published > limits.max) return 'unpublish';
  return 'none';
}

module.exports = { limitsFor, limitsForCompany, enforce, EXTRA_PERCENT, PLANS };
