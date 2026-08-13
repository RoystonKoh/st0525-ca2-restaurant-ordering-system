const Cart = require('../models/Cart');
const Voucher = require('../models/Voucher');

function parseWholeNumber(value, fieldName, allowZero = false) {
  const parsed = Number(value);
  const minimum = allowZero ? 0 : 1;
  if (!Number.isInteger(parsed) || parsed < minimum) {
    throw new Error(`${fieldName} must be a whole number of at least ${minimum}.`);
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
      res.status(500).json({ success: false, message: 'Unable to load the cart summary.' });
    }
  }

  static async addItem(req, res) {
    try {
      const productId = parseWholeNumber(req.body.product_id, 'Product ID');
      const quantity = parseWholeNumber(req.body.quantity ?? 1, 'Quantity');
      const cart = await Cart.addItem(req.session.userId, productId, quantity);
      res.status(201).json({ success: true, message: 'Item added to cart.', cart });
    } catch (error) {
      res.status(400).json({ success: false, message: error.message });
    }
  }

  static async updateItem(req, res) {
    try {
      const cartItemId = parseWholeNumber(req.params.cartItemId, 'Cart item ID');
      const quantity = parseWholeNumber(req.body.quantity, 'Quantity', true);
      const cart = await Cart.updateItem(req.session.userId, cartItemId, quantity);
      res.json({ success: true, message: quantity === 0 ? 'Item removed from cart.' : 'Cart quantity updated.', cart });
    } catch (error) {
      res.status(400).json({ success: false, message: error.message });
    }
  }

  static async listVouchers(req, res) {
    try {
      const [cart, vouchers] = await Promise.all([
        Cart.getActive(req.session.userId),
        Voucher.listActive(),
      ]);
      res.json({ success: true, vouchers, selected_voucher: cart.summary.selected_voucher });
    } catch (error) {
      console.error('List vouchers error:', error);
      res.status(500).json({ success: false, message: 'Unable to load vouchers.' });
    }
  }

  static async selectVoucher(req, res) {
    try {
      const cart = await Cart.getActive(req.session.userId);
      const voucher = await Voucher.selectForCart(req.session.userId, cart.cart_id, req.body.voucher_code);
      const refreshedCart = await Cart.getActive(req.session.userId);
      res.json({ success: true, message: `${voucher.code} selected.`, cart: refreshedCart });
    } catch (error) {
      res.status(400).json({ success: false, message: error.message });
    }
  }

  static async clearVoucher(req, res) {
    try {
      const cart = await Cart.getActive(req.session.userId);
      await Voucher.clearForCart(req.session.userId, cart.cart_id);
      const refreshedCart = await Cart.getActive(req.session.userId);
      res.json({ success: true, message: 'Voucher removed.', cart: refreshedCart });
    } catch (error) {
      res.status(400).json({ success: false, message: error.message });
    }
  }

  static async deleteItem(req, res) {
    try {
      const cartItemId = parseWholeNumber(req.params.cartItemId, 'Cart item ID');
      const cart = await Cart.removeItem(req.session.userId, cartItemId);
      res.json({ success: true, message: 'Item removed from cart.', cart });
    } catch (error) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
}

module.exports = CartController;
