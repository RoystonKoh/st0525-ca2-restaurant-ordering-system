# ST0525 CA2 — Complete Setup, Evidence, and Submission Guide

This guide is written for the completed project folder. Follow the steps in order. Do not skip the database setup steps: the application and report evidence depend on the restored PostgreSQL database.

## 1. Prepare your project copy and GitHub repository

1. Extract the supplied `CA2_READY_TO_SUBMIT.zip` file into a normal project folder on your computer.
2. Create a new GitHub repository named, for example, `st0525-ca2-restaurant-ordering-system`.
3. Open a terminal inside the extracted project folder and run the following commands.

```bash
git init
git add .
git commit -m "Complete CA2 cart, checkout, transaction and indexing implementation"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
git push -u origin main
```

4. Copy the repository URL. You will use it in the individual report. Do **not** upload your `.env` file because it contains local credentials.

## 2. Restore the main restaurant database

The supplied `restaurant_db_restore.sql` is a PostgreSQL custom-format backup despite the `.sql` filename. Restore it through **pgAdmin 4**, because the archive version may be newer than your locally installed command-line restore program.

1. Open pgAdmin 4 and connect to your PostgreSQL server.
2. Create a database named `restaurant_db` if your lecturer has not given you another required name.
3. Right-click `restaurant_db` → **Restore**.
4. Select `database/restaurant_db_restore.sql` (or the original supplied backup if it is outside the project folder).
5. Use the **Custom or tar** restore format if pgAdmin asks. Run the restore.
6. Open Query Tool and verify the baseline tables:

```sql
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

You should be able to see tables including `member`, `product`, `sale_order`, and `sale_order_item`.

## 3. Restore the separate manufacturer database

The setup guide requires a **separate** manufacturer database.

1. In pgAdmin, create a new database named `manufacturer`.
2. Right-click `manufacturer` → **Restore**.
3. Select the originally supplied `manufacturer_restore.sql` backup.
4. After restoration, run:

```sql
SELECT COUNT(*) AS manufacturer_rows FROM public.manufacturer;
SELECT * FROM public.manufacturer LIMIT 10;
```

5. Capture one screenshot showing that `manufacturer` is a separate database, contains one `manufacturer` table, and has the correct restored row count. Keep this screenshot for the corresponding CA2 deliverable if your lecturer asks for it.

> The application must continue to point at `restaurant_db`. Do not change the runtime `DB_NAME` to `manufacturer`.

## 4. Configure the environment

1. In the project root, copy `.env.example` to `.env`.
2. Replace the placeholder password and secret with your local values.
3. Ensure that both the Node.js configuration and Prisma target the **same restaurant database**.

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=restaurant_db
DB_USER=postgres
DB_PASSWORD=YOUR_POSTGRES_PASSWORD
DATABASE_URL=postgresql://postgres:YOUR_POSTGRES_PASSWORD@localhost:5432/restaurant_db?schema=public
SESSION_SECRET=use_a_long_random_value_here
PORT=3000
NODE_ENV=development
```

If your password contains special characters, URL-encode it in `DATABASE_URL`. The `DB_PASSWORD` line should retain the normal password.

## 5. Install dependencies and integrate Prisma

Run the commands below from the project root.

```bash
npm install
npx prisma validate
npx prisma db pull
npx prisma generate
```

The supplied `prisma/schema.prisma` already maps the existing restaurant entities and the new `Cart`/`CartItem` models. Run `npx prisma db pull` after the main database is restored, then inspect the schema carefully. If Prisma modifies a type based on your restored database, keep the change only if it reflects the database correctly.

## 6. Apply the CA2 database migration

1. In pgAdmin Query Tool, connected to `restaurant_db`, open and run:

```text
database/ca2_cart_checkout_indexes.sql
```

2. Verify the new tables and stored procedure:

```sql
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('cart', 'cart_item');

SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'place_order_from_cart';

SELECT indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%'
ORDER BY indexname;
```

3. Record a screenshot of the successful SQL execution and the result grid. This is useful evidence for database design, transaction management, and indexing.

## 7. Start and test the application

Start the project:

```bash
npm start
```

Open `http://localhost:3000/login` in your browser. Use the seeded account details shown on the project login page, or register a new member account.

Perform this exact demonstration flow:

1. Log in as a `USER`.
2. Open **Products**.
3. Add two different available products to the cart, with one item quantity above 1.
4. Open **Cart**. Increase one quantity, decrease another quantity, and remove an item if you need a removal screenshot.
5. Return to Products and add the removed item again so the cart has at least two items.
6. Open **Checkout**. Confirm the summary contains all products, quantities, and totals.
7. Select **Confirm and Place Order**.
8. Capture the success confirmation showing the order number and total.
9. Log in as an `ADMIN` and open the dashboard. Confirm the new order appears and change its status if the existing application requires this for feedback testing.

## 8. Capture evidence screenshots for the individual report

Use your own screenshots. Insert them into `docs/CA2_Individual_Report.docx` at the marked places.

| Criterion | Minimum screenshots to insert |
| --- | --- |
| Database design / ORM | Lucidchart-exported ERD and successful migration/result-grid screenshot. |
| Cart management | Successful add-to-cart/cart count, populated Cart page, one invalid/unavailable case. |
| Checkout | Checkout review page, successful order confirmation, one disabled/error business-rule case. |
| Transaction management | Success, empty-cart error, unavailable-product error, verification query showing no partial order. |
| Indexing | Six `EXPLAIN (ANALYZE, BUFFERS)` outputs—one for each proposed query. |

The report template specifically says the ERD must be diagrammed in Lucidchart. Use `docs/erd_ca2.png` and `docs/erd_ca2.mmd` as the accurate source, reproduce the same structure in Lucidchart, export it as PNG, and replace the ERD image in the Word report with the Lucidchart-exported image.

## 9. Test transaction management

1. Open `database/checkout_test_cases.sql` in pgAdmin Query Tool.
2. Replace the member and product IDs at the top of each test block with values found in your restored database.
3. Run the success case. Capture the notice and verification queries.
4. Run the empty-cart failure case. Capture the expected error notice and the before/after order-count notice.
5. Run the unavailable-product case. Capture the expected error notice.
6. Explain in your report that the procedure locks the active cart and product rows before validating and inserting the order. This prevents a partially completed order if a validation rule fails.

## 10. Test the six indexes with real plans

1. Ensure the application has enough realistic data. Place a few additional test orders if necessary.
2. Open `database/index_benchmark.sql` in pgAdmin.
3. Replace the sample member IDs, product IDs, and category string with values that exist in your database.
4. Run the index list query and capture the result.
5. Run each of Q1–Q6. Capture the `EXPLAIN (ANALYZE, BUFFERS)` plan.
6. In the report, state what PostgreSQL actually selected: for example, `Index Scan`, `Bitmap Index Scan`, or `Seq Scan`; state the actual execution time and explain the outcome.

> Do not force an index scan or invent a performance improvement. On a small restored dataset, PostgreSQL may correctly choose a sequential scan because scanning a small table can cost less than index access. Your explanation of the real plan is more credible than a false performance claim.

## 11. Finalise the individual report

1. Open `docs/CA2_Individual_Report.docx`.
2. Replace all `[[...]]` fields with your name, student ID, class, GitHub URL, evidence-link base, confirmed self-ratings, and checklist values.
3. Replace each placeholder GitHub link using your repository URL. For example:

```text
https://github.com/YOUR_USERNAME/YOUR_REPOSITORY/blob/main/prisma/schema.prisma
```

4. Insert the required screenshots at the marked places.
5. Replace the generated ERD with your Lucidchart export.
6. Click every hyperlink in the Word report. Broken links can result in a major mark deduction according to the supplied template.
7. Save the completed document using your required naming convention, for example: `P1234567_CA2_Individual_Report.docx`.

## 12. Final submission checklist

| Item | What to submit |
| --- | --- |
| Application source | Your GitHub repository URL and/or source ZIP as instructed. |
| Main SQL work | `database/ca2_cart_checkout_indexes.sql`, `database/checkout_test_cases.sql`, and `database/index_benchmark.sql`. |
| Prisma work | `prisma/schema.prisma`, `prisma.config.ts`, and `config/prisma.js`. |
| Individual report | Finalised Word report with screenshots, Lucidchart ERD, working GitHub links, and personal details. |
| Manufacturer evidence | Screenshot verifying the separate `manufacturer` database/table/row count, if required by the deliverable. |

## 13. Commands to run before final upload

```bash
npm test
npx prisma validate
npx prisma generate
git status
git add .
git commit -m "Final CA2 submission"
git push
```

The project-level validation report is in `VALIDATION_EVIDENCE.md`. It records what was automatically validated and explicitly distinguishes this from the live PostgreSQL evidence that you must capture on your own restored database.
