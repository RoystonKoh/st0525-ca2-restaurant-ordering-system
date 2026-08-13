const pool = require('../config/database');

class Feedback {
    static async create(memberId, productId, rating, comments) {
        try {
            await pool.query('CALL create_feedback($1, $2, $3, $4)', [
                memberId,
                productId,
                rating,
                comments
            ]);
        } catch (error) {
            throw new Error(error.message);
        }
    }

    static async update(feedbackId, memberId, rating, comments) {
        try {
            await pool.query('CALL update_feedback($1, $2, $3, $4)', [
                feedbackId,
                memberId,
                rating,
                comments
            ]);
        } catch (error) {
            throw new Error(error.message);
        }
    }

    static async delete(feedbackId, memberId) {
        try {
            await pool.query('CALL delete_feedback($1, $2)', [feedbackId, memberId]);
        } catch (error) {
            throw new Error(error.message);
        }
    }

    static async getByProduct(productId) {
        const result = await pool.query('SELECT * FROM get_feedback(NULL, $1)', [productId]);
        return result.rows;
    }

    static async getByMember(memberId) {
        const result = await pool.query('SELECT * FROM get_feedback($1, NULL)', [memberId]);
        return result.rows;
    }
}

module.exports = Feedback;
