const express = require('express');
const OrderController = require('../controllers/orderController');
const { ensureAuthenticated } = require('../middleware/auth');

const router = express.Router();

router.post('/', ensureAuthenticated, OrderController.createOrder);
router.get('/product/:productId', ensureAuthenticated, OrderController.getProductHistory);

module.exports = router;
