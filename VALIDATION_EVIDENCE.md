# CA2 Validation Evidence

## Automated validation completed

The completed project was checked on **14 August 2026** using the following commands:

```bash
npm test
npx prisma validate
npx prisma generate
find config controllers models routes middleware public/js tests -type f -name '*.js' -print0 | xargs -0 -n1 node --check
node --check server.js
```

All six structural checks passed. The checks confirm that the CA2 migration creates `cart` and `cart_item`, contains the guarded `place_order_from_cart` procedure, defines the six selected indexes, maps the cart entities in Prisma, protects cart/checkout endpoints, supplies the two member pages, and loads the Prisma-backed runtime modules.

The Express HTTP smoke test also passed in test mode. `GET /login` returned HTTP `200`, while an unauthenticated request to `GET /member/cart` returned HTTP `302` and redirected to `/login`. This demonstrates that the cart page is access-controlled before a session is established.

## Live database evidence to capture

The sandbox did not contain a running PostgreSQL server or a PostgreSQL 17 restore utility compatible with the supplied custom-format backups. Therefore, no database performance numbers or UI screenshots are fabricated in this package. After restoring the supplied database locally, capture the evidence below using the exact scripts included in the project.

| Criterion | File to run/use | Capture required |
| --- | --- | --- |
| Cart management | Application pages: Products and Cart | One successful add/update/remove sequence and one validation/error state. |
| Checkout | Application page: Checkout | The review screen plus the success confirmation containing order number and total. |
| Transaction management | `database/checkout_test_cases.sql` | Success case, empty-cart rejection, unavailable-product rejection, and verification queries proving no partial order was inserted. |
| Indexing | `database/index_benchmark.sql` | The six `EXPLAIN (ANALYZE, BUFFERS)` plans, one per proposed query. Show the relevant index name and real execution statistics. |
| ERD/ORM model | `docs/erd_ca2.mmd` and `docs/erd_ca2.png` | Export the ERD from Lucidchart after reproducing it there, as required by the template. |

> Do not report made-up milliseconds. Use the actual execution-time and plan output shown by PostgreSQL on the restored assignment database.
