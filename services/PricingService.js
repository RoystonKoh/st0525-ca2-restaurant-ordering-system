const PricingRule = require('../models/PricingRule');

const roundMoney = (value) => Number(Number(value || 0).toFixed(2));

class PricingService {
  static async calculate(cart) {
    const activeRules = await PricingRule.listActive();
    const orderableItems = cart.items.filter((item) => item.product.is_available);
    const unavailableItems = cart.items.filter((item) => !item.product.is_available);
    const itemsSubtotal = roundMoney(orderableItems.reduce((sum, item) => sum + item.subtotal, 0));
    const unavailableValue = roundMoney(unavailableItems.reduce((sum, item) => sum + item.subtotal, 0));
    const appliedRules = [];

    // Required CA2 automatic product quantity rules.
    const productRules = activeRules.filter((rule) => rule.ruleType === 'PRODUCT_QUANTITY_PERCENT');
    let productDiscountAmount = 0;
    for (const item of orderableItems) {
      const eligible = productRules
        .filter((rule) => rule.productId === item.product_id && item.quantity >= rule.minimumQuantity)
        .sort((a, b) => b.priority - a.priority || Number(b.discountPercent) - Number(a.discountPercent));
      if (eligible.length > 0) {
        const rule = eligible[0];
        const amount = roundMoney(item.subtotal * (Number(rule.discountPercent) / 100));
        productDiscountAmount = roundMoney(productDiscountAmount + amount);
        appliedRules.push({
          pricing_rule_id: rule.pricingRuleId,
          name: rule.name,
          scope: rule.ruleScope,
          type: rule.ruleType,
          product_id: item.product_id,
          product_name: item.product.name,
          rate: Number(rule.discountPercent),
          amount,
          description: `${rule.name}: ${rule.discountPercent}% off ${item.product.name}.`,
        });
      }
    }

    // Required CA2 automatic cart-value rule; it stacks after product rules.
    const afterProductDiscount = roundMoney(itemsSubtotal - productDiscountAmount);
    const cartRules = activeRules
      .filter((rule) => rule.ruleType === 'CART_VALUE_PERCENT' && afterProductDiscount >= Number(rule.minimumCartValue))
      .sort((a, b) => b.priority - a.priority || Number(b.minimumCartValue) - Number(a.minimumCartValue));
    let cartDiscountAmount = 0;
    if (cartRules.length > 0) {
      const rule = cartRules[0];
      cartDiscountAmount = roundMoney(afterProductDiscount * (Number(rule.discountPercent) / 100));
      appliedRules.push({
        pricing_rule_id: rule.pricingRuleId,
        name: rule.name,
        scope: rule.ruleScope,
        type: rule.ruleType,
        rate: Number(rule.discountPercent),
        amount: cartDiscountAmount,
        description: `${rule.name}: ${rule.discountPercent}% off after product discounts.`,
      });
    }

    const afterAutomaticDiscounts = roundMoney(afterProductDiscount - cartDiscountAmount);
    // All automatic CA2 rules are resolved before an optional voucher is considered.
    // The delivery tier therefore depends only on the automatic discounted orderable total.
    const standardDeliveryFee = 8;
    let tierDeliveryFee = standardDeliveryFee;
    let deliveryRule = null;
    const deliveryRules = activeRules
      .filter((rule) => rule.ruleType === 'DELIVERY_TIER'
        && afterAutomaticDiscounts >= Number(rule.minimumCartValue)
        && (rule.maximumCartValue === null || afterAutomaticDiscounts <= Number(rule.maximumCartValue)))
      .sort((a, b) => b.priority - a.priority || Number(b.minimumCartValue) - Number(a.minimumCartValue));

    if (deliveryRules.length > 0) {
      deliveryRule = deliveryRules[0];
      tierDeliveryFee = roundMoney(Number(deliveryRule.deliveryFee));
      appliedRules.push({
        pricing_rule_id: deliveryRule.pricingRuleId,
        name: deliveryRule.name,
        scope: deliveryRule.ruleScope,
        type: deliveryRule.ruleType,
        amount: roundMoney(standardDeliveryFee - tierDeliveryFee),
        delivery_fee: tierDeliveryFee,
        description: `${deliveryRule.name}: delivery fee is $${tierDeliveryFee.toFixed(2)}.`,
      });
    }

    const selectedVoucher = cart.voucherSelection?.voucher || null;
    let voucherDiscountAmount = 0;
    let voucherDeliverySaving = 0;
    let voucherMessage = 'No voucher selected.';

    // Optional customer-selected voucher. It supplements—not replaces—the automatic CA2 rules above.
    if (selectedVoucher) {
      const minimumValue = Number(selectedVoucher.minimumCartValue || 0);
      if (orderableItems.length === 0) {
        voucherMessage = `${selectedVoucher.code} cannot be applied because there are no available items.`;
      } else if (afterAutomaticDiscounts < minimumValue) {
        voucherMessage = `${selectedVoucher.code} requires an orderable subtotal of at least $${minimumValue.toFixed(2)} after automatic discounts.`;
      } else if (selectedVoucher.voucherType === 'PERCENT') {
        voucherDiscountAmount = roundMoney(afterAutomaticDiscounts * (Number(selectedVoucher.voucherValue) / 100));
        voucherMessage = `${selectedVoucher.code}: ${selectedVoucher.voucherValue}% voucher discount applied after automatic rules.`;
      } else if (selectedVoucher.voucherType === 'FIXED') {
        voucherDiscountAmount = roundMoney(Math.min(afterAutomaticDiscounts, Number(selectedVoucher.voucherValue)));
        voucherMessage = `${selectedVoucher.code}: $${Number(selectedVoucher.voucherValue).toFixed(2)} voucher discount applied after automatic rules.`;
      } else if (selectedVoucher.voucherType === 'FREE_DELIVERY') {
        voucherDeliverySaving = tierDeliveryFee;
        voucherMessage = `${selectedVoucher.code}: free-delivery voucher applied after delivery-tier pricing.`;
      }
    }

    const itemsTotalAfterVoucher = roundMoney(afterAutomaticDiscounts - voucherDiscountAmount);
    if (orderableItems.length === 0) {
      tierDeliveryFee = 0;
      voucherDeliverySaving = 0;
      deliveryRule = null;
      const deliveryRulePosition = appliedRules.findIndex((rule) => rule.type === 'DELIVERY_TIER');
      if (deliveryRulePosition >= 0) appliedRules.splice(deliveryRulePosition, 1);
    }

    const deliveryFee = roundMoney(Math.max(0, tierDeliveryFee - voucherDeliverySaving));
    const deliveryDiscountAmount = orderableItems.length === 0 ? 0 : roundMoney(Math.max(0, standardDeliveryFee - tierDeliveryFee));
    const finalTotal = roundMoney(itemsTotalAfterVoucher + deliveryFee);

    return {
      all_cart_items_subtotal: roundMoney(itemsSubtotal + unavailableValue),
      items_subtotal: itemsSubtotal,
      unavailable_items_value: unavailableValue,
      product_discount_amount: productDiscountAmount,
      cart_discount_amount: cartDiscountAmount,
      total_product_discount_amount: roundMoney(productDiscountAmount + cartDiscountAmount),
      discounted_items_total: afterAutomaticDiscounts,
      voucher_discount_amount: voucherDiscountAmount,
      items_total_after_voucher: itemsTotalAfterVoucher,
      selected_voucher: selectedVoucher ? {
        code: selectedVoucher.code,
        name: selectedVoucher.name,
        type: selectedVoucher.voucherType,
        minimum_cart_value: Number(selectedVoucher.minimumCartValue),
        item_discount_amount: voucherDiscountAmount,
        delivery_saving: voucherDeliverySaving,
        message: voucherMessage,
      } : null,
      standard_delivery_fee: standardDeliveryFee,
      delivery_tier_fee: tierDeliveryFee,
      delivery_fee: deliveryFee,
      delivery_discount_amount: deliveryDiscountAmount,
      voucher_delivery_saving: voucherDeliverySaving,
      delivery_rule: deliveryRule ? {
        pricing_rule_id: deliveryRule.pricingRuleId,
        name: deliveryRule.name,
        minimum_cart_value: Number(deliveryRule.minimumCartValue),
        maximum_cart_value: deliveryRule.maximumCartValue === null ? null : Number(deliveryRule.maximumCartValue),
      } : null,
      final_total: finalTotal,
      applied_rules: appliedRules,
      orderable_item_count: orderableItems.reduce((sum, item) => sum + item.quantity, 0),
      unavailable_item_count: unavailableItems.reduce((sum, item) => sum + item.quantity, 0),
      can_place_order: orderableItems.length > 0,
      message: orderableItems.length === 0
        ? 'No available items can be processed. Unavailable items remain in the cart.'
        : unavailableItems.length > 0
          ? 'Available items will be processed; unavailable items will remain in your cart.'
          : 'All cart items are available for processing.',
    };
  }
}

module.exports = PricingService;
