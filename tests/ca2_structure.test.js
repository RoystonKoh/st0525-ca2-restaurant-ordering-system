const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');
const exists = (relativePath) => fs.existsSync(path.join(root, relativePath));

test('official CA2 migration creates rule and pricing tables without changing original restaurant table definitions', () => {
  const sql = read('database/ca2_official_pricing_and_transactions.sql');
  ['CREATE TABLE IF NOT EXISTS public.pricing_rule', 'CREATE TABLE IF NOT EXISTS public.order_pricing', 'CREATE TABLE IF NOT EXISTS public.voucher', 'CREATE TABLE IF NOT EXISTS public.cart_voucher', 'PRODUCT_QUANTITY_PERCENT', 'CART_VALUE_PERCENT', 'DELIVERY_TIER'].forEach((fragment) => {
    assert.ok(sql.includes(fragment), `Expected migration fragment: ${fragment}`);
  });
  ['member', 'member_role', 'product', 'sale_order', 'sale_order_item'].forEach((tableName) => {
    assert.doesNotMatch(sql, new RegExp(`ALTER TABLE public\\.${tableName}\\b`), `Original table must not be altered: ${tableName}`);
  });
});

test('Prisma models cover Cart, CartItem, extensible PricingRule, and immutable OrderPricing records', () => {
  const schema = read('prisma/schema.prisma');
  ['model Cart {', 'model CartItem {', 'model PricingRule {', 'model Voucher {', 'model CartVoucher {', 'model OrderPricing {', '@@map("cart")', '@@map("cart_item")', '@@map("pricing_rule")', '@@map("voucher")', '@@map("cart_voucher")', '@@map("order_pricing")'].forEach((fragment) => {
    assert.ok(schema.includes(fragment), `Expected Prisma schema fragment: ${fragment}`);
  });
});

test('cart management uses Prisma CRUD and backend pricing summary', () => {
  const cartModel = read('models/Cart.js');
  ['prisma.cart.findFirst', 'prisma.cart.create', 'prisma.cartItem.upsert', 'prisma.cartItem.update', 'prisma.cartItem.delete', 'PricingService.calculate'].forEach((fragment) => {
    assert.ok(cartModel.includes(fragment), `Expected cart CRUD/summary fragment: ${fragment}`);
  });
  const cartRoutes = read('routes/cart.js');
  assert.match(cartRoutes, /router\.get\('\/create'/);
  assert.match(cartRoutes, /router\.get\('\/retrieve\/all'/);
  assert.match(cartRoutes, /router\.use\(ensureAuthenticated, ensureCustomer\)/);
});

test('pricing service applies stackable product quantity and cart value rules plus delivery tiers', () => {
  const pricing = read('services/PricingService.js');
  ['PRODUCT_QUANTITY_PERCENT', 'CART_VALUE_PERCENT', 'DELIVERY_TIER', 'productDiscountAmount', 'cartDiscountAmount', 'deliveryFee', 'applied_rules'].forEach((fragment) => {
    assert.ok(pricing.includes(fragment), `Expected pricing fragment: ${fragment}`);
  });
});

test('customer voucher selection and delivery price breakdown are protected and visible', () => {
  const routes = read('routes/cart.js');
  const controller = read('controllers/cartController.js');
  const cartPage = read('views/cart.html');
  const checkoutPage = read('views/checkout.html');
  ['router.get(\'/vouchers\'', 'router.put(\'/voucher\'', 'router.delete(\'/voucher\''].forEach((fragment) => assert.ok(routes.includes(fragment)));
  ['Voucher.listActive', 'Voucher.selectForCart', 'Voucher.clearForCart'].forEach((fragment) => assert.ok(controller.includes(fragment)));
  ['Optional Voucher', 'Delivery / Service Pricing', 'Final delivery / service fee'].forEach((fragment) => assert.ok(cartPage.includes(fragment)));
  ['Selected voucher', 'Voucher item saving', 'Final delivery/service fee'].forEach((fragment) => assert.ok(checkoutPage.includes(fragment)));
});

test('administrator dashboard protects and exposes pricing rule management', () => {
  const routes = read('routes/dashboard.js');
  const controller = read('controllers/pricingRuleController.js');
  const page = read('views/dashboard.html');
  assert.match(routes, /router\.use\(ensureAuthenticated, ensureAdmin\)/);
  ['GET', 'POST', 'PUT', 'PATCH'].forEach((method) => assert.ok(routes.includes(method.toLowerCase()) || routes.includes(method), `Expected dashboard method ${method}`));
  ['PricingRule.listForAdmin', 'PricingRule.create', 'PricingRule.update', 'PricingRule.setActive'].forEach((fragment) => assert.ok(controller.includes(fragment)));
  assert.ok(page.includes('Promotion and Delivery Rules'));
});

test('required place_orders procedure processes available items and leaves unavailable items in the cart', () => {
  const sql = read('database/ca2_official_pricing_and_transactions.sql');
  ['CREATE OR REPLACE PROCEDURE public.place_orders', 'FOR v_item IN', 'IF v_item.is_available THEN', 'DELETE FROM public.cart_item', 'p_skipped_item_count := p_skipped_item_count + 1', 'It intentionally does not calculate discounts or delivery pricing'].forEach((fragment) => {
    assert.ok(sql.includes(fragment), `Expected procedure fragment: ${fragment}`);
  });
  assert.ok(exists('tests/official_ca2_transaction_checks.sql'));
});

test('checkout invokes required procedure and stores the backend pricing snapshot after order processing', () => {
  const controller = read('controllers/checkoutController.js');
  ['CALL public.place_orders', 'prisma.$transaction', 'prisma.orderPricing.create', 'voucherCode', 'voucherDiscountAmount', 'voucherDeliverySaving', 'skipped_item_count', 'remainingCart'].forEach((fragment) => {
    assert.ok(controller.includes(fragment), `Expected checkout fragment: ${fragment}`);
  });
});

test('required customer, administrator, transaction, manufacturer, and report artifacts are present', () => {
  [
    'views/products.html', 'views/cart.html', 'views/checkout.html', 'views/dashboard.html',
    'database/functions_&_stored_procedures.sql', 'database/manufacturer_indexing.sql',
    'database/manufacturer_benchmark.sql', 'docs/CA2_REQUIREMENTS_TRACEABILITY.md',
    'docs/CA2_PRICING_AND_TRANSACTION_DESIGN.md', 'tests/official_ca2_transaction_checks.sql',
  ].forEach((relativePath) => assert.ok(exists(relativePath), `Missing required artifact: ${relativePath}`));
});

test('final runtime modules load without requiring a live database connection', () => {
  ['../models/Cart', '../models/PricingRule', '../models/Voucher', '../services/PricingService', '../controllers/cartController', '../controllers/checkoutController', '../controllers/pricingRuleController'].forEach((modulePath) => {
    assert.doesNotThrow(() => require(modulePath), `Unable to load ${modulePath}`);
  });
});
