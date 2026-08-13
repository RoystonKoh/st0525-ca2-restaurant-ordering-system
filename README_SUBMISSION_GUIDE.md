# ST0525 CA2 — Simple Setup, Test, Interview, and Submission Guide

Follow this guide **in order**. Do not skip database steps. This final project uses **two separate databases**: `restaurant_db` for the Node/Prisma application and `manufacturer` only for Deliverable #005 indexing.

> **Important:** Do **not** run `npx prisma db pull`. The supplied final `prisma/schema.prisma` is already mapped to the required database tables. Running `db pull` can overwrite the Cart, PricingRule, and OrderPricing model mappings.

## Part A — Put the project on your computer

1. Download and extract the final ZIP into a normal folder, such as `Documents\ST0525_CA2`.
2. Open the extracted folder in VS Code.
3. Confirm that the folder contains `package.json`, `prisma`, `database`, `views`, `controllers`, `docs`, and this guide.
4. Create your GitHub repository now, but do not upload `.env`.

```bash
git init
git add .
git commit -m "ST0525 CA2 final implementation"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
git push -u origin main
```

## Part B — Restore the restaurant database

1. Open **pgAdmin 4** and connect to your PostgreSQL server.
2. Create a database named `restaurant_db` unless your lecturer gave you a different required name.
3. Right-click the new database → **Restore**.
4. Select `restaurant_db_restore.sql` from the submitted project folder/original supplied files.
5. Choose **Custom or tar** format if pgAdmin asks, then restore.
6. Right-click `restaurant_db` → **Query Tool** and run this check.

```sql
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

You should see at least `member`, `member_role`, `product`, `sale_order`, and `sale_order_item`.

## Part C — Add the CA2 database entities and procedure

Stay connected to **restaurant_db** in Query Tool. Run the files in this exact order.

1. Open and run:

```text
database/ca2_cart_checkout_indexes.sql
```

This creates only the new `cart` and `cart_item` tables and their constraints.

2. Open and run:

```text
database/ca2_official_pricing_and_transactions.sql
```

This creates only the new `pricing_rule`, `voucher`, `cart_voucher`, and `order_pricing` tables, seeds automatic rules plus three optional customer vouchers, and creates the required `place_orders` procedure.

3. Open and run:

```text
database/functions_&_stored_procedures.sql
```

This keeps the stored-procedure export in sync with the project. If you already ran this earlier for CA1, it is safe to run again.

4. Run this verification query. Take a screenshot of the successful output.

```sql
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('cart', 'cart_item', 'pricing_rule', 'voucher', 'cart_voucher', 'order_pricing')
ORDER BY tablename;

SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'place_orders';

SELECT name, rule_scope, rule_type, minimum_quantity,
       minimum_cart_value, maximum_cart_value,
       discount_percent, delivery_fee, is_active
FROM public.pricing_rule
ORDER BY pricing_rule_id;
```

> The `NOTICE ... does not exist, skipping` messages for an old prototype procedure are **not errors**. The important result is that `place_orders` exists and the new tables/rules appear.

## Part D — Restore the separate manufacturer database

1. In pgAdmin, create another database called `manufacturer`.
2. Restore the provided `manufacturer_restore.sql` into **manufacturer**, not `restaurant_db`.
3. In the `manufacturer` Query Tool, run:

```sql
SELECT COUNT(*) AS manufacturer_rows FROM public.manufacturer;
SELECT * FROM public.manufacturer LIMIT 10;
```

4. Take one screenshot proving that `manufacturer` is a separate database and contains the `manufacturer` table.

## Part E — Configure and start the application

1. In the project root, copy `.env.example` and rename the copy to `.env`.
2. Replace the password and secret using your own local PostgreSQL details.

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=restaurant_db
DB_USER=postgres
DB_PASSWORD=YOUR_POSTGRES_PASSWORD
DATABASE_URL=postgresql://postgres:YOUR_POSTGRES_PASSWORD@localhost:5432/restaurant_db?schema=public
SESSION_SECRET=put_a_long_random_string_here
PORT=3000
NODE_ENV=development
```

3. Open the VS Code terminal in the project root and run:

```bash
npm install
npx prisma validate
npx prisma generate
npm start
```

4. Open `http://localhost:3000/login`.
5. Use the sample customer/admin login details displayed on the login page. If your database has different seeded credentials, use those instead.

## Part F — Customer demonstration: cart CRUD

Use a **customer** account.

1. Go to **Add Items** or open `http://localhost:3000/cart/create`.
2. Add an available product.
3. Open the cart at `http://localhost:3000/cart/retrieve/all`.
4. Use `+` to increase its quantity, then `−` to decrease it.
5. Add a different item and then use **Delete** on one item.
6. Add items again so your cart contains the products needed for the next tests.

Take screenshots of:

| Screenshot | What the marker should see |
| --- | --- |
| Cart add | A successful add message and cart badge/count. |
| Retrieve all | At least two cart items, subtotals, quantity controls, and server-calculated summary. |
| Update/delete | A changed quantity or deleted line. |

## Part G — Find the required product and unavailable item

In `restaurant_db` Query Tool, run:

```sql
SELECT product_id, name, price, is_available
FROM public.product
ORDER BY is_available DESC, product_id;

SELECT pr.name AS rule_name, pr.minimum_quantity, pr.discount_percent,
       p.product_id, p.name AS target_product
FROM public.pricing_rule pr
LEFT JOIN public.product p ON p.product_id = pr.product_id
WHERE pr.rule_type = 'PRODUCT_QUANTITY_PERCENT'
ORDER BY pr.minimum_quantity;
```

The first available product chosen during setup is the target product for the seeded **Buy 3 at 10%** and **Buy 5 at 15%** rules. Find one product where `is_available` is `false`; this is your unavailable demonstration item.

If your restored data does not contain an unavailable product, use a test product you are allowed to mark unavailable:

```sql
UPDATE public.product
SET is_available = FALSE
WHERE product_id = YOUR_TEST_PRODUCT_ID;
```

This changes test data only; it does **not** alter the original table structure.

## Part H — Customer demonstration: automatic discounts, vouchers, and delivery

The required CA2 product-quantity, cart-value, and delivery-tier rules apply automatically. The Cart page also has an optional customer voucher dropdown. A shopper may select **one** reusable active voucher; this is additional to the automatic rules, not a replacement for them. The Cart and Checkout summaries show every component separately.

> **Pricing order to explain in the interview:** product quantity discount → cart-value discount → delivery-tier selection → optional `PERCENT`, `FIXED`, or `FREE_DELIVERY` voucher. A voucher does not alter the automatic delivery tier.

### Test 1: Product quantity discount, delivery tier, and `WELCOME10`

1. Add **3 units** of the target available product and add one unavailable product.
2. Open Cart. In **Optional Voucher**, select `WELCOME10`.
3. Show the 10% automatic product rule, the `WELCOME10` item saving, and the **Delivery / Service Pricing** lines: standard delivery price, automatic tier saving, and final delivery fee.
4. Open Checkout and confirm the selected voucher and the same breakdown are visible.
5. Press **Place Order**. The successful order contains only available items; the unavailable item remains in Cart.

### Test 2: All items unavailable

1. In Cart, remove any selected voucher if needed. After Test 1, the unavailable item should remain.
2. Go to Checkout and press **Place Order**.
3. Show the message that no order is created and the unavailable item remains.

### Test 3: Stacked automatic discounts and `SAVE5`

1. Keep the unavailable item in the cart if you want to demonstrate partial processing again.
2. Add **5 units** of the target available product and enough available items until the **orderable subtotal** is at least `$100`.
3. In Cart, select `SAVE5` from the voucher dropdown.
4. Open Checkout. Show the Buy 5 product discount, Spend `$100` cart-value discount, `SAVE5` item saving, free-delivery tier (`$0.00`), and final total.
5. Press **Place Order** and show that available lines are processed while the unavailable line remains.

### Test 4: `FREEDELIVERY`

1. Add **3 units** of the target available product, which normally reaches the `$5.00` delivery tier after the 10% automatic product discount.
2. Select `FREEDELIVERY` in Cart.
3. Show the **standard delivery price**, **automatic delivery-tier saving**, **voucher delivery saving**, and **final delivery/service fee `$0.00`**.
4. Open Checkout and place the order. The confirmation records the free-delivery voucher saving separately from automatic discounts.

Take screenshots of the Cart dropdown and delivery breakdown, the Checkout summary, and the post-order confirmation for your report evidence.
## Part I — Administrator demonstration

1. Log out and log in as an **ADMIN**.
2. Open `http://localhost:3000/dashboard`.
3. Scroll to **Promotion and Delivery Rules**.
4. Show the existing Buy 3/Buy 5 product rules, cart-value rule, and delivery-tier rules.
5. Create a new rule. A good interview example is:

| Field | Value |
| --- | --- |
| Rule Name | `Buy 2 Test Product at 8 percent` |
| Rule Type | Product quantity percentage |
| Product | Any available test product |
| Minimum Quantity | `2` |
| Discount Percent | `8` |
| Priority | `5` |

6. Show the new rule in the table, then deactivate it. Explain that this is data-driven and a manager can add, edit, activate, or deactivate policy rows without changing checkout code.

## Part J — Run the two transaction scenarios in pgAdmin

1. Open `tests/official_ca2_transaction_checks.sql`.
2. This script is designed for the project’s controlled test data. For your own restored database, use the application screenshots as your main evidence, or adjust the product/member IDs carefully.
3. The expected behaviour is:

| Scenario | Expected result |
| --- | --- |
| Available + unavailable | A sale order and line exist for the available item; its cart item is deleted; unavailable item remains. |
| All unavailable | No new sale order/line exists; all unavailable items remain in cart. |

4. Use Query Tool to verify the latest data:

```sql
SELECT * FROM public.sale_order ORDER BY order_id DESC LIMIT 10;
SELECT * FROM public.sale_order_item ORDER BY order_item_id DESC LIMIT 20;
SELECT ci.*, p.name, p.is_available
FROM public.cart_item ci
JOIN public.product p ON p.product_id = ci.product_id
ORDER BY ci.cart_id, ci.cart_item_id;
```

## Part K — Manufacturer Deliverable #005: six real index tests

In the separate **manufacturer** database:

1. Open `database/manufacturer_benchmark.sql` and run it **before** adding indexes. Save or screenshot all six `EXPLAIN ANALYSE` outputs.
2. Open and run `database/manufacturer_indexing.sql`.
3. Run `database/manufacturer_benchmark.sql` again.
4. For every query, capture the before/after plan or write down the actual plan node and execution time.
5. Use `docs/MANUFACTURER_INDEX_RESULTS.md` as your explanation model. The completed project’s evidence used the supplied backup, but your local plan/time can vary.

## Part L — Finish the individual report

1. Open `docs/CA2_Individual_Report.docx`.
2. Replace every `[[...]]` field with your own name, student ID, class, GitHub URL, and completion checks.
3. Replace `[[GITHUB_BASE]]` in links with your GitHub blob URL.
4. Insert your own screenshots from Parts C, F, H, I, J, and K.
5. If your template requires Lucidchart specifically, reproduce `docs/erd_ca2.mmd` / `docs/erd_ca2.png` in Lucidchart, export it, and insert that export.
6. Save as your lecturer’s requested naming format, for example `P1234567_CA2_Individual_Report.docx`.

## Part M — Final commands and upload checklist

Before uploading:

```bash
npm test
npx prisma validate
npx prisma generate
git status
git add .
git commit -m "Final CA2 submission"
git push
```

| Submit / verify | What you should provide |
| --- | --- |
| Deliverables #002–#004 | The final source ZIP/GitHub repository as your learning site specifies, plus your individual report if requested in that slot. |
| Deliverable #005 | Manufacturer index SQL, benchmark SQL, six before/after plan screenshots, and the report indexing section. |
| Individual report | Final Word report with your own details, screenshots, Lucidchart ERD if required, and working GitHub links. |
| Do **not** submit | `.env`, `node_modules`, PostgreSQL password, or unrelated lecture files. |
