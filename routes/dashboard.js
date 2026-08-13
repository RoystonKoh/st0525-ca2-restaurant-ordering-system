const express = require('express');
const DashboardController = require('../controllers/dashboardController');
const PricingRuleController = require('../controllers/pricingRuleController');
const { ensureAuthenticated, ensureAdmin } = require('../middleware/auth');

const router = express.Router();
router.use(ensureAuthenticated, ensureAdmin);

router.get('/', DashboardController.showDashboard);
router.get('/summary', DashboardController.getSummary);
router.put('/orders/:orderId/status', DashboardController.updateOrderStatus);

// Operational controls for restaurant promotions and delivery pricing.
router.get('/pricing-rules', PricingRuleController.list);
router.post('/pricing-rules', PricingRuleController.create);
router.put('/pricing-rules/:pricingRuleId', PricingRuleController.update);
router.patch('/pricing-rules/:pricingRuleId/active', PricingRuleController.setActive);

module.exports = router;
