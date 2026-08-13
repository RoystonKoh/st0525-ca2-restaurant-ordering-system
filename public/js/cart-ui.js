function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (character) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  }[character]));
}

async function getJson(url, options = {}) {
  const response = await fetch(url, options);
  const data = await response.json();
  if (!response.ok || !data.success) {
    throw new Error(data.message || 'The request could not be completed.');
  }
  return data;
}

async function refreshCartBadge() {
  const badge = document.getElementById('cart-count');
  if (!badge) return;

  try {
    const data = await getJson('/cart');
    badge.textContent = data.cart.item_count;
    badge.classList.toggle('d-none', data.cart.item_count === 0);
  } catch (error) {
    badge.classList.add('d-none');
  }
}

function showPageMessage(message, type = 'info') {
  const box = document.getElementById('page-message');
  if (!box) return;
  box.className = `alert alert-${type}`;
  box.textContent = message;
  box.classList.remove('d-none');
  box.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}
