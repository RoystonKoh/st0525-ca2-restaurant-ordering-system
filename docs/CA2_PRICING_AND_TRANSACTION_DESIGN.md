# CA2 Pricing, Delivery, Administration, and Transaction Design

## Design intent

The CA2 brief requires a rule-driven checkout. The solution therefore introduces **data-driven automatic pricing rules** that an administrator can maintain on the existing dashboard. During checkout, the server retrieves all active rules, determines which rules apply to the active cart, calculates a transparent price breakdown, and allows the applicable product and cart-value discounts to stack. The Cart also offers a dropdown through which a shopper can choose one optional reusable voucher; voucher selection is deliberately separate from the required automatic rule engine.

## New entities

| Entity | Key attributes | Purpose and relationship |
| --- | --- | --- |
| `pricing_rule` | `pricing_rule_id`, `name`, `rule_scope`, `rule_type`, `product_id`, `minimum_quantity`, `minimum_cart_value`, `maximum_cart_value`, `discount_percent`, `delivery_fee`, `priority`, `is_active` | Stores all product, cart-value, and delivery/service rule definitions. A product-quantity rule optionally relates to one `product`; cart and delivery rules are not product-specific. |
| `voucher` | `voucher_id`, `code`, `name`, `voucher_type`, `voucher_value`, `minimum_cart_value`, `is_active`, `description` | Stores optional active `PERCENT`, `FIXED`, and `FREE_DELIVERY` customer offers without modifying restaurant tables. |
| `cart_voucher` | `cart_id`, `voucher_id`, timestamps | Uses `cart_id` as its primary key, meaning an active cart can select zero or one voucher. |
| `order_pricing` | `order_id`, `items_subtotal`, product/cart discounts, `voucher_code`, voucher savings, delivery fee/saving, `final_total`, `pricing_snapshot` | Stores a one-to-one immutable pricing snapshot for each successfully created sale order. It avoids altering the original `sale_order` schema while preserving the amounts that were calculated before placing the order. |

The existing `cart`, `cart_item`, `member`, `product`, `sale_order`, and `sale_order_item` tables remain the business core. Cart CRUD is performed using Prisma. The new tables make the pricing design extensible without hard-coding rules in controllers or browser JavaScript.

## Rule types and stacking policy

| Rule scope | Rule type | Example seeded rule | Evaluation policy |
| --- | --- | --- | --- |
| Product | `PRODUCT_QUANTITY_PERCENT` | Buy 3 of a specified product, get 10% off that product line. | For a given product, only the highest eligible active quantity tier applies; for example, Buy 5 at 15% replaces Buy 3 at 10% rather than incorrectly taking both. |
| Cart | `CART_VALUE_PERCENT` | Spend $100, get 5% off the remaining item subtotal. | Applies after the product-quantity discount; this is the second stackable product discount required by the brief. |
| Delivery | `DELIVERY_TIER` | Subtotal below $50: $8; $50–$99.99: $5; $100+: free. | The best matching tier is selected by value range. A zero fee is the required free-delivery case. |
| Customer voucher | `PERCENT`, `FIXED`, `FREE_DELIVERY` | `WELCOME10`, `SAVE5`, `FREEDELIVERY`. | One active voucher can be selected per cart. It is evaluated after all automatic CA2 rules and is returned as a separate price line. |

The price calculation is performed on the back end. The sequence is: item subtotal → product-quantity discount → cart-value discount → automatic delivery-tier selection → optional `PERCENT`/`FIXED` item voucher or `FREE_DELIVERY` saving → final total. A voucher therefore cannot alter the automatic delivery tier. Each rule or voucher amount is returned to the Cart and Checkout UI so the member can understand exactly why an amount changed.

## Administrator management design

The existing administrator dashboard receives a new **Promotion and Delivery Rules** panel. It is protected by the existing `ensureAuthenticated` and `ensureAdmin` middleware. The administrator can view rules, create a rule, edit rule values, and activate/deactivate rules. This fits the restaurant context: the restaurant manager controls seasonal menu promotions and delivery fees without a developer changing application code.

## Required order-processing procedure

The procedure is named **`place_orders`**, exactly as specified. It deliberately does not calculate discount eligibility or delivery rules. The checkout controller calculates and validates a pricing snapshot before it calls the procedure.

The procedure loops through cart items. For an available item, it creates the order header if necessary, writes the order item, and removes that cart item. For an unavailable item, it records it as skipped and leaves it in the cart. It does not throw an exception merely because one item is unavailable. Consequently, the required appendix outcomes are achieved: partially available carts produce an order containing only available items, while an all-unavailable cart creates no order and leaves all items in the cart.

## Validation strategy

The verification suite runs the procedure under both appendix scenarios and exercises the rule engine through a live Express session. It tests a product quantity rule, a higher quantity tier, a cart-value rule, delivery tiers, `WELCOME10`, `SAVE5`, `FREEDELIVERY`, administrator changes, a partially available cart, and an all-unavailable cart.
