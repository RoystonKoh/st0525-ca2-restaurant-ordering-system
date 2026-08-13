const prisma = require('../config/prisma');

const SCOPES = ['PRODUCT', 'CART', 'DELIVERY'];
const TYPES = ['PRODUCT_QUANTITY_PERCENT', 'CART_VALUE_PERCENT', 'DELIVERY_TIER'];

function toNumberOrNull(value) {
  return value === undefined || value === null || value === '' ? null : Number(value);
}

function validateRule(input) {
  const rule = {
    name: String(input.name || '').trim(),
    ruleScope: String(input.rule_scope || input.ruleScope || '').trim().toUpperCase(),
    ruleType: String(input.rule_type || input.ruleType || '').trim().toUpperCase(),
    productId: input.product_id || input.productId ? Number(input.product_id || input.productId) : null,
    minimumQuantity: input.minimum_quantity || input.minimumQuantity ? Number(input.minimum_quantity || input.minimumQuantity) : null,
    minimumCartValue: toNumberOrNull(input.minimum_cart_value ?? input.minimumCartValue),
    maximumCartValue: toNumberOrNull(input.maximum_cart_value ?? input.maximumCartValue),
    discountPercent: toNumberOrNull(input.discount_percent ?? input.discountPercent),
    deliveryFee: toNumberOrNull(input.delivery_fee ?? input.deliveryFee),
    priority: Number(input.priority ?? 0),
    isActive: input.is_active === undefined && input.isActive === undefined ? true : Boolean(input.is_active ?? input.isActive),
  };

  if (!rule.name) throw new Error('Rule name is required.');
  if (!SCOPES.includes(rule.ruleScope)) throw new Error('Rule scope must be PRODUCT, CART, or DELIVERY.');
  if (!TYPES.includes(rule.ruleType)) throw new Error('Rule type is invalid.');
  if (!Number.isInteger(rule.priority) || rule.priority < 0) throw new Error('Priority must be a non-negative whole number.');

  if (rule.ruleType === 'PRODUCT_QUANTITY_PERCENT') {
    if (rule.ruleScope !== 'PRODUCT' || !Number.isInteger(rule.productId) || rule.productId < 1) {
      throw new Error('A product quantity rule must select a product.');
    }
    if (!Number.isInteger(rule.minimumQuantity) || rule.minimumQuantity < 1) {
      throw new Error('A product quantity rule requires a minimum quantity of at least 1.');
    }
    if (!(rule.discountPercent > 0 && rule.discountPercent <= 100)) {
      throw new Error('A product quantity rule requires a discount percentage between 0 and 100.');
    }
  }

  if (rule.ruleType === 'CART_VALUE_PERCENT') {
    if (rule.ruleScope !== 'CART' || !(rule.minimumCartValue >= 0)) {
      throw new Error('A cart-value rule requires a minimum cart value of 0 or more.');
    }
    if (!(rule.discountPercent > 0 && rule.discountPercent <= 100)) {
      throw new Error('A cart-value rule requires a discount percentage between 0 and 100.');
    }
    rule.productId = null;
    rule.minimumQuantity = null;
  }

  if (rule.ruleType === 'DELIVERY_TIER') {
    if (rule.ruleScope !== 'DELIVERY' || !(rule.minimumCartValue >= 0) || !(rule.deliveryFee >= 0)) {
      throw new Error('A delivery tier requires a minimum cart value and a delivery fee of 0 or more.');
    }
    if (rule.maximumCartValue !== null && rule.maximumCartValue < rule.minimumCartValue) {
      throw new Error('Maximum cart value must be greater than or equal to minimum cart value.');
    }
    rule.productId = null;
    rule.minimumQuantity = null;
    rule.discountPercent = null;
  }

  return rule;
}

class PricingRule {
  static async listForAdmin() {
    return prisma.pricingRule.findMany({
      include: { product: { select: { productId: true, name: true } } },
      orderBy: [{ ruleScope: 'asc' }, { priority: 'desc' }, { pricingRuleId: 'asc' }],
    });
  }

  static async listActive() {
    return prisma.pricingRule.findMany({
      where: { isActive: true },
      include: { product: { select: { productId: true, name: true } } },
      orderBy: [{ ruleScope: 'asc' }, { priority: 'desc' }, { pricingRuleId: 'asc' }],
    });
  }

  static async create(input) {
    const rule = validateRule(input);
    if (rule.productId) {
      const product = await prisma.product.findUnique({ where: { productId: rule.productId }, select: { productId: true } });
      if (!product) throw new Error('Selected product does not exist.');
    }
    return prisma.pricingRule.create({ data: rule, include: { product: { select: { productId: true, name: true } } } });
  }

  static async update(pricingRuleId, input) {
    const existing = await prisma.pricingRule.findUnique({ where: { pricingRuleId } });
    if (!existing) throw new Error('Pricing rule not found.');
    const rule = validateRule({ ...existing, ...input });
    if (rule.productId) {
      const product = await prisma.product.findUnique({ where: { productId: rule.productId }, select: { productId: true } });
      if (!product) throw new Error('Selected product does not exist.');
    }
    return prisma.pricingRule.update({
      where: { pricingRuleId },
      data: rule,
      include: { product: { select: { productId: true, name: true } } },
    });
  }

  static async setActive(pricingRuleId, isActive) {
    return prisma.pricingRule.update({
      where: { pricingRuleId },
      data: { isActive: Boolean(isActive) },
      include: { product: { select: { productId: true, name: true } } },
    });
  }
}

module.exports = PricingRule;
