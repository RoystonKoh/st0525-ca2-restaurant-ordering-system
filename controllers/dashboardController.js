const path = require('path');
const Product = require('../models/Product');
const SaleOrder = require('../models/SaleOrder');

class DashboardController {
    static async showDashboard(req, res) {
        res.sendFile(path.join(__dirname, '../views/dashboard.html'));
    }

    static async getSummary(req, res) {
        try {
            const { start_date, end_date, category, sort_by, sort_order } = req.query;

            const orders = await SaleOrder.getSummary(
                start_date || null,
                end_date || null,
                category || null,
                sort_by || 'order_date',
                sort_order || 'DESC'
            );
            const categories = await Product.getCategories();

            res.json({ success: true, orders, categories });
        } catch (error) {
            console.error('Dashboard summary error:', error);
            res.status(500).json({ success: false, message: error.message });
        }
    }

    static async updateOrderStatus(req, res) {
        try {
            const { orderId } = req.params;
            const { status } = req.body;
            const allowedStatuses = ['PACKING', 'COMPLETED', 'CANCELLED'];

            if (!allowedStatuses.includes(status)) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid order status.'
                });
            }

            const order = await SaleOrder.updateStatus(orderId, status);
            res.json({
                success: true,
                message: `Order status updated to ${status}.`,
                order
            });
        } catch (error) {
            console.error('Dashboard update status error:', error);
            res.status(500).json({ success: false, message: error.message });
        }
    }
}

module.exports = DashboardController;
