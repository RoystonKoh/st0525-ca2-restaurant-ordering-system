document.addEventListener('DOMContentLoaded', () => {
    loadDashboardData();
    setupFilterForm();
});

async function loadDashboardData() {
    const urlParams = new URLSearchParams(window.location.search);

    try {
        const response = await fetch(`/dashboard/summary?${urlParams.toString()}`);
        const data = await response.json();

        if (!data.success) {
            alert(data.message || 'Failed to load dashboard data.');
            return;
        }

        displayOrders(data.orders);
        populateCategories(data.categories);
        restoreFilters(urlParams);
    } catch (error) {
        console.error('Dashboard load error:', error);
        alert('Failed to load dashboard data.');
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
            <td>#${order.order_id}</td>
            <td>${escapeHtml(order.customer_name)}</td>
            <td>${formatDashboardDate(order.order_date)}</td>
            <td>$${parseFloat(order.total_amount).toFixed(2)}</td>
            <td><span class="badge bg-${getStatusBadgeClass(order.status)}">${escapeHtml(order.status)}</span></td>
            <td>${order.total_items}</td>
            <td>${escapeHtml(order.products)}</td>
            <td>
                <select class="form-select form-select-sm" onchange="updateStatus(${order.order_id}, this.value)">
                    <option value="PACKING" ${order.status === 'PACKING' ? 'selected' : ''}>PACKING</option>
                    <option value="COMPLETED" ${order.status === 'COMPLETED' ? 'selected' : ''}>COMPLETED</option>
                    <option value="CANCELLED" ${order.status === 'CANCELLED' ? 'selected' : ''}>CANCELLED</option>
                </select>
            </td>
        </tr>
    `).join('');
}

function populateCategories(categories) {
    const categorySelect = document.getElementById('category');
    const selectedValue = categorySelect.value;

    while (categorySelect.options.length > 1) {
        categorySelect.remove(1);
    }

    categories.forEach((category) => {
        const option = document.createElement('option');
        option.value = category;
        option.textContent = category;
        categorySelect.appendChild(option);
    });

    categorySelect.value = selectedValue;
}

function restoreFilters(urlParams) {
    const fields = ['start_date', 'end_date', 'category', 'sort_by', 'sort_order'];

    fields.forEach((field) => {
        const value = urlParams.get(field);
        if (value) {
            document.getElementById(field).value = value;
        }
    });
}

function setupFilterForm() {
    const form = document.getElementById('filter-form');

    form.addEventListener('submit', (event) => {
        event.preventDefault();
        const formData = new FormData(form);
        const params = new URLSearchParams();

        for (const [key, value] of formData.entries()) {
            if (String(value).trim() !== '') {
                params.append(key, value);
            }
        }

        window.history.pushState({}, '', `${window.location.pathname}?${params.toString()}`);
        loadDashboardData();
    });
}

async function updateStatus(orderId, status) {
    try {
        const response = await fetch(`/dashboard/orders/${orderId}/status`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status })
        });
        const data = await response.json();

        if (!data.success) {
            alert(data.message || 'Unable to update order status.');
            loadDashboardData();
            return;
        }

        loadDashboardData();
    } catch (error) {
        console.error('Status update error:', error);
        alert('Unable to update order status.');
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

function getStatusBadgeClass(status) {
    switch (status) {
        case 'COMPLETED':
            return 'success';
        case 'CANCELLED':
            return 'danger';
        case 'PACKING':
            return 'warning';
        default:
            return 'secondary';
    }
}

function formatDashboardDate(dateString) {
    if (!dateString) return 'N/A';
    return new Date(dateString).toLocaleDateString('en-SG', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    });
}

function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, (char) => ({
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;'
    }[char]));
}

window.addEventListener('popstate', loadDashboardData);
