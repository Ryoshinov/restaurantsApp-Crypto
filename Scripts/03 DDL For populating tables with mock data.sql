-- Cleanup helper functions
CREATE OR REPLACE FUNCTION mock_id(
    p_prefix VARCHAR,
    p_size INTEGER
)
RETURNS VARCHAR
AS $$
BEGIN
    RETURN p_prefix || '_' || substring(md5(random()::text), 1, p_size);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mock_text(
    p_min INTEGER,
    p_max INTEGER
)
RETURNS TEXT
AS $$
DECLARE
    v_text TEXT := '';
    v_length INTEGER;
BEGIN
    v_length := p_min + floor(random() * (p_max - p_min + 1))::INTEGER;

    WHILE length(v_text) < v_length LOOP
        v_text := v_text || ' ' || substring(md5(random()::text), 1, 1 + floor(random() * 9)::INTEGER);
    END LOOP;

    RETURN trim(left(v_text, v_length));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calculate_order_total(
    p_order_id BIGINT
)
RETURNS NUMERIC(12,2)
AS $$
DECLARE
    v_total NUMERIC(12,2);
BEGIN
    SELECT COALESCE(SUM(quantity * unit_price), 0)
    INTO v_total
    FROM order_item
    WHERE order_id = p_order_id;

    RETURN ROUND(v_total, 2);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calculate_check_paid(
    p_check_id BIGINT
)
RETURNS NUMERIC(12,2)
AS $$
DECLARE
    v_paid NUMERIC(12,2);
BEGIN
    SELECT COALESCE(SUM(amount), 0)
    INTO v_paid
    FROM payment
    WHERE check_id = p_check_id
      AND status = 'COMPLETED';

    RETURN ROUND(v_paid, 2);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION is_check_reconciled(
    p_check_id BIGINT
)
RETURNS BOOLEAN
AS $$
DECLARE
    v_total NUMERIC(12,2);
    v_paid  NUMERIC(12,2);
BEGIN
    SELECT total_amount INTO v_total
    FROM restaurant_check
    WHERE id = p_check_id;

    v_paid := calculate_check_paid(p_check_id);

    RETURN v_paid = v_total;
END;
$$ LANGUAGE plpgsql;

-- 1. Insert Restaurants
INSERT INTO restaurant (name, legal_name, address, phone, email)
VALUES
    ('Crypto Tacos LTD', 'LTD Crypto tacos', '12 Sofia Blvd, Sofia', '+359 2 400 1001', 'contact@urbanfork.example'),
    ('Balkan Table', 'Balkan Table Ltd.', '25 Cherni Vrah Blvd, Sofia', '+359 2 400 1002', 'contact@balkantable.example'),
    ('Green Garden', 'Green Garden Dining Ltd.', '8 Oborishte St, Sofia', '+359 2 400 1003', 'contact@greengarden.example'),
    ('Central Bistro', 'Central Bistro Ltd.', '41 Tsar Osvoboditel Blvd, Sofia', '+359 2 400 1004', 'contact@centralbistro.example'),
    ('The Corner Kitchen', 'Corner Kitchen Ltd.', '17 Dondukov Blvd, Sofia', '+359 2 400 1005', 'contact@cornerkitchen.example');

-- 2. Insert Floors
INSERT INTO floor (restaurant_id, name, width, height)
SELECT r.id, f.name, f.width, f.height
FROM restaurant r
CROSS JOIN (
    VALUES
        ('Ground Floor', 25.00, 20.00),
        ('First Floor', 30.00, 20.00),
        ('Terrace', 35.00, 15.00)
) AS f(name, width, height);

-- 3. Insert Restaurant Tables
INSERT INTO restaurant_table (
    restaurant_id, floor_id, table_number, capacity,
    shape, position_x, position_y, width, height, rotation, status
)
SELECT
    f.restaurant_id,
    f.id,
    ROW_NUMBER() OVER (PARTITION BY f.restaurant_id ORDER BY f.id, gs)::INTEGER,
    CASE
        WHEN gs % 5 = 0 THEN 8
        WHEN gs % 4 = 0 THEN 6
        WHEN gs % 2 = 0 THEN 4
        ELSE 2
    END,
    CASE
        WHEN gs % 3 = 0 THEN 'ROUND'
        WHEN gs % 3 = 1 THEN 'RECTANGLE'
        ELSE 'SQUARE'
    END,
    2 + ((gs - 1) % 4) * 6,
    2 + floor((gs - 1) / 4) * 6,
    CASE WHEN gs % 3 = 0 THEN 3.0 ELSE 4.0 END,
    CASE WHEN gs % 3 = 0 THEN 3.0 ELSE 2.5 END,
    0,
    'AVAILABLE'
FROM floor f
CROSS JOIN generate_series(1, 12) AS gs;

-- 4. Insert Table Seats
INSERT INTO table_seat (table_id, seat_number, position_x, position_y, rotation)
SELECT
    rt.id,
    s.seat_number,
    CASE WHEN s.seat_number <= rt.capacity / 2 THEN 0 ELSE rt.width END,
    (s.seat_number - 1) * 1.5,
    CASE WHEN s.seat_number <= rt.capacity / 2 THEN 270 ELSE 90 END
FROM restaurant_table rt
CROSS JOIN LATERAL generate_series(1, rt.capacity) AS s(seat_number);

-- 5. Insert Roles
INSERT INTO role (restaurant_id, name)
SELECT r.id, roles.name
FROM restaurant r
CROSS JOIN (
    VALUES ('Manager'), ('Waiter'), ('Chef'), ('Bartender'), ('Cashier')
) AS roles(name);

-- 6. Insert Employees
INSERT INTO employee (restaurant_id, role_id, first_name, last_name, email, phone, active)
SELECT
    r.id AS restaurant_id,
    ro.id AS role_id,
    names.first_name,
    names.last_name,
    LOWER(
        names.first_name || '.' || names.last_name || gs || '@' ||
        REGEXP_REPLACE(LOWER(r.name), '[^a-z0-9]', '', 'g') || '.com'
    ) AS email,
    '+359 88 ' || LPAD((1000000 + FLOOR(RANDOM() * 8999999))::BIGINT::TEXT, 7, '0') AS phone,
    (RANDOM() > 0.10) AS active
FROM restaurant r
CROSS JOIN generate_series(1, 5) gs
CROSS JOIN LATERAL (
    SELECT id FROM role WHERE restaurant_id = r.id ORDER BY random() LIMIT 1
) ro
CROSS JOIN LATERAL (
    SELECT
        (ARRAY['Ivan','Maria','Georgi','Elena','Nikolay','Petar','Anna','Alexander','Victoria','Daniel'])[1 + (ABS(HASHTEXT(r.id::TEXT || gs::TEXT || 'fn')) % 10)] AS first_name,
        (ARRAY['Petrov','Ivanova','Dimitrov','Georgieva','Nikolov','Petrova','Kolev','Stoyanova','Todorov','Marinova'])[1 + (ABS(HASHTEXT(r.id::TEXT || gs::TEXT || 'ln')) % 10)] AS last_name
) names;

-- 7. Insert Menu Categories
INSERT INTO menu_category (restaurant_id, name, description, display_order, active)
SELECT r.id, c.name, c.description, c.display_order, TRUE
FROM restaurant r
CROSS JOIN (
    VALUES
        ('Starters', 'Small dishes and appetizers', 1),
        ('Salads', 'Fresh salads and vegetables', 2),
        ('Main Courses', 'Main dishes', 3),
        ('Pizza', 'Freshly prepared pizzas', 4),
        ('Desserts', 'Desserts and sweet dishes', 5),
        ('Drinks', 'Hot and cold beverages', 6)
) c(name, description, display_order);

-- 8. Insert Menu Items with Discount Logic
INSERT INTO menu_item (
    restaurant_id, category_id, name, description, price, discounted_price, discount_active, active
)
SELECT
    mc.restaurant_id,
    mc.id,
    item.name,
    item.description,
    item.price,
    disc.discounted_price,
    disc.discount_active,
    random() > 0.05
FROM menu_category mc
JOIN (
    VALUES
        ('Starters','Garlic Bread','Bread with garlic butter',6.50),
        ('Starters','Bruschetta','Tomatoes, basil and olive oil',8.90),
        ('Starters','Chicken Wings','Grilled chicken wings',12.50),
        ('Starters','Mozzarella Sticks','Fried mozzarella with dip',10.50),
        ('Salads','Greek Salad','Tomatoes, cucumber, olives and feta',11.90),
        ('Salads','Caesar Salad','Chicken, lettuce, parmesan and dressing',13.90),
        ('Salads','Garden Salad','Seasonal vegetables',9.50),
        ('Salads','Avocado Salad','Avocado and mixed greens',14.50),
        ('Main Courses','Grilled Chicken','Grilled chicken with vegetables',18.90),
        ('Main Courses','Grilled Salmon','Salmon with seasonal vegetables',24.90),
        ('Main Courses','Beef Steak','Beef steak with potatoes',29.90),
        ('Main Courses','Pasta Carbonara','Pasta with bacon and parmesan',16.90),
        ('Pizza','Margherita','Tomato, mozzarella and basil',12.90),
        ('Pizza','Pepperoni','Pepperoni and mozzarella',15.90),
        ('Pizza','Four Cheese','Four cheese combination',16.90),
        ('Pizza','Vegetarian','Seasonal vegetables and mozzarella',14.90),
        ('Desserts','Tiramisu','Classic Italian dessert',8.90),
        ('Desserts','Chocolate Fondant','Warm chocolate dessert',9.90),
        ('Desserts','Cheesecake','Classic cheesecake',8.50),
        ('Desserts','Ice Cream','Three scoops of ice cream',7.50),
        ('Drinks','Mineral Water','Bottled mineral water',2.50),
        ('Drinks','Cola','Soft drink',3.50),
        ('Drinks','Fresh Orange Juice','Freshly squeezed orange juice',6.90),
        ('Drinks','Coffee','Espresso coffee',3.20)
) item(category_name, name, description, price)
    ON item.category_name = mc.name
CROSS JOIN LATERAL (
    SELECT 
        calc.d_price AS discounted_price,
        (calc.d_price IS NOT NULL) AS discount_active
    FROM (
        SELECT CASE 
            WHEN random() < 0.20 THEN ROUND((item.price * (0.80 + random() * 0.10))::numeric, 2)
            ELSE NULL 
        END AS d_price
    ) calc
) disc;

-- 9. Populate Reservations
INSERT INTO reservation (
    restaurant_id, customer_name, customer_phone, customer_email, party_size,
    start_time, end_time, status, confirmed_at, arrived_at, seated_at,
    completed_at, cancelled_at, notes, created_at
)
SELECT
    r.id AS restaurant_id,
    names.first_name || ' ' || names.last_name AS customer_name,
    '+359 88 ' || lpad((1000000 + floor(random() * 8999999))::BIGINT::TEXT, 7, '0') AS customer_phone,
    lower(names.first_name || '.' || names.last_name || gs || '@example.com') AS customer_email,
    party.party_size,
    reservation_time.start_time,
    reservation_time.start_time + interval '90 minutes' AS end_time,
    status_data.status,
    CASE WHEN status_data.status IN ('CONFIRMED', 'ARRIVED', 'SEATED', 'COMPLETED') THEN reservation_time.start_time - interval '1 day' ELSE NULL END AS confirmed_at,
    CASE WHEN status_data.status IN ('ARRIVED', 'SEATED', 'COMPLETED') THEN reservation_time.start_time + interval '5 minutes' ELSE NULL END AS arrived_at,
    CASE WHEN status_data.status IN ('SEATED', 'COMPLETED') THEN reservation_time.start_time + interval '10 minutes' ELSE NULL END AS seated_at,
    CASE WHEN status_data.status = 'COMPLETED' THEN reservation_time.start_time + interval '90 minutes' ELSE NULL END AS completed_at,
    CASE WHEN status_data.status = 'CANCELLED' THEN reservation_time.start_time - interval '3 hours' ELSE NULL END AS cancelled_at,
    CASE WHEN random() < 0.20 THEN (ARRAY['Window seat requested','Birthday celebration','Quiet table preferred','High chair needed','Nut allergy in party','Anniversary dinner'])[1 + (abs(hashtext(gs::text || 'note')) % 6)] ELSE NULL END AS notes,
    reservation_time.start_time - (interval '1 day' + (random() * 30 || ' days')::interval) AS created_at
FROM generate_series(1, 2000) gs
CROSS JOIN LATERAL (SELECT id FROM restaurant ORDER BY random() LIMIT 1) r
CROSS JOIN LATERAL (
    SELECT
        (ARRAY['Ivan','Maria','Georgi','Elena','Nikolay','Petar','Anna','Alexander','Victoria','Daniel'])[1 + (abs(hashtext(gs::text || 'first')) % 10)] AS first_name,
        (ARRAY['Petrov','Ivanova','Dimitrov','Georgieva','Nikolov','Petrova','Kolev','Stoyanova','Todorov','Marinova'])[1 + (abs(hashtext(gs::text || 'last')) % 10)] AS last_name
) names
CROSS JOIN LATERAL (SELECT 1 + (abs(hashtext(gs::text || 'party')) % 8) AS party_size) party
CROSS JOIN LATERAL (
    SELECT date_trunc('minute', now() - (random() * 365 || ' days')::interval + (11 + floor(random() * 11)) * interval '1 hour') AS start_time
) reservation_time
CROSS JOIN LATERAL (
    SELECT (ARRAY['PENDING','CONFIRMED','CANCELLED','NO_SHOW','ARRIVED','SEATED','COMPLETED'])[1 + (abs(hashtext(gs::text || 'status')) % 7)] AS status
) status_data;