const Response = require('../models/Response');

class ResponseController {
    static async createResponse(req, res) {
        try {
            const { feedback_id, response_text, parent_response_id } = req.body;
            await Response.create(feedback_id, req.session.userId, response_text, parent_response_id);
            res.json({ success: true, message: 'Response submitted successfully.' });
        } catch (error) {
            console.error('Create response error:', error);
            res.status(400).json({ success: false, message: error.message });
        }
    }

    static async deleteResponse(req, res) {
        try {
            await Response.delete(req.params.id, req.session.userId);
            res.json({ success: true, message: 'Response deleted successfully.' });
        } catch (error) {
            console.error('Delete response error:', error);
            res.status(400).json({ success: false, message: error.message });
        }
    }
}

module.exports = ResponseController;
