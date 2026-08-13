let pricingRules = [];
let pricingProducts = [];
let editingRuleActive = true;

document.addEventListener('DOMContentLoaded', () => {
  loadDashboardData();
  setupFilterForm();
  setupPricingRuleForm();
  loadPricingRules();
  updateRuleForm();
});

async function loadDashboardData() {
  const urlParams = new URLSearchParams(window.location.search);
  try {
    const response = await fetch(`/dashboard/summary?${urlParams.toString()}`);
    const data = await response.json();
    if (!data.success) throw new Error(data.message || 'Failed to load dashboard data.');
    displayOrders(data.orders);
    populateCategories(data.categories);
    restoreFilters(urlParams);
  } catch (error) {
    console.error('Dashboard load error:', error);
    alert(error.message || 'Failed to load dashboard data.');
  }
}

function displayOrders(orders) {
  const tbody = document.getElementById('orders-tbody');
  const noOrders = document.getElementById('no-orders');
  const tableContainer = document.getElementById('orders-table-container');
  const title = document.getElementById('order-summary-title');
  title.textContent = `Order Summary (${orders.length} orders)`;
  if (orders.length === 0) {
    tbody.innerHTML = '';
    tableContainer.style.display = 'none';
    noOrders.style.display = 'block';
    return;
  }
  tableContainer.style.display = 'block';
  noOrders.style.display = 'none';
  tbody.innerHTML = orders.map((order) => `
    <tr>
      <td>#${order.order_id}</td><td>${escapeHtml(order.customer_name)}</td><td>${formatDashboardDate(order.order_date)}</td>
      <td>$${Number(order.total_amount).toFixed(2)}</td><td><span class="badge bg-${getStatusBadgeClass(order.status)}">${escapeHtml(order.status)}</span></td>
      <td>${order.total_items}</td><td>${escapeHtml(order.products)}</td>
      <td><select class="form-select form-select-sm" onchange="updateStatus(${order.order_id}, this.value)">
        <option value="PACKING" ${order.status === 'PACKING' ? 'selected' : ''}>PACKING</option>
        <option value="COMPLETED" ${order.status === 'COMPLETED' ? 'selected' : ''}>COMPLETED</option>
        <option value="CANCELLED" ${order.status === 'CANCELLED' ? 'selected' : ''}>CANCELLED</option>
      </select></td>
    </tr>`).join('');
}

function populateCategories(categories) {
  const categorySelect = document.getElementById('category');
  const selectedValue = categorySelect.value;
  while (categorySelect.options.length > 1) categorySelect.remove(1);
  categories.forEach((category) => {
    const option = document.createElement('option');
    option.value = category;
    option.textContent = category;
    categorySelect.appendChild(option);
  });
  categorySelect.value = selectedValue;
}

function restoreFilters(urlParams) {
  ['start_date', 'end_date', 'category', 'sort_by', 'sort_order'].forEach((field) => {
    const value = urlParams.get(field);
    if (value) document.getElementById(field).value = value;
  });
}

function setupFilterForm() {
  document.getElementById('filter-form').addEventListener('submit', (event) => {
    event.preventDefault();
    const params = new URLSearchParams();
    for (const [key, value] of new FormData(event.target).entries()) {
      if (String(value).trim() !== '') params.append(key, value);
    }
    window.history.pushState({}, '', `${window.location.pathname}?${params.toString()}`);
    loadDashboardData();
  });
}

async function updateStatus(orderId, status) {
  try {
    const response = await fetch(`/dashboard/orders/${orderId}/status`, {
      method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ status }),
    });
    const data = await response.json();
    if (!data.success) throw new Error(data.message || 'Unable to update order status.');
    loadDashboardData();
  } catch (error) {
    alert(error.message || 'Unable to update order status.');
    loadDashboardData();
  }
}

function clearFilters() {
  document.getElementById('start_date').value = '';
  document.getElementById('end_date').value = '';
  document.getElementById('category').value = '';
  document.getElementById('sort_by').value = 'order_date';
  document.getElementById('sort_order').value = 'DESC';
  window.history.pushState({}, '', window.location.pathname);
  loadDashboardData();
}

async function loadPricingRules() {
  try {
    const response = await fetch('/dashboard/pricing-rules');
    const data = await response.json();
    if (!data.success) throw new Error(data.message || 'Unable to load pricing rules.');
    pricingRules = data.rules || [];
    pricingProducts = data.products || [];
    const select = document.getElementById('rule-product');
    const selected = select.value;
    select.innerHTML = '<option value="">Select product</option>' + pricingProducts.map((product) =>
      `<option value="${product.productId}">${escapeHtml(product.name)} — $${Number(product.price).toFixed(2)}${product.isAvailable ? '' : ' (unavailable)'}</option>`
    ).join('');
    select.value = selected;
    renderPricingRules();
  } catch (error) {
    showPricingMessage(error.message || 'Unable to load pricing rules.', 'danger');
  }
}

function renderPricingRules() {
  const tbody = document.getElementById('pricing-rules-tbody');
  if (pricingRules.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" class="text-muted">No pricing rules have been created.</td></tr>';
    return;
  }
  tbody.innerHTML = pricingRules.map((rule) => {
    const condition = rule.ruleType === 'PRODUCT_QUANTITY_PERCENT'
      ? `${escapeHtml(rule.product?.name || 'Deleted product')} × ${rule.minimumQuantity}+`
      : rule.ruleType === 'CART_VALUE_PERCENT'
        ? `Cart ≥ $${Number(rule.minimumCartValue).toFixed(2)}`
        : `$${Number(rule.minimumCartValue).toFixed(2)}${rule.maximumCartValue !== null ? `–$${Number(rule.maximumCartValue).toFixed(2)}` : '+'}`;
    const benefit = rule.ruleType === 'DELIVERY_TIER'
      ? `Delivery $${Number(rule.deliveryFee).toFixed(2)}`
      : `${Number(rule.discountPercent).toFixed(2)}% off`;
    return `<tr>
      <td><strong>${escapeHtml(rule.name)}</strong></td>
      <td>${escapeHtml(rule.ruleScope)}<br><span class="small text-muted">${escapeHtml(rule.ruleType)}</span></td>
      <td>${condition}</td><td>${benefit}</td><td>${rule.priority}</td>
      <td><span class="badge bg-${rule.isActive ? 'success' : 'secondary'}">${rule.isActive ? 'Active' : 'Inactive'}</span></td>
      <td class="text-nowrap"><button class="btn btn-sm btn-outline-primary" onclick="editPricingRule(${rule.pricingRuleId})">Edit</button> <button class="btn btn-sm btn-outline-${rule.isActive ? 'warning' : 'success'}" onclick="togglePricingRule(${rule.pricingRuleId}, ${!rule.isActive})">${rule.isActive ? 'Deactivate' : 'Activate'}</button></td>
    </tr>`;
  }).join('');
}

function updateRuleForm() {
  const type = document.getElementById('rule-type').value;
  const isProduct = type === 'PRODUCT_QUANTITY_PERCENT';
  const isCart = type === 'CART_VALUE_PERCENT';
  const isDelivery = type === 'DELIVERY_TIER';
  document.getElementById('rule-product-group').classList.toggle('d-none', !isProduct);
  document.getElementById('rule-quantity-group').classList.toggle('d-none', !isProduct);
  document.getElementById('rule-maximum-cart-value-group').classList.toggle('d-none', !isDelivery);
  document.getElementById('rule-discount-percent-group').classList.toggle('d-none', isDelivery);
  document.getElementById('rule-delivery-fee-group').classList.toggle('d-none', !isDelivery);
  document.getElementById('rule-minimum-cart-value').closest('.col-md-3').classList.toggle('d-none', isProduct);
  if (isCart) document.getElementById('rule-maximum-cart-value').value = '';
}

function setupPricingRuleForm() {
  document.getElementById('pricing-rule-form').addEventListener('submit', async (event) => {
    event.preventDefault();
    const id = document.getElementById('pricing-rule-id').value;
    const type = document.getElementById('rule-type').value;
    const scope = type === 'PRODUCT_QUANTITY_PERCENT' ? 'PRODUCT' : type === 'CART_VALUE_PERCENT' ? 'CART' : 'DELIVERY';
    const optionalNumber = (id) => document.getElementById(id).value === '' ? null : Number(document.getElementById(id).value);
    const payload = {
      name: document.getElementById('rule-name').value,
      rule_scope: scope,
      rule_type: type,
      product_id: optionalNumber('rule-product'),
      minimum_quantity: optionalNumber('rule-minimum-quantity'),
      minimum_cart_value: optionalNumber('rule-minimum-cart-value'),
      maximum_cart_value: optionalNumber('rule-maximum-cart-value'),
      discount_percent: optionalNumber('rule-discount-percent'),
      delivery_fee: optionalNumber('rule-delivery-fee'),
      priority: Number(document.getElementById('rule-priority').value || 0),
      is_active: editingRuleActive,
    };
    try {
      const response = await fetch(id ? `/dashboard/pricing-rules/${id}` : '/dashboard/pricing-rules', {
        method: id ? 'PUT' : 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload),
      });
      const data = await response.json();
      if (!data.success) throw new Error(data.message || 'Unable to save pricing rule.');
      showPricingMessage(data.message, 'success');
      resetPricingRuleForm();
      loadPricingRules();
    } catch (error) {
      showPricingMessage(error.message || 'Unable to save pricing rule.', 'danger');
    }
  });
}

function editPricingRule(pricingRuleId) {
  const rule = pricingRules.find((item) => item.pricingRuleId === pricingRuleId);
  if (!rule) return;
  editingRuleActive = rule.isActive;
  document.getElementById('pricing-rule-id').value = rule.pricingRuleId;
  document.getElementById('rule-name').value = rule.name;
  document.getElementById('rule-type').value = rule.ruleType;
  document.getElementById('rule-product').value = rule.productId || '';
  document.getElementById('rule-minimum-quantity').value = rule.minimumQuantity || '';
  document.getElementById('rule-minimum-cart-value').value = rule.minimumCartValue ?? '';
  document.getElementById('rule-maximum-cart-value').value = rule.maximumCartValue ?? '';
  document.getElementById('rule-discount-percent').value = rule.discountPercent ?? '';
  document.getElementById('rule-delivery-fee').value = rule.deliveryFee ?? '';
  document.getElementById('rule-priority').value = rule.priority;
  updateRuleForm();
  document.getElementById('pricing-rule-form').scrollIntoView({ behavior: 'smooth', block: 'center' });
}

function resetPricingRuleForm() {
  document.getElementById('pricing-rule-form').reset();
  editingRuleActive = true;
  document.getElementById('pricing-rule-id').value = '';
  document.getElementById('rule-priority').value = '0';
  updateRuleForm();
}

async function togglePricingRule(pricingRuleId, isActive) {
  try {
    const response = await fetch(`/dashboard/pricing-rules/${pricingRuleId}/active`, {
      method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ is_active: isActive }),
    });
    const data = await response.json();
    if (!data.success) throw new Error(data.message || 'Unable to update rule status.');
    showPricingMessage(data.message, 'success');
    loadPricingRules();
  } catch (error) {
    showPricingMessage(error.message || 'Unable to update rule status.', 'danger');
  }
}

function showPricingMessage(message, type) {
  const box = document.getElementById('pricing-rule-message');
  box.textContent = message;
  box.className = `alert alert-${type}`;
}

function getStatusBadgeClass(status) {
  return ({ COMPLETED: 'success', CANCELLED: 'danger', PACKING: 'warning' }[status] || 'secondary');
}

function formatDashboardDate(dateString) {
  return dateString ? new Date(dateString).toLocaleDateString('en-SG', { year: 'numeric', month: 'short', day: 'numeric' }) : 'N/A';
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>'"]/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
}

window.addEventListener('popstate', loadDashboardData);
