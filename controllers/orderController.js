const SaleOrder = require('../models/SaleOrder');

class OrderController {
    static async createOrder(req, res) {
        try {
            const { product_id, quantity } = req.body;

            if (!product_id) {
                return res.status(400).json({
                    success: false,
                    message: 'Product is required.'
                });
            }

            const order = await SaleOrder.create(
                req.session.userId,
                Number(product_id),
                Number(quantity || 1)
            );

            res.json({
                success: true,
                message: 'Order placed successfully. An admin can mark it as COMPLETED from the dashboard.',
                order
            });
        } catch (error) {
            console.error('Create order error:', error);
            res.status(400).json({ success: false, message: error.message });
        }
    }

    static async getProductHistory(req, res) {
        try {
            const productId = Number(req.params.productId);
            const orders = await SaleOrder.getProductHistory(req.session.userId, productId);
            const hasCompletedOrder = orders.some((order) => order.status === 'COMPLETED');

            res.json({
                success: true,
                orders,
                hasCompletedOrder
            });
        } catch (error) {
            console.error('Get product order history error:', error);
            res.status(500).json({ success: false, message: error.message });
        }
    }
}

module.exports = OrderController;
