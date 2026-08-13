-- ST0525 DBS CA2: Interview demonstration helper.
-- Run AFTER ca2_cart_checkout_indexes.sql and ca2_discounts_interview_demo.sql.
-- It safely chooses one currently available product as the unavailable demonstration item.

-- Step 1: inspect all products and identify at least three products.
SELECT product_id, name, price, category, is_available
FROM public.product
ORDER BY product_id;

-- Step 2: mark one available product unavailable for the cart-validation demonstration.
-- The selected product is returned. Record its product_id so you can restore it after the interview.
WITH selected_product AS (
    SELECT product_id
    FROM public.product
    WHERE is_available = TRUE
    ORDER BY product_id DESC
    LIMIT 1
)
UPDATE public.product p
SET is_available = FALSE
FROM selected_product s
WHERE p.product_id = s.product_id
RETURNING p.product_id, p.name, p.price, p.is_available;

-- Step 3: choose any two rows that remain available for the normal cart and discount demonstrations.
SELECT product_id, name, price, category, is_available
FROM public.product
WHERE is_available = TRUE
ORDER BY product_id
LIMIT 2;

-- Step 4: after your interview, restore the demonstration product.
-- Replace 999 with the product_id returned in Step 2.
-- UPDATE public.product SET is_available = TRUE WHERE product_id = 999;
