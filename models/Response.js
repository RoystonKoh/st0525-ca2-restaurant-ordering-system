const pool = require('../config/database');

class Response {
    static async create(feedbackId, memberId, responseText, parentResponseId = null) {
        try {
            await pool.query('CALL create_response($1, $2, $3, $4)', [
                feedbackId,
                memberId,
                responseText,
                parentResponseId || null
            ]);
        } catch (error) {
            throw new Error(error.message);
        }
    }

    static async delete(responseId, memberId) {
        try {
            await pool.query('CALL delete_response($1, $2)', [responseId, memberId]);
        } catch (error) {
            throw new Error(error.message);
        }
    }

    static async getByFeedback(feedbackId) {
        const result = await pool.query('SELECT * FROM get_response($1)', [feedbackId]);
        return result.rows;
    }
}

module.exports = Response;
