CREATE TABLE public.member (
    member_id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL DEFAULT 'not-used-in-sql-test',
    first_name VARCHAR(100) NOT NULL DEFAULT 'Test',
    last_name VARCHAR(100) NOT NULL DEFAULT 'Member',
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.member_role (
    member_id INTEGER NOT NULL REFERENCES public.member(member_id),
    role VARCHAR(20) NOT NULL,
    PRIMARY KEY (member_id, role)
);

CREATE TABLE public.product (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL,
    category VARCHAR(100),
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.sale_order (
    order_id SERIAL PRIMARY KEY,
    member_id INTEGER NOT NULL REFERENCES public.member(member_id),
    order_date TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_amount NUMERIC(10, 2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PACKING'
);

CREATE TABLE public.sale_order_item (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES public.sale_order(order_id),
    product_id INTEGER NOT NULL REFERENCES public.product(product_id),
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    subtotal NUMERIC(10, 2) NOT NULL
);

INSERT INTO public.member (member_id, username, email, first_name, last_name)
VALUES
    (1, 'testmember', 'testmember@example.com', 'Test', 'Customer'),
    (2, 'testadmin', 'testadmin@example.com', 'Test', 'Administrator');

INSERT INTO public.member_role (member_id, role)
VALUES (1, 'USER'), (2, 'ADMIN');

INSERT INTO public.product (product_id, name, description, price, category, is_available)
VALUES
    (1, 'Chicken Rice', 'Available product targeted by quantity tiers.', 20.00, 'Main Course', TRUE),
    (2, 'Laksa', 'Available product for cart value and delivery tests.', 30.00, 'Main Course', TRUE),
    (3, 'Sold Out Cake', 'Unavailable product retained after order processing.', 8.00, 'Dessert', FALSE),
    (4, 'Iced Tea', 'Low-cost available product for under-$50 delivery tier.', 10.00, 'Beverage', TRUE);

SELECT setval(pg_get_serial_sequence('public.member', 'member_id'), 2, TRUE);
SELECT setval(pg_get_serial_sequence('public.product', 'product_id'), 4, TRUE);
