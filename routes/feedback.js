const express = require('express');
const FeedbackController = require('../controllers/feedbackController');
const { ensureAuthenticated } = require('../middleware/auth');

const router = express.Router();

router.get('/product/:id', ensureAuthenticated, FeedbackController.getProductFeedback);
router.get('/mine', ensureAuthenticated, FeedbackController.getMyFeedback);
router.post('/', ensureAuthenticated, FeedbackController.createFeedback);
router.put('/:id', ensureAuthenticated, FeedbackController.updateFeedback);
router.delete('/:id', ensureAuthenticated, FeedbackController.deleteFeedback);

module.exports = router;
