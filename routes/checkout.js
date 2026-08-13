const express = require('express');
const CheckoutController = require('../controllers/checkoutController');
const { ensureAuthenticated, ensureCustomer } = require('../middleware/auth');

const router = express.Router();

router.use(ensureAuthenticated, ensureCustomer);
router.get('/preview', CheckoutController.preview);
router.post('/', CheckoutController.placeOrder);

module.exports = router;
