const assert = require('node:assert/strict');

const baseUrl = process.env.BASE_URL || 'http://127.0.0.1:3103';

function money(value) {
  return Number(Number(value).toFixed(2));
}

function createSession() {
  let cookie = '';
  return {
    async request(path, options = {}) {
      const headers = { ...(options.headers || {}) };
      if (cookie) headers.Cookie = cookie;
      const response = await fetch(`${baseUrl}${path}`, { ...options, headers, redirect: 'manual' });
      const setCookie = response.headers.get('set-cookie');
      if (setCookie) cookie = setCookie.split(';')[0];
      const text = await response.text();
      let body;
      try { body = text ? JSON.parse(text) : null; } catch { body = text; }
      return { response, body };
    },
  };
}

async function jsonRequest(session, path, method = 'GET', body) {
  const options = { method, headers: {} };
  if (body !== undefined) {
    options.headers['Content-Type'] = 'application/json';
    options.body = JSON.stringify(body);
  }
  return session.request(path, options);
}

async function main() {
  const customer = createSession();
  const admin = createSession();

  let result = await jsonRequest(customer, '/login', 'POST', { email: 'testmember@example.com', password: 'Password123' });
  assert.equal(result.response.status, 200);
  assert.equal(result.body.user.role, 'USER');

  // Customer pages required for the end-to-end cart workflow.
  for (const path of ['/cart/create', '/cart/retrieve/all', '/member/checkout']) {
    result = await customer.request(path);
    assert.equal(result.response.status, 200, `${path} should render for a customer`);
  }

  // CRUD: add, retrieve, update, and delete a single item.
  result = await jsonRequest(customer, '/cart/items', 'POST', { product_id: 4, quantity: 1 });
  assert.equal(result.response.status, 201);
  const teaItem = result.body.cart.items.find((item) => item.product_id === 4);
  result = await jsonRequest(customer, `/cart/items/${teaItem.cart_item_id}`, 'PATCH', { quantity: 2 });
  assert.equal(result.body.cart.items.find((item) => item.product_id === 4).quantity, 2);
  result = await jsonRequest(customer, `/cart/items/${teaItem.cart_item_id}`, 'DELETE');
  assert.equal(result.body.cart.items.some((item) => item.product_id === 4), false);

  // Scenario 1: available quantity tier + unavailable item, then a PERCENT voucher after automatic rules.
  await jsonRequest(customer, '/cart/items', 'POST', { product_id: 1, quantity: 3 });
  await jsonRequest(customer, '/cart/items', 'POST', { product_id: 3, quantity: 1 });
  result = await jsonRequest(customer, '/cart/vouchers');
  assert.equal(result.response.status, 200);
  assert.deepEqual(result.body.vouchers.map((voucher) => voucher.code), ['FREEDELIVERY', 'SAVE5', 'WELCOME10']);
  result = await jsonRequest(customer, '/cart/voucher', 'PUT', { voucher_code: 'WELCOME10' });
  assert.equal(result.response.status, 200);
  assert.equal(result.body.cart.summary.selected_voucher.code, 'WELCOME10');
  result = await jsonRequest(customer, '/checkout/preview');
  assert.equal(result.response.status, 200);
  assert.equal(money(result.body.cart.summary.items_subtotal), 60);
  assert.equal(money(result.body.cart.summary.product_discount_amount), 6);
  assert.equal(money(result.body.cart.summary.cart_discount_amount), 0);
  assert.equal(money(result.body.cart.summary.voucher_discount_amount), 5.4);
  assert.equal(money(result.body.cart.summary.delivery_tier_fee), 5);
  assert.equal(money(result.body.cart.summary.delivery_fee), 5);
  assert.equal(money(result.body.cart.summary.final_total), 53.6);
  assert.equal(result.body.can_checkout, true);

  result = await jsonRequest(customer, '/checkout', 'POST');
  assert.equal(result.response.status, 201);
  assert.equal(result.body.processed_item_count, 1);
  assert.equal(result.body.skipped_item_count, 1);
  assert.equal(result.body.order.pricing.voucher_code, 'WELCOME10');
  assert.equal(money(result.body.order.pricing.voucher_discount_amount), 5.4);
  assert.equal(money(result.body.order.pricing.final_total), 53.6);
  assert.equal(result.body.cart.items.length, 1);
  assert.equal(result.body.cart.items[0].product_id, 3);
  result = await jsonRequest(customer, '/cart/voucher', 'DELETE');
  assert.equal(result.response.status, 200);
  assert.equal(result.body.cart.summary.selected_voucher, null);

  // Scenario 2: all remaining items unavailable. No order is created and the item remains.
  result = await jsonRequest(customer, '/checkout', 'POST');
  assert.equal(result.response.status, 200);
  assert.equal(result.body.order, null);
  assert.equal(result.body.processed_item_count, 0);
  assert.equal(result.body.skipped_item_count, 1);
  assert.equal(result.body.cart.items.length, 1);

  // High-value scenario: higher product tier and cart-value rule stack, then a FIXED voucher.
  await jsonRequest(customer, '/cart/items', 'POST', { product_id: 1, quantity: 5 });
  await jsonRequest(customer, '/cart/items', 'POST', { product_id: 2, quantity: 1 });
  result = await jsonRequest(customer, '/cart/voucher', 'PUT', { voucher_code: 'SAVE5' });
  assert.equal(result.response.status, 200);
  result = await jsonRequest(customer, '/checkout/preview');
  assert.equal(money(result.body.cart.summary.items_subtotal), 130);
  assert.equal(money(result.body.cart.summary.product_discount_amount), 15);
  assert.equal(money(result.body.cart.summary.cart_discount_amount), 5.75);
  assert.equal(money(result.body.cart.summary.voucher_discount_amount), 5);
  assert.equal(money(result.body.cart.summary.delivery_fee), 0);
  assert.equal(money(result.body.cart.summary.final_total), 104.25);
  assert.equal(result.body.cart.summary.applied_rules.length, 3);

  result = await jsonRequest(customer, '/checkout', 'POST');
  assert.equal(result.response.status, 201);
  assert.equal(result.body.processed_item_count, 2);
  assert.equal(result.body.skipped_item_count, 1);
  assert.equal(result.body.order.pricing.voucher_code, 'SAVE5');
  assert.equal(money(result.body.order.pricing.voucher_discount_amount), 5);
  assert.equal(money(result.body.order.pricing.final_total), 104.25);

  // FREE_DELIVERY applies after the automatic delivery tier and leaves the unavailable item untouched.
  await jsonRequest(customer, '/cart/items', 'POST', { product_id: 1, quantity: 3 });
  result = await jsonRequest(customer, '/cart/voucher', 'PUT', { voucher_code: 'FREEDELIVERY' });
  assert.equal(result.response.status, 200);
  result = await jsonRequest(customer, '/checkout/preview');
  assert.equal(money(result.body.cart.summary.items_subtotal), 60);
  assert.equal(money(result.body.cart.summary.product_discount_amount), 6);
  assert.equal(money(result.body.cart.summary.delivery_tier_fee), 5);
  assert.equal(money(result.body.cart.summary.voucher_delivery_saving), 5);
  assert.equal(money(result.body.cart.summary.delivery_fee), 0);
  assert.equal(money(result.body.cart.summary.final_total), 54);
  result = await jsonRequest(customer, '/checkout', 'POST');
  assert.equal(result.response.status, 201);
  assert.equal(result.body.order.pricing.voucher_code, 'FREEDELIVERY');
  assert.equal(money(result.body.order.pricing.voucher_delivery_saving), 5);
  assert.equal(money(result.body.order.pricing.final_total), 54);

  // Customer cannot administer restaurant pricing rules.
  result = await customer.request('/dashboard/pricing-rules');
  assert.equal(result.response.status, 403);

  // Admin can list, create, and deactivate a delivery rule.
  result = await jsonRequest(admin, '/login', 'POST', { email: 'testadmin@example.com', password: 'Password123' });
  assert.equal(result.response.status, 200);
  assert.equal(result.body.user.role, 'ADMIN');
  result = await jsonRequest(admin, '/dashboard/pricing-rules');
  assert.equal(result.response.status, 200);
  assert.ok(result.body.rules.length >= 6);

  result = await jsonRequest(admin, '/dashboard/pricing-rules', 'POST', {
    name: 'Automated test delivery tier',
    rule_scope: 'DELIVERY',
    rule_type: 'DELIVERY_TIER',
    minimum_cart_value: 0,
    maximum_cart_value: 39.99,
    delivery_fee: 7,
    priority: 99,
    is_active: true,
  });
  assert.equal(result.response.status, 201);
  const createdRuleId = result.body.rule.pricingRuleId;
  result = await jsonRequest(admin, `/dashboard/pricing-rules/${createdRuleId}/active`, 'PATCH', { is_active: false });
  assert.equal(result.response.status, 200);
  assert.equal(result.body.rule.isActive, false);

  console.log('HTTP_OFFICIAL_CA2_INTEGRATION_PASSED');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
