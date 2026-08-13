const pool = require('../config/database');

class SaleOrder {
    static async create(memberId, productId, quantity = 1) {
        const client = await pool.connect();

        try {
            await client.query('BEGIN');

            const productResult = await client.query(
                `SELECT product_id, price, is_available
                 FROM public.product
                 WHERE product_id = $1`,
                [productId]
            );

            if (productResult.rows.length === 0) {
                throw new Error('Product not found.');
            }

            const product = productResult.rows[0];
            if (!product.is_available) {
                throw new Error('This product is currently unavailable.');
            }

            const orderQuantity = Number(quantity);
            if (!Number.isInteger(orderQuantity) || orderQuantity < 1) {
                throw new Error('Quantity must be at least 1.');
            }

            const unitPrice = Number(product.price);
            const subtotal = unitPrice * orderQuantity;

            const orderResult = await client.query(
                `INSERT INTO public.sale_order (member_id, total_amount, status, order_date)
                 VALUES ($1, $2, 'PACKING', CURRENT_TIMESTAMP)
                 RETURNING *`,
                [memberId, subtotal]
            );

            const order = orderResult.rows[0];

            await client.query(
                `INSERT INTO public.sale_order_item (order_id, product_id, quantity, unit_price, subtotal)
                 VALUES ($1, $2, $3, $4, $5)`,
                [order.order_id, productId, orderQuantity, unitPrice, subtotal]
            );

            await client.query('COMMIT');
            return order;
        } catch (error) {
            await client.query('ROLLBACK');
            throw error;
        } finally {
            client.release();
        }
    }

    static async getSummary(startDate, endDate, category, sortBy = 'order_date', sortOrder = 'DESC') {
        const result = await pool.query(
            `SELECT * FROM get_sale_order_summary(
                $1::TIMESTAMP,
                $2::TIMESTAMP,
                $3::VARCHAR,
                $4::VARCHAR,
                $5::VARCHAR
            )`,
            [
                startDate || null,
                endDate || null,
                category || null,
                sortBy || 'order_date',
                sortOrder || 'DESC'
            ]
        );

        return result.rows;
    }

    static async getProductHistory(memberId, productId) {
        const result = await pool.query(
            `SELECT
                so.order_id,
                so.order_date,
                so.status,
                so.total_amount,
                soi.product_id,
                soi.quantity,
                soi.unit_price,
                soi.subtotal
             FROM public.sale_order so
             JOIN public.sale_order_item soi ON soi.order_id = so.order_id
             WHERE so.member_id = $1
               AND soi.product_id = $2
             ORDER BY so.order_date DESC, so.order_id DESC`,
            [memberId, productId]
        );

        return result.rows;
    }

    static async updateStatus(orderId, status) {
        const result = await pool.query(
            `UPDATE public.sale_order
             SET status = $2
             WHERE order_id = $1
             RETURNING *`,
            [orderId, status]
        );

        if (result.rows.length === 0) {
            throw new Error('Order not found.');
        }

        return result.rows[0];
    }
}

module.exports = SaleOrder;
