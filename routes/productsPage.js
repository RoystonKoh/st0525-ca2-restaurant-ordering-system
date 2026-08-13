// routes/productsPage.js
const express = require('express');
const path = require('path');
const { ensureAuthenticated } = require('../middleware/auth');

const router = express.Router();

// GET /member/products - serve products page
router.get('/products', ensureAuthenticated, (req, res) => {
  res.sendFile(path.join(__dirname, '../views/products.html'));
});

// GET /member/product-detail - serve product detail page
router.get('/product-detail', ensureAuthenticated, (req, res) => {
  res.sendFile(path.join(__dirname, '../views/product-detail.html'));
});

// GET /member/cart - serve cart page
router.get('/cart', ensureAuthenticated, (req, res) => {
  res.sendFile(path.join(__dirname, '../views/cart.html'));
});

// GET /member/checkout - serve checkout page
router.get('/checkout', ensureAuthenticated, (req, res) => {
  res.sendFile(path.join(__dirname, '../views/checkout.html'));
});

// GET /member/my-feedback - serve customer feedback history page
router.get('/my-feedback', ensureAuthenticated, (req, res) => {
  res.sendFile(path.join(__dirname, '../views/my-feedback.html'));
});

module.exports = router;
