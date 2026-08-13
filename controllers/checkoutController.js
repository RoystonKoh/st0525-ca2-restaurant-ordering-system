const pool = require('../config/database');
const Cart = require('../models/Cart');

class CheckoutController {
  static async preview(req, res) {
    try {
      const cart = await Cart.getActive(req.session.userId);
      res.json({
        success: true,
        cart,
        can_checkout: cart.items.length > 0 && cart.items.every((item) => item.product.is_available),
      });
    } catch (error) {
      console.error('Checkout preview error:', error);
      res.status(500).json({ success: false, message: 'Unable to prepare checkout.' });
    }
  }

  static async placeOrder(req, res) {
    try {
      // The database procedure locks the active cart, validates every item, creates the order
      // and line items, then marks the cart as CHECKED_OUT as one atomic database operation.
      const result = await pool.query('CALL public.place_order_from_cart($1, NULL)', [req.session.userId]);
      const orderId = result.rows[0]?.p_order_id;

      if (!orderId) {
        throw new Error('Checkout did not return an order identifier.');
      }

      const orderResult = await pool.query(
        `SELECT
           so.order_id,
           so.order_date,
           so.total_amount,
           so.status,
           COUNT(soi.order_item_id)::INTEGER AS item_count
         FROM public.sale_order so
         JOIN public.sale_order_item soi ON soi.order_id = so.order_id
         WHERE so.order_id = $1
         GROUP BY so.order_id, so.order_date, so.total_amount, so.status`,
        [orderId]
      );

      res.status(201).json({
        success: true,
        message: `Order #${orderId} was placed successfully.`,
        order: orderResult.rows[0],
      });
    } catch (error) {
      console.error('Checkout error:', error);
      res.status(400).json({ success: false, message: error.message || 'Checkout could not be completed.' });
    }
  }
}

module.exports = CheckoutController;
