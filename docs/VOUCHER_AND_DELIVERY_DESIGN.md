# Voucher Selection and Delivery Pricing Design

The required CA2 pricing rules remain automatic. Product-quantity and cart-value rules continue to stack, and the delivery tier remains selected from the calculated orderable subtotal. The customer-facing voucher drop-down is an additional checkout feature: the shopper may select **one optional voucher** from the active voucher list.

| Layer | Design decision |
| --- | --- |
| Voucher catalogue | New `voucher` table stores code, name, type, threshold, value, active status, and description. It does not alter any original restaurant table. |
| Customer selection | New `cart_voucher` table stores at most one selected voucher for an active Cart. The customer can select or clear it from the Cart page. |
| Voucher types | `PERCENT`, `FIXED`, and `FREE_DELIVERY`. Vouchers are reusable because the CA2 brief does not require one-time redemption. |
| Evaluation order | Product quantity discount → automatic cart-value discount → automatic delivery-tier selection → optional PERCENT/FIXED voucher or FREE_DELIVERY saving. The voucher cannot change the automatic delivery tier. |
| Stacking | The automatic CA2 discounts still stack. An eligible optional voucher then provides an additional, transparent discount. The Cart/Checkout summary shows each amount separately. |
| Persistence | The new `order_pricing` row records voucher code and voucher saving with the existing pricing snapshot. `place_orders` remains unchanged: it processes items and does not calculate incentives. |
| Delivery presentation | Cart and Checkout display the standard delivery fee, matching tier, delivery fee after tier, voucher delivery saving (if selected), and the final delivery charge. |

Seeded vouchers are `WELCOME10` (10% off eligible orderable items), `SAVE5` ($5 off eligible orderable items), and `FREEDELIVERY` (waives delivery when eligible). The administrator can manage the automatic PricingRule data as before; voucher selection is intentionally customer-facing and optional.
