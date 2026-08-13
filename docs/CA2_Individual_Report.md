# CA2 Individual Report — Restaurant Ordering, Pricing Rules, and Manufacturer Indexing

| Submission field | Replace before submission |
| --- | --- |
| **Student name** | `[[REPLACE_WITH_YOUR_FULL_NAME]]` |
| **Student ID** | `[[REPLACE_WITH_YOUR_P_NUMBER]]` |
| **Class** | `[[REPLACE_WITH_YOUR_CLASS]]` |
| **GitHub repository** | `https://github.com/[[YOUR_USERNAME]]/[[YOUR_REPOSITORY]]` |
| **Evidence-link base** | `https://github.com/[[YOUR_USERNAME]]/[[YOUR_REPOSITORY]]/blob/main/` |

> **Submission integrity note.** Replace the identity and GitHub placeholders, push this exact final source to the repository requested by the lecturer, and insert screenshots from your own restored database and application session. No personal identity, repository URL, or student-local screenshot has been invented in this report.

## 1. Database Design and ORM Modelling

The solution keeps the five original restaurant tables (`member`, `member_role`, `product`, `sale_order`, and `sale_order_item`) structurally unchanged. It adds the required **Cart** and **CartItem** entities, two pricing-policy entities (**PricingRule** and **OrderPricing**), and two optional customer-voucher entities (**Voucher** and **CartVoucher**). This design follows the CA2 instruction to use ORM models for cart management and supports data-driven product and delivery/service incentives without modifying an original restaurant table. [1]

![Final CA2 Entity Relationship Diagram](erd_ca2.png)

| New entity | Key attributes and constraints | Relationship and rationale |
| --- | --- | --- |
| `cart` | `cart_id`, `member_id`, `status`, timestamps; partial unique index ensures one active cart per member. | A member owns carts. Cart data is mutable and independent from historical orders. |
| `cart_item` | `cart_item_id`, `cart_id`, `product_id`, positive `quantity`; unique `(cart_id, product_id)`. | A cart contains product lines. The uniqueness rule means adding the same product increments quantity through Prisma `upsert` rather than duplicating rows. |
| `pricing_rule` | Scope, type, optional product target, quantity/cart thresholds, discount percentage, delivery fee, priority, active state. | Represents configurable product-quantity, cart-value, and delivery-tier policies. New tiers can be added in data by an administrator. |
| `voucher` | Unique code, name, type (`PERCENT`, `FIXED`, or `FREE_DELIVERY`), value, threshold, active state, description. | Holds optional reusable customer offers in a new table without changing the restaurant tables. |
| `cart_voucher` | `cart_id` is the primary key; `voucher_id` is a foreign key. | Gives each active cart zero or one selected voucher, which a customer can select or clear. |
| `order_pricing` | One `order_id`, item subtotal, product/cart discounts, voucher code/savings, delivery fee/savings, final total, JSON pricing snapshot. | Stores the immutable calculated result for a newly created order without altering the original `sale_order` table. |

The Prisma schema maps all original and new relations using `@map` and `@@map`. Cart operations use the Prisma methods taught in the ORM practicals: `findFirst`, `create`, `upsert`, `update`, and `delete`. The customer cart summary is calculated on the back end after the ORM query, not trusted from browser input. [2]

| Evidence | Repository path to link after pushing |
| --- | --- |
| Prisma models and relationships | [`prisma/schema.prisma`]([[GITHUB_BASE]]prisma/schema.prisma) |
| Cart/CartItem migration and constraints | [`database/ca2_cart_checkout_indexes.sql`]([[GITHUB_BASE]]database/ca2_cart_checkout_indexes.sql) |
| Pricing and order-pricing migration | [`database/ca2_official_pricing_and_transactions.sql`]([[GITHUB_BASE]]database/ca2_official_pricing_and_transactions.sql) |
| ERD source and PNG | [`docs/erd_ca2.mmd`]([[GITHUB_BASE]]docs/erd_ca2.mmd) and [`docs/erd_ca2.png`]([[GITHUB_BASE]]docs/erd_ca2.png) |

**Suggested self-rating:** `[[CONFIRM_SCORE]] / 5`

## 2. Cart Management Feature Implementation

The end-to-end customer flow starts at `/cart/create`, which presents restaurant products and calls `POST /cart/items`. The protected Cart model obtains or creates the member’s active cart, validates product identity and a positive whole-number quantity, then uses Prisma `upsert` to create or increment one cart item. The member retrieves the complete cart at `/cart/retrieve/all`, changes a single line through `PATCH /cart/items/:cartItemId`, and deletes one line through `DELETE /cart/items/:cartItemId`. The API returns a fresh server-side summary after each change. [1]

| Layer | Implementation | CA2 purpose |
| --- | --- | --- |
| Customer pages | `views/products.html`, `views/cart.html`, `views/checkout.html` | Provides the required add, retrieve, update, delete, and end-to-end checkout interactions. |
| Protected routes | `routes/cart.js` | Exposes create/retrieve pages and authenticated customer API endpoints. |
| Controller validation | `controllers/cartController.js` | Rejects invalid IDs and non-integer/negative quantities before database operations. |
| Prisma model | `models/Cart.js` | Enforces active-cart ownership and performs ORM CRUD. |
| Database constraints | Cart/cart-item foreign keys, positive quantity check, unique product per cart | Prevents invalid rows even if a request bypasses browser controls. |

The cart accepts an unavailable product so that the required transaction behaviour can be demonstrated. Availability is shown clearly in the cart. At checkout, available items are processed and removed; unavailable items remain in the active cart, rather than causing prior work to be lost. This matches the appendix scenarios in the CA2 brief. [1]

### Screenshot evidence to insert

1. Add one available product from `/cart/create` and show the success message/cart badge.
2. Show `/cart/retrieve/all` with at least two cart items, backend subtotals, quantity update controls, and a delete action.
3. Show a server-side validation message by entering `0`, a negative value, or text in a request/quantity test.
4. Show one unavailable item labelled as retained for partial processing.

**Suggested self-rating:** `[[CONFIRM_SCORE]] / 5`

## 3. Checkout, Stackable Discounts, Delivery Pricing, and Administration

The checkout preview is calculated by `PricingService` on the server. It first evaluates all active automatic rules in `pricing_rule`: the highest eligible quantity tier per targeted product, then an eligible cart-value percentage discount against the post-product-discount subtotal, then the automatic delivery tier. The seeded tiers demonstrate `$8` under `$50`, `$5` from `$50` to `$99.99`, and free delivery from `$100`. These automatic rules stack as required. After that sequence, the shopper may optionally select one active `Voucher` in the Cart dropdown. `PERCENT` and `FIXED` vouchers reduce the automatic discounted items total; `FREE_DELIVERY` waives the already-selected delivery-tier fee. A voucher cannot change the automatic delivery tier. [1]

| Requirement | Final implementation | Demonstration result |
| --- | --- | --- |
| Product quantity discount | `PRODUCT_QUANTITY_PERCENT` rule with a product, minimum quantity, percentage, and priority. | Buy 3 of the target product applies 10%; Buy 5 applies the higher 15% tier. |
| Cart total discount | `CART_VALUE_PERCENT` rule with a cart threshold and percentage. | Spend `$100` triggers 5% after the product quantity discount. |
| Stackable discounts | The pricing service adds product and cart-value discounts in sequence. | `$130` orderable subtotal: `$15.00` product discount plus `$5.75` cart discount. |
| Delivery/service discount | `DELIVERY_TIER` rules use minimum/maximum cart value and a delivery fee. | The same high-value test selects the `$0.00` free-delivery tier. |
| Optional `PERCENT` voucher | `WELCOME10` is selected in the Cart dropdown after automatic rules. | `$5.40` additional item saving on the Buy 3 scenario; the `$5.00` automatic tier remains unchanged. |
| Optional `FIXED` voucher | `SAVE5` is selected in the Cart dropdown after automatic rules. | `$5.00` additional saving on the high-value stacked-rule scenario. |
| Optional `FREE_DELIVERY` voucher | `FREEDELIVERY` is selected after automatic delivery-tier evaluation. | The `$5.00` tier charge is shown as a voucher delivery saving and final delivery becomes `$0.00`. |
| Flexibility/extensibility | Rules are rows, not hard-coded checkout conditions; voucher selection is stored separately per cart. | Administrator can add automatic product or delivery tiers; customers choose one optional active voucher without editing policy data. |

The administrator management panel extends the existing restaurant dashboard. It is protected by the project’s existing `ensureAdmin` middleware. An administrator can view products and rules, create a product-quantity/cart-value/delivery-tier rule, edit it, and activate or deactivate it. This represents a sensible restaurant-management responsibility rather than exposing technical database controls to customers.

| Evidence | Repository path to link after pushing |
| --- | --- |
| Pricing service | [`services/PricingService.js`]([[GITHUB_BASE]]services/PricingService.js) |
| Rule ORM model | [`models/PricingRule.js`]([[GITHUB_BASE]]models/PricingRule.js) |
| Admin controller/routes | [`controllers/pricingRuleController.js`]([[GITHUB_BASE]]controllers/pricingRuleController.js) and [`routes/dashboard.js`]([[GITHUB_BASE]]routes/dashboard.js) |
| Admin UI | [`views/dashboard.html`]([[GITHUB_BASE]]views/dashboard.html) and [`public/js/dashboard.js`]([[GITHUB_BASE]]public/js/dashboard.js) |

### Screenshot evidence to insert

1. A Cart screenshot showing the optional voucher dropdown and the standard fee, tier saving, voucher saving (when relevant), final delivery fee, and final total.
2. A Checkout screenshot showing a selected voucher alongside the applied automatic product/cart rules and delivery breakdown.
3. An administrator dashboard screenshot showing the Promotion and Delivery Rules table and a rule creation/edit form.
4. A free-delivery result using either the automatic high-value tier or `FREEDELIVERY`.

**Suggested self-rating:** `[[CONFIRM_SCORE]] / 5`

## 4. Transaction Management

The required procedure is named `public.place_orders`. The checkout controller calculates discount and delivery eligibility before calling it, then calls the procedure using the member ID. The procedure itself intentionally contains only cart-item and order processing logic, as required by the brief. It locks the active cart and loops through every cart item. When a product is available, it creates the order header if needed, creates an order item, and removes that cart item. When a product is unavailable, it increments a skipped count and leaves that item in the cart. It does not roll back items already processed merely because a later item is unavailable. [1]

| CA2 scenario | Expected database result | Verified outcome |
| --- | --- | --- |
| Available item followed by unavailable item | One sale order and one sale order item exist; available cart item is deleted; unavailable item remains. | Passed in `tests/official_ca2_transaction_checks.sql`. |
| All cart items unavailable | No new sale order/sale order item is created; all items remain in the cart. | Passed in `tests/official_ca2_transaction_checks.sql`. |
| Customer checkout call | Pricing snapshot is persisted in new `order_pricing` only after `place_orders` returns an order ID. | Passed through the running Express application. |

The controller subsequently performs a Prisma `$transaction` to update the newly created order’s final amount and create the immutable `order_pricing` snapshot, including the selected voucher code, item voucher saving, delivery voucher saving, and full pricing snapshot. This separates the procedure’s required cart-processing responsibility from the application’s rule evaluation responsibility. [3]

| Evidence | Repository path to link after pushing |
| --- | --- |
| Required procedure definition | [`database/functions_&_stored_procedures.sql`]([[GITHUB_BASE]]database/functions_%26_stored_procedures.sql) |
| Official migration | [`database/ca2_official_pricing_and_transactions.sql`]([[GITHUB_BASE]]database/ca2_official_pricing_and_transactions.sql) |
| Checkout controller | [`controllers/checkoutController.js`]([[GITHUB_BASE]]controllers/checkoutController.js) |
| Appendix scenario test script | [`tests/official_ca2_transaction_checks.sql`]([[GITHUB_BASE]]tests/official_ca2_transaction_checks.sql) |

### Screenshot evidence to insert

1. `CALL public.place_orders(...)` or the test output showing Scenario 1 passed.
2. The resulting `sale_order`, `sale_order_item`, and remaining unavailable `cart_item` query results.
3. Scenario 2 output proving no new order was created when all items were unavailable.

**Suggested self-rating:** `[[CONFIRM_SCORE]] / 5`

## 5. Manufacturer Queries and Indexing

The separate manufacturer database was restored without being connected to the application. Six queries were proposed against its `manufacturer` table, and six matching indexes were created. This follows the indexing practical’s method: first observe the actual plan with `EXPLAIN ANALYSE`, create an index that matches the predicate/expression/selected columns, then rerun the same query and record the plan and execution time. [4]

| Query | Purpose and index | Before time | After time | Result |
| --- | --- | ---: | ---: | --- |
| Q1 | Case-insensitive support-email lookup; function index `LOWER(support_email)`. | 146.236 ms | 0.080 ms | Bitmap index scan; 99.95% lower. |
| Q2 | Operating manufacturers by origin/category; composite `(origin, product_category, is_operational)`. | 50.823 ms | 44.842 ms | Bitmap index scan; 11.77% lower. |
| Q3 | Category and founded-date range; composite `(product_category, founded_since)`. | 47.819 ms | 26.441 ms | Bitmap index scan; 44.70% lower. |
| Q4 | Origin plus employee-count range; composite `(origin, employee_count)`. | 43.875 ms | 24.875 ms | Bitmap index scan; 43.30% lower. |
| Q5 | Founded year; function index `EXTRACT(YEAR FROM founded_since)`. | 76.168 ms | 22.274 ms | Bitmap index scan; 70.76% lower. |
| Q6 | Employee aggregate for category/operational status; covering `(product_category, is_operational, employee_count)`. | 50.403 ms | 5.632 ms | Index-only scan; 88.83% lower. |

The before-and-after output was collected on the supplied manufacturer backup containing 818,244 rows. The marker should see the exact SQL, raw plan outputs, and concise reasoning in the repository. Performance results can differ on another machine; the report therefore states the database and evidence files used rather than claiming a universal runtime.

| Evidence | Repository path to link after pushing |
| --- | --- |
| Six index DDL statements | [`database/manufacturer_indexing.sql`]([[GITHUB_BASE]]database/manufacturer_indexing.sql) |
| Six `EXPLAIN ANALYSE` queries | [`database/manufacturer_benchmark.sql`]([[GITHUB_BASE]]database/manufacturer_benchmark.sql) |
| Raw pre-index plans | [`docs/manufacturer_before_explain.txt`]([[GITHUB_BASE]]docs/manufacturer_before_explain.txt) |
| Raw post-index plans | [`docs/manufacturer_after_explain.txt`]([[GITHUB_BASE]]docs/manufacturer_after_explain.txt) |
| Interpretation table | [`docs/MANUFACTURER_INDEX_RESULTS.md`]([[GITHUB_BASE]]docs/MANUFACTURER_INDEX_RESULTS.md) |

**Suggested self-rating:** `[[CONFIRM_SCORE]] / 5`

## 6. Validation and Final Submission Checklist

The source passed ten automated requirement checks, Prisma validation/client generation, JavaScript syntax validation, two clean-database procedure scenarios, customer cart CRUD, stackable automatic pricing/delivery tests, `PERCENT`, `FIXED`, and `FREE_DELIVERY` voucher tests, access-control tests, administrator rule CRUD, and six manufacturer plan comparisons. The detailed log is included in `VALIDATION_EVIDENCE.md`.

| Final action before upload | Complete? |
| --- | --- |
| Replace all student/GitHub placeholders in this report | `[[YES/NO]]` |
| Push the final project to the correct GitHub repository and make it accessible to the marker | `[[YES/NO]]` |
| Reproduce or import the ERD in Lucidchart, if your lecturer specifically requires Lucidchart evidence | `[[YES/NO]]` |
| Insert your own customer, checkout, admin, and transaction screenshots | `[[YES/NO]]` |
| Insert your own manufacturer pgAdmin `EXPLAIN ANALYSE` screenshots if required | `[[YES/NO]]` |
| Verify all report links after replacing `[[GITHUB_BASE]]` | `[[YES/NO]]` |

## References

[1]: AY2627s1ST0525DBSCA2Brief-final.pdf "ST0525 DBS CA2 Brief"
[2]: PracticalORM3CRUDv2.pdf "Practical ORM 3: CRUD"
[3]: PracticalTransactionsv3.pdf "Practical Transactions"
[4]: PracticalIndexingv1.pdf "Practical Indexing"
