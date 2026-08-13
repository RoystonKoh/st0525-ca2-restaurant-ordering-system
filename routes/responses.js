const express = require('express');
const ResponseController = require('../controllers/responseController');
const { ensureAuthenticated } = require('../middleware/auth');

const router = express.Router();

router.post('/', ensureAuthenticated, ResponseController.createResponse);
router.delete('/:id', ensureAuthenticated, ResponseController.deleteResponse);

module.exports = router;
