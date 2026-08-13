# CA2 Intensive Validation Evidence

## Validation result

The final CA2 source was validated against clean, isolated PostgreSQL databases. The restaurant database tests used a controlled copy of the required schema and representative product/member data. The manufacturer tests used the supplied manufacturer backup restored with **818,244 rows**.

| Validation layer | Test | Result |
| --- | --- | --- |
| Automated structure tests | `npm test` | **10 / 10 passed**. |
| Prisma | `npx prisma validate` and `npx prisma generate` | Passed. |
| JavaScript | `node --check` over configuration, controllers, models, routes, middleware, browser JS, services, test code, and `server.js` | Passed. |
| SQL migration | Cart migration and official pricing/transaction migration applied to a fresh database | Passed. |
| Transaction Scenario 1 | Available quantity-tier product plus unavailable product; call `place_orders` | Passed: one available line was ordered, removed from cart, and the unavailable line remained. |
| Transaction Scenario 2 | All remaining items unavailable; call `place_orders` | Passed: no additional sale order was created and the item remained in the cart. |
| Customer cart CRUD | Add, retrieve, update quantity, and delete an individual cart item through the running API | Passed. |
| Product quantity pricing | Buy 3 targeted products | Passed: 10% product rule and `$5.00` automatic delivery tier calculated. |
| Optional `PERCENT` voucher | Select `WELCOME10` after Buy 3 automatic rule | Passed: `$5.40` voucher item saving, `$5.00` tier fee unchanged, final total `$53.60`; voucher code and saving persisted in `order_pricing`. |
| Stacked pricing + `FIXED` voucher | Buy 5 targeted products plus a `$30` item, then select `SAVE5` | Passed: 15% product tier + 5% cart-value discount + `$5.00` voucher saving + free-delivery tier; final total `$104.25`. |
| Optional `FREE_DELIVERY` voucher | Select `FREEDELIVERY` for the `$5.00` automatic delivery tier | Passed: automatic delivery tier remained `$5.00`, voucher delivery saving was `$5.00`, final delivery fee was `$0.00`, and the saving persisted. |
| Checkout API | Available/unavailable partial order and all-unavailable no-order response, with voucher pricing snapshot | Passed. |
| Access control | Customer attempted to read admin pricing rules | Passed: HTTP `403`. |
| Administrator rules | Admin listed rules, created a delivery tier, and deactivated it | Passed. |
| Manufacturer indexes | Six before/after `EXPLAIN ANALYSE` comparisons | Passed; all six selected post-index plans used an index and execution time decreased. |

## Commands used in the final validation

```bash
npm test
npx prisma validate
npx prisma generate
node --check <each revised JavaScript file>
psql -f tests/sql_integration_base.sql
psql -f database/ca2_cart_checkout_indexes.sql
psql -f database/ca2_official_pricing_and_transactions.sql
psql -f tests/official_ca2_transaction_checks.sql
BASE_URL=http://127.0.0.1:3103 node tests/http_official_ca2_integration.js
psql -f database/manufacturer_benchmark.sql   # before indexes
psql -f database/manufacturer_indexing.sql
psql -f database/manufacturer_benchmark.sql   # after indexes
```

## What to reproduce in the student environment

Run the two restaurant SQL files in the stated order, replace `prisma/schema.prisma` with the final version, run `npx prisma generate`, and use the numbered setup guide. Then run the customer and administrator demonstrations in `INTERVIEW_DEMONSTRATION_RUNBOOK.md`. The report must contain the student’s own screenshots from their restored databases and local application session.
