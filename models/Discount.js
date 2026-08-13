const pool = require('../config/database');

class Discount {
  static async getActive() {
    const result = await pool.query(
      `SELECT code, discount_type, discount_value, minimum_subtotal,
              buy_quantity, get_quantity, description
         FROM public.discount
        WHERE is_active = TRUE
        ORDER BY code`
    );
    return result.rows;
  }

  static async getAppliedCode(cartId) {
    const result = await pool.query(
      'SELECT discount_code FROM public.cart WHERE cart_id = $1',
      [cartId]
    );
    return result.rows[0]?.discount_code || null;
  }

  static async getPricing(cartId, discountCode = null) {
    const result = await pool.query(
      `SELECT subtotal, discount_code, discount_type, discount_description,
              discount_amount, final_total
         FROM public.calculate_cart_discount($1, $2)`,
      [cartId, discountCode]
    );
    return result.rows[0];
  }

  static async apply(memberId, cartId, discountCode) {
    const code = String(discountCode || '').trim().toUpperCase();
    if (!code) throw new Error('Select a discount code before applying it.');

    // Preview first. This validates activity, minimum spend and Buy-X-Get-Y eligibility.
    const pricing = await this.getPricing(cartId, code);

    await pool.query(
      `UPDATE public.cart
          SET discount_code = $1,
              updated_at = CURRENT_TIMESTAMP
        WHERE cart_id = $2
          AND member_id = $3
          AND status = 'ACTIVE'`,
      [code, cartId, memberId]
    );

    return pricing;
  }

  static async clear(memberId, cartId) {
    await pool.query(
      `UPDATE public.cart
          SET discount_code = NULL,
              updated_at = CURRENT_TIMESTAMP
        WHERE cart_id = $1
          AND member_id = $2
          AND status = 'ACTIVE'`,
      [cartId, memberId]
    );
    return this.getPricing(cartId, null);
  }
}

module.exports = Discount;
