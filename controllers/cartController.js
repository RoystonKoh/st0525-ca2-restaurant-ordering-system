const Cart = require('../models/Cart');

function parsePositiveInteger(value, fieldName, allowZero = false) {
  const parsed = Number(value);
  const minimum = allowZero ? 0 : 1;
  if (!Number.isInteger(parsed) || parsed < minimum) {
    throw new Error(`${fieldName} must be a whole number${allowZero ? ' of at least 0' : ' of at least 1'}.`);
  }
  return parsed;
}

class CartController {
  static async getCart(req, res) {
    try {
      const cart = await Cart.getActive(req.session.userId);
      res.json({ success: true, cart });
    } catch (error) {
      console.error('Get cart error:', error);
      res.status(500).json({ success: false, message: 'Unable to load the cart.' });
    }
  }

  static async addItem(req, res) {
    try {
      const productId = parsePositiveInteger(req.body.product_id, 'Product ID');
      const quantity = parsePositiveInteger(req.body.quantity ?? 1, 'Quantity');
      const cart = await Cart.addItem(req.session.userId, productId, quantity);
      res.status(201).json({ success: true, message: 'Item added to cart.', cart });
    } catch (error) {
      res.status(400).json({ success: false, message: error.message });
    }
  }

  static async updateItem(req, res) {
    try {
      const cartItemId = parsePositiveInteger(req.params.cartItemId, 'Cart item ID');
      const quantity = parsePositiveInteger(req.body.quantity, 'Quantity', true);
      const cart = await Cart.updateItem(req.session.userId, cartItemId, quantity);
      res.json({ success: true, message: quantity === 0 ? 'Item removed from cart.' : 'Cart quantity updated.', cart });
    } catch (error) {
      res.status(400).json({ success: false, message: error.message });
    }
  }

  static async deleteItem(req, res) {
    try {
      const cartItemId = parsePositiveInteger(req.params.cartItemId, 'Cart item ID');
      const cart = await Cart.removeItem(req.session.userId, cartItemId);
      res.json({ success: true, message: 'Item removed from cart.', cart });
    } catch (error) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
}

module.exports = CartController;
