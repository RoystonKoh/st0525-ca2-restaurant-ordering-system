const express = require('express');
const DashboardController = require('../controllers/dashboardController');
const { ensureAuthenticated, ensureAdmin } = require('../middleware/auth');

const router = express.Router();

router.get('/', ensureAuthenticated, ensureAdmin, DashboardController.showDashboard);
router.get('/summary', ensureAuthenticated, ensureAdmin, DashboardController.getSummary);
router.put('/orders/:orderId/status', ensureAuthenticated, ensureAdmin, DashboardController.updateOrderStatus);

module.exports = router;
