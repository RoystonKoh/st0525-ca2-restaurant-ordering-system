const PricingRule = require('../models/PricingRule');
const prisma = require('../config/prisma');

function parseRuleId(value) {
  const id = Number(value);
  if (!Number.isInteger(id) || id < 1) throw new Error('Pricing rule ID must be a positive whole number.');
  return id;
}

class PricingRuleController {
  static async list(req, res) {
    try {
      const [rules, products] = await Promise.all([
        PricingRule.listForAdmin(),
        prisma.product.findMany({ select: { productId: true, name: true, price: true, isAvailable: true }, orderBy: { name: 'asc' } }),
      ]);
      res.json({ success: true, rules, products });
    } catch (error) {
      console.error('List pricing rules error:', error);
      res.status(500).json({ success: false, message: 'Unable to load pricing rules.' });
    }
  }

  static async create(req, res) {
    try {
      const rule = await PricingRule.create(req.body);
      res.status(201).json({ success: true, message: 'Pricing rule created.', rule });
    } catch (error) {
      res.status(400).json({ success: false, message: error.message });
    }
  }

  static async update(req, res) {
    try {
      const rule = await PricingRule.update(parseRuleId(req.params.pricingRuleId), req.body);
      res.json({ success: true, message: 'Pricing rule updated.', rule });
    } catch (error) {
      res.status(400).json({ success: false, message: error.message });
    }
  }

  static async setActive(req, res) {
    try {
      if (typeof req.body.is_active !== 'boolean') throw new Error('is_active must be true or false.');
      const rule = await PricingRule.setActive(parseRuleId(req.params.pricingRuleId), req.body.is_active);
      res.json({ success: true, message: `Pricing rule ${rule.isActive ? 'activated' : 'deactivated'}.`, rule });
    } catch (error) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
}

module.exports = PricingRuleController;
