const express = require('express');
const CartController = require('../controllers/cartController');
const { ensureAuthenticated, ensureCustomer } = require('../middleware/auth');

const router = express.Router();

router.use(ensureAuthenticated, ensureCustomer);
router.get('/', CartController.getCart);
router.post('/items', CartController.addItem);
router.patch('/items/:cartItemId', CartController.updateItem);
router.delete('/items/:cartItemId', CartController.deleteItem);

module.exports = router;
