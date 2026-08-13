const express = require('express');
const path = require('path');
const CartController = require('../controllers/cartController');
const { ensureAuthenticated, ensureCustomer } = require('../middleware/auth');

const router = express.Router();

router.use(ensureAuthenticated, ensureCustomer);

// Brief-aligned end-to-end pages.
router.get('/create', (req, res) => res.sendFile(path.join(__dirname, '../views/products.html')));
router.get('/retrieve/all', (req, res) => res.sendFile(path.join(__dirname, '../views/cart.html')));

// API endpoints remain callable from both the application and Postman.
router.get('/', CartController.getCart);
router.get('/vouchers', CartController.listVouchers);
router.put('/voucher', CartController.selectVoucher);
router.delete('/voucher', CartController.clearVoucher);
router.post('/items', CartController.addItem);
router.patch('/items/:cartItemId', CartController.updateItem);
router.delete('/items/:cartItemId', CartController.deleteItem);

module.exports = router;
