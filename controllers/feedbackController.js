const Feedback = require('../models/Feedback');
const Response = require('../models/Response');

class FeedbackController {
    static async getProductFeedback(req, res) {
        try {
            const productId = Number(req.params.id);
            const feedback = await Feedback.getByProduct(productId);

            for (const item of feedback) {
                item.responses = await Response.getByFeedback(item.feedback_id);
                for (const response of item.responses) {
                    response.can_reply = response.member_id !== req.session.userId;
                    response.can_delete = response.member_id === req.session.userId;
                }
                item.can_edit = item.member_id === req.session.userId;
                item.can_respond = item.member_id !== req.session.userId;
            }

            res.json({ success: true, feedback });
        } catch (error) {
            console.error('Get feedback error:', error);
            res.status(500).json({ success: false, message: error.message });
        }
    }

    static async getMyFeedback(req, res) {
        try {
            const feedback = await Feedback.getByMember(req.session.userId);
            res.json({ success: true, feedback });
        } catch (error) {
            console.error('Get my feedback error:', error);
            res.status(500).json({ success: false, message: error.message });
        }
    }

    static async createFeedback(req, res) {
        try {
            const { product_id, rating, comments } = req.body;
            await Feedback.create(req.session.userId, product_id, rating, comments);
            res.json({ success: true, message: 'Feedback submitted successfully.' });
        } catch (error) {
            console.error('Create feedback error:', error);
            res.status(400).json({ success: false, message: error.message });
        }
    }

    static async updateFeedback(req, res) {
        try {
            const { rating, comments } = req.body;
            await Feedback.update(req.params.id, req.session.userId, rating, comments);
            res.json({ success: true, message: 'Feedback updated successfully.' });
        } catch (error) {
            console.error('Update feedback error:', error);
            res.status(400).json({ success: false, message: error.message });
        }
    }

    static async deleteFeedback(req, res) {
        try {
            await Feedback.delete(req.params.id, req.session.userId);
            res.json({ success: true, message: 'Feedback deleted successfully.' });
        } catch (error) {
            console.error('Delete feedback error:', error);
            res.status(400).json({ success: false, message: error.message });
        }
    }
}

module.exports = FeedbackController;
