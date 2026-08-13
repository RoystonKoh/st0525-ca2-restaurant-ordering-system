const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

test('CA2 database script creates cart tables and an atomic checkout procedure', () => {
  const sql = read('database/ca2_cart_checkout_indexes.sql');
  assert.match(sql, /CREATE TABLE IF NOT EXISTS public\.cart \(/);
  assert.match(sql, /CREATE TABLE IF NOT EXISTS public\.cart_item \(/);
  assert.match(sql, /CREATE OR REPLACE PROCEDURE public\.place_order_from_cart/);
  assert.match(sql, /FOR UPDATE/);
  assert.match(sql, /INSERT INTO public\.sale_order_item/);
  assert.match(sql, /UPDATE public\.cart\s+SET status = 'CHECKED_OUT'/);
});

test('CA2 script includes six explained performance indexes', () => {
  const sql = read('database/ca2_cart_checkout_indexes.sql');
  const requiredIndexes = [
    'idx_cart_member_status',
    'idx_cart_item_product_id',
    'idx_sale_order_member_order_date',
    'idx_sale_order_status_order_date',
    'idx_product_available_category',
    'idx_sale_order_item_product_order',
  ];
  requiredIndexes.forEach((indexName) => assert.match(sql, new RegExp(`CREATE INDEX IF NOT EXISTS ${indexName}`)));
});

test('Prisma schema models cart data and maps existing restaurant tables', () => {
  const schema = read('prisma/schema.prisma');
  ['model Cart {', 'model CartItem {', '@@map("cart")', '@@map("cart_item")', '@@map("sale_order")'].forEach((fragment) => {
    assert.ok(schema.includes(fragment), `Expected schema fragment: ${fragment}`);
  });
});

test('Cart and checkout routes are protected and mounted', () => {
  const cartRoutes = read('routes/cart.js');
  const checkoutRoutes = read('routes/checkout.js');
  const server = read('server.js');
  assert.match(cartRoutes, /router\.use\(ensureAuthenticated, ensureCustomer\)/);
  assert.match(checkoutRoutes, /router\.use\(ensureAuthenticated, ensureCustomer\)/);
  assert.match(server, /app\.use\('\/cart'/);
  assert.match(server, /app\.use\('\/checkout'/);
});

test('Cart and checkout member pages are available', () => {
  ['views/cart.html', 'views/checkout.html', 'public/js/cart-ui.js', 'models/Cart.js'].forEach((relativePath) => {
    assert.ok(fs.existsSync(path.join(root, relativePath)), `Missing ${relativePath}`);
  });
});

test('Prisma-backed cart and checkout modules load successfully', () => {
  assert.doesNotThrow(() => require('../models/Cart'));
  assert.doesNotThrow(() => require('../controllers/checkoutController'));
});
