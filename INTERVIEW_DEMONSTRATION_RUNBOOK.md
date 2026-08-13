# CA2 Interview Demonstration Runbook

Use this as a simple, accurate script. The official CA2 solution uses **automatic, data-driven pricing rules** and the required **`place_orders`** procedure. This project also provides one optional customer voucher selection per active cart; it supplements, rather than replaces, the automatic CA2 pricing logic.

## 1. Before the interview

1. Restore `restaurant_db` and run, in order:

```text
database/ca2_cart_checkout_indexes.sql
database/ca2_official_pricing_and_transactions.sql
database/functions_&_stored_procedures.sql
```

2. In the project terminal run:

```bash
npm install
npx prisma validate
npx prisma generate
npm start
```

3. Log in as a customer using the credentials displayed on the local login page.
4. In pgAdmin, identify the Buy 3/Buy 5 target product and an unavailable item:

```sql
SELECT pr.name AS rule_name, pr.minimum_quantity, pr.discount_percent,
       p.product_id, p.name, p.price
FROM public.pricing_rule pr
LEFT JOIN public.product p ON p.product_id = pr.product_id
WHERE pr.rule_type = 'PRODUCT_QUANTITY_PERCENT'
ORDER BY pr.minimum_quantity;

SELECT product_id, name, price
FROM public.product
WHERE is_available = FALSE;
```

If no product is unavailable, mark a disposable test product unavailable before the interview:

```sql
UPDATE public.product
SET is_available = FALSE
WHERE product_id = YOUR_TEST_PRODUCT_ID;
```

## 2. Opening explanation — say this

> “The customer cart is built with Prisma ORM. The Cart model uses `findFirst`, `create`, `upsert`, `update`, and `delete` for required cart CRUD. The server calculates the cart summary and all automatic rules; the browser only displays the returned result. Product and cart discounts stack, the automatic delivery tier is selected, and an optional selected voucher is applied afterward. The rules are data-driven, so an administrator can change the automatic policy rows without rewriting checkout code.”

## 3. Demonstrate Cart CRUD

1. Open **Add Items**.
2. Add an available product.
3. Open **Cart**.
4. Increase its quantity using `+`, then decrease it using `−`.
5. Add a second available product.
6. Use **Delete** on one line, then add it back if needed.

> Say: “Every create, retrieve, update, and delete action goes through protected customer routes and is validated again on the server. The cart summary is calculated on the back end.”

## 4. Demonstrate an unavailable item, partial processing, and `WELCOME10`

1. Add **one unavailable product** to the cart.
2. Add **3 units of the product named by the Buy 3 pricing rule**.
3. Open Cart and select `WELCOME10` from **Optional Voucher**.
4. Show all of the following:
   - available item(s) marked **Available**;
   - unavailable item marked **Unavailable — will remain after checkout**;
   - 10% automatic Buy 3 discount;
   - `WELCOME10` voucher item saving;
   - **Delivery / Service Pricing**: standard fee, automatic delivery-tier saving, and final delivery fee.
5. Open Checkout and show the selected voucher and the same price breakdown.
6. Click **Place Order**.
7. Show the confirmation: an order was created for available lines and the unavailable item remains in the cart.

> Say: “This implements the required first scenario. `place_orders` loops through every cart item. An available item creates an order item and is deleted from cart. An unavailable item is skipped and remains in the cart. Earlier available items are not rolled back. The procedure contains no discount or delivery calculation.”

## 5. Demonstrate all-unavailable behaviour

1. Clear the voucher in Cart if it is still selected.
2. The remaining cart should contain only the unavailable item.
3. Go to Checkout and click **Place Order**.
4. Show the message that **no order was created** and the item is still in the cart.

> Say: “This is the required second scenario. No new sale order or sale-order item is created when every cart item is unavailable.”

## 6. Demonstrate stacked automatic discounts and `SAVE5`

1. Keep the unavailable item for a partial-processing example if desired.
2. Add **5 units** of the target product. This selects the higher Buy 5 tier instead of the Buy 3 tier.
3. Add enough other available products so the **orderable items subtotal** is at least `$100`.
4. Select `SAVE5` from the Cart voucher dropdown.
5. Open Checkout and show the following components:

| Component | What should appear |
| --- | --- |
| Buy 5 product rule | Higher automatic percentage product discount. |
| Spend `$100` rule | Automatic cart-value discount calculated after product discount. |
| `SAVE5` | Optional `$5.00` item voucher saving. |
| Free delivery tier | Automatic delivery/service fee is `$0.00`. |

6. Place the order and show that available lines are processed while the unavailable line remains, if included.

> Say: “The automatic product quantity discount and cart-value discount stack. The automatic delivery tier is then selected. `SAVE5` is a separate optional customer saving, so its amount is shown separately in the Cart, Checkout, and order-pricing snapshot.”

## 7. Demonstrate `FREEDELIVERY`

1. Add **3 units** of the Buy 3 target product. After the automatic 10% discount, this should normally use the `$5.00` delivery tier.
2. Select `FREEDELIVERY` in Cart.
3. Show all delivery lines:
   - standard delivery price;
   - automatic delivery-tier saving;
   - voucher delivery saving;
   - final delivery/service fee `$0.00`.
4. Place the order and show the confirmation’s `FREEDELIVERY` saving.

> Say: “The free-delivery voucher runs after the automatic delivery-tier selection. It waives that tier fee; it cannot change which automatic delivery tier was selected.”

## 8. Demonstrate the administrator side

1. Log out and log in as **ADMIN**.
2. Open **Dashboard**.
3. Scroll to **Promotion and Delivery Rules**.
4. Show the product-quantity rules, cart-value rule, and delivery tiers.
5. Create a test rule, for example Buy 2 of a product at 8%.
6. Show it appearing in the table, then deactivate it.

> Say: “The manager can create, edit, activate, or deactivate automatic policy rows. This is extensible: an additional Buy 5 Product A at 15% tier is a new row, not a code change. Voucher selection is deliberately customer-facing and optional.”

## 9. Show database evidence in pgAdmin

Use these queries after the demonstration:

```sql
SELECT order_id, member_id, order_date, total_amount, status
FROM public.sale_order
ORDER BY order_id DESC
LIMIT 10;

SELECT order_id, product_id, quantity, unit_price, subtotal
FROM public.sale_order_item
ORDER BY order_item_id DESC
LIMIT 20;

SELECT ci.cart_item_id, ci.cart_id, p.name, p.is_available, ci.quantity
FROM public.cart_item ci
JOIN public.product p ON p.product_id = ci.product_id
ORDER BY ci.cart_id, ci.cart_item_id;

SELECT order_id, items_subtotal, product_discount_amount, cart_discount_amount,
       voucher_code, voucher_discount_amount, delivery_fee,
       voucher_delivery_saving, final_total, pricing_snapshot
FROM public.order_pricing
ORDER BY created_at DESC
LIMIT 10;
```

> Say: “The order record remains in the original restaurant tables. The new `order_pricing` table keeps the calculated subtotal, automatic discounts, selected voucher, delivery amount, final total, and pricing snapshot without altering the original table definitions.”

## 10. If the lecturer asks about indexes

1. Switch to the separate **manufacturer** database.
2. Run `database/manufacturer_benchmark.sql` before indexes.
3. Run `database/manufacturer_indexing.sql`.
4. Run the benchmark again.
5. Point to `docs/MANUFACTURER_INDEX_RESULTS.md` for the six real before/after outcomes.

> Say: “I used `EXPLAIN ANALYSE` before and after each index. The six indexes include single-column/function indexes, composite indexes, and one covering index; the post-index plans use Bitmap Index Scans or an Index Only Scan.”
