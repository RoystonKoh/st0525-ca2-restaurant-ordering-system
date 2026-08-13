# CA2 Requirements Traceability Matrix

This matrix maps the final source to the official **AY2627s1 ST0525 DBS CA2 Brief** and the supplied ORM, transaction, and indexing practicals.

| Official CA2 requirement | Final implementation evidence | Validation status |
| --- | --- | --- |
| Keep the five original restaurant table definitions unchanged. | `database/ca2_cart_checkout_indexes.sql` and `database/ca2_official_pricing_and_transactions.sql` add only Cart, CartItem, PricingRule, Voucher, CartVoucher, and OrderPricing entities. | Verified: clean-schema check returned zero prohibited original-table pricing columns. |
| Cart and CartItem ORM model design with documented relationships/constraints. | `prisma/schema.prisma`, `docs/erd_ca2.mmd`, `docs/erd_ca2.png`. | Implemented and rendered. |
| Add, retrieve all, update one, and delete one cart item using Prisma. | `models/Cart.js`, `controllers/cartController.js`, `routes/cart.js`, `/cart/create`, `/cart/retrieve/all`. | Verified by real HTTP CRUD test. |
| Summary computed in the back end with validation/error handling. | `Cart.getActive`, `PricingService.calculate`, controller quantity validation, database constraints. | Verified by automated and HTTP tests. |
| Product quantity discount and total cart value discount, both stackable. | `pricing_rule`, `PricingService`, customer Cart/Checkout pages. | Verified: 15% product tier plus 5% cart discount. |
| Delivery/service pricing with free-delivery and tiered rules. | `DELIVERY_TIER` rules, `PricingService`, customer UI, admin management panel. | Verified: `$5.00` tier and `$0.00` automatic free-delivery tier. |
| Optional customer voucher selection and delivery breakdown. | `voucher`, `cart_voucher`, `models/Voucher.js`, Cart dropdown, Checkout summary, `order_pricing` voucher fields. | Verified in HTTP flow for `WELCOME10`, `SAVE5`, and `FREEDELIVERY`; automatic tier selection occurs before voucher application. |
| Extensible rules including additional product tiers. | Data-driven `pricing_rule` rows; administrator create/edit/activate/deactivate controls. | Verified by admin HTTP create/deactivate test. |
| End-to-end checkout. | `views/checkout.html`, `controllers/checkoutController.js`, `routes/checkout.js`, `order_pricing`. | Verified through real customer session. |
| Required `place_orders` procedure. | `database/ca2_official_pricing_and_transactions.sql`, `database/functions_&_stored_procedures.sql`. | Verified in clean PostgreSQL database. |
| Available item is ordered/removed; unavailable item stays; all-unavailable cart produces no order. | Procedure loop plus `tests/official_ca2_transaction_checks.sql`. | Both appendix-style scenarios passed. |
| Discount calculations are not contained in `place_orders`. | `services/PricingService.js` evaluates rules; procedure only processes cart items and orders. | Code and SQL inspected; validated by checkout flow. |
| Six manufacturer queries/indexes with performance evidence. | `database/manufacturer_indexing.sql`, `database/manufacturer_benchmark.sql`, plan outputs, `docs/MANUFACTURER_INDEX_RESULTS.md`. | Six real before/after plans captured from the 818,244-row backup. |
| Complete report/evidence and interview support. | Report, guide, ERD, validation evidence, and runbook in project root/docs. | Final personalisation and student screenshots remain required. |

> The final implementation uses **automatic data-driven pricing rules** for all CA2-required promotions and delivery tiers. It additionally provides a customer-selected, reusable optional voucher feature; the CA2 brief does not require one-time voucher redemption.
