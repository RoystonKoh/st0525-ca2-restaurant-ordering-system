const pool = require('../config/database');
const prisma = require('../config/prisma');
const Cart = require('../models/Cart');

class CheckoutController {
  static async preview(req, res) {
    try {
      const cart = await Cart.getActive(req.session.userId);
      res.json({
        success: true,
        cart,
        // A non-empty cart may always invoke the procedure. If all items are unavailable,
        // place_orders returns no order and leaves every item in the cart, matching Appendix Scenario 2.
        can_checkout: cart.items.length > 0,
        message: cart.summary.message,
      });
    } catch (error) {
      console.error('Checkout preview error:', error);
      res.status(500).json({ success: false, message: 'Unable to prepare checkout.' });
    }
  }

  static async placeOrder(req, res) {
    try {
      // Discount and delivery eligibility are calculated in the backend pricing service before this call.
      // The required procedure processes cart items only; it continues past unavailable items.
      const cartBeforeProcessing = await Cart.getActive(req.session.userId);
      const pricing = cartBeforeProcessing.summary;

      if (cartBeforeProcessing.items.length === 0) {
        return res.status(400).json({
          success: false,
          message: 'Cannot place an order from an empty cart.',
          cart: cartBeforeProcessing,
        });
      }

      const procedureResult = await pool.query(
        'CALL public.place_orders($1, NULL, NULL, NULL)',
        [req.session.userId]
      );
      const procedureOutput = procedureResult.rows[0] || {};
      const orderId = procedureOutput.p_order_id;
      const processedItemCount = Number(procedureOutput.p_processed_item_count || 0);
      const skippedItemCount = Number(procedureOutput.p_skipped_item_count || 0);

      if (!orderId) {
        const remainingCart = await Cart.getActive(req.session.userId);
        return res.json({
          success: true,
          message: 'No order was created because every cart item is unavailable. The items remain in your cart.',
          order: null,
          processed_item_count: processedItemCount,
          skipped_item_count: skippedItemCount,
          cart: remainingCart,
        });
      }

      // This is a Prisma transaction, matching the ORM transaction approach taught in the practicals.
      await prisma.$transaction([
        prisma.saleOrder.update({
          where: { orderId },
          data: { totalAmount: pricing.final_total },
        }),
        prisma.orderPricing.create({
          data: {
            orderId,
            itemsSubtotal: pricing.items_subtotal,
            productDiscountAmount: pricing.product_discount_amount,
            cartDiscountAmount: pricing.cart_discount_amount,
            deliveryFee: pricing.delivery_fee,
            deliveryDiscountAmount: pricing.delivery_discount_amount,
            voucherCode: pricing.selected_voucher?.code || null,
            voucherDiscountAmount: pricing.voucher_discount_amount,
            voucherDeliverySaving: pricing.voucher_delivery_saving,
            finalTotal: pricing.final_total,
            pricingSnapshot: pricing,
          },
        }),
      ]);

      const order = await prisma.saleOrder.findUnique({
        where: { orderId },
        include: { items: true, pricing: true },
      });
      const remainingCart = await Cart.getActive(req.session.userId);
      const partialMessage = skippedItemCount > 0
        ? `Order #${orderId} was placed for available items. ${skippedItemCount} unavailable item(s) remain in your cart.`
        : `Order #${orderId} was placed successfully.`;

      res.status(201).json({
        success: true,
        message: partialMessage,
        order: {
          order_id: order.orderId,
          order_date: order.orderDate,
          total_amount: Number(order.totalAmount),
          status: order.status,
          item_count: order.items.length,
          pricing: {
            items_subtotal: Number(order.pricing.itemsSubtotal),
            product_discount_amount: Number(order.pricing.productDiscountAmount),
            cart_discount_amount: Number(order.pricing.cartDiscountAmount),
            delivery_fee: Number(order.pricing.deliveryFee),
            delivery_discount_amount: Number(order.pricing.deliveryDiscountAmount),
            voucher_code: order.pricing.voucherCode,
            voucher_discount_amount: Number(order.pricing.voucherDiscountAmount),
            voucher_delivery_saving: Number(order.pricing.voucherDeliverySaving),
            final_total: Number(order.pricing.finalTotal),
            applied_rules: order.pricing.pricingSnapshot.applied_rules || [],
          },
        },
        processed_item_count: processedItemCount,
        skipped_item_count: skippedItemCount,
        cart: remainingCart,
      });
    } catch (error) {
      console.error('Checkout error:', error);
      res.status(400).json({ success: false, message: error.message || 'Checkout could not be completed.' });
    }
  }
}

module.exports = CheckoutController;
