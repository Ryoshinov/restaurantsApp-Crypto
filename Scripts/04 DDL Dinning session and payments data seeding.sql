-- 1. Clean existing sessions before re-seeding
TRUNCATE TABLE dining_session_table, dining_session CASCADE;

-- 2. Seed Dining Sessions & Map Tables
WITH 
reservation_sessions AS (
    INSERT INTO dining_session
    (
        restaurant_id,
        reservation_id,
        guest_count,
        started_at,
        ended_at,
        status
    )
    SELECT
        r.restaurant_id,
        r.id AS reservation_id,
        r.party_size AS guest_count,
        COALESCE(r.seated_at, r.arrived_at, r.start_time) AS started_at,
        CASE
            WHEN r.status = 'COMPLETED' THEN COALESCE(r.completed_at, r.end_time)
            ELSE NULL
        END AS ended_at,
        CASE
            WHEN r.status = 'COMPLETED' THEN 'CLOSED'
            WHEN r.status IN ('SEATED', 'ARRIVED') THEN 'OPEN'
            ELSE 'CANCELLED'
        END AS status
    FROM reservation r
    WHERE r.status IN ('SEATED', 'ARRIVED', 'COMPLETED')
    RETURNING id AS dining_session_id, restaurant_id, guest_count
),

walkin_times AS (
    SELECT
        rest.id AS restaurant_id,
        gs,
        (1 + (abs(hashtext(rest.id::text || gs::text || 'walkin')) % 6)) AS guest_count,
        date_trunc('minute', NOW() - (random() * 90 || ' days')::interval + (11 + floor(random() * 11)) * interval '1 hour') AS started_at,
        (60 + floor(random() * 60)) * interval '1 minute' AS duration
    FROM restaurant rest
    CROSS JOIN generate_series(1, 300) gs
),

walkin_sessions AS (
    INSERT INTO dining_session
    (
        restaurant_id,
        reservation_id,
        guest_count,
        started_at,
        ended_at,
        status
    )
    SELECT
        restaurant_id,
        NULL AS reservation_id,
        guest_count,
        started_at,
        started_at + duration AS ended_at,
        'CLOSED' AS status
    FROM walkin_times
    RETURNING id AS dining_session_id, restaurant_id, guest_count
),

all_sessions AS (
    SELECT dining_session_id, restaurant_id, guest_count FROM reservation_sessions
    UNION ALL
    SELECT dining_session_id, restaurant_id, guest_count FROM walkin_sessions
)

INSERT INTO dining_session_table (dining_session_id, table_id)
SELECT DISTINCT ON (s.dining_session_id)
    s.dining_session_id,
    t.id AS table_id
FROM all_sessions s
JOIN restaurant_table t 
    ON t.restaurant_id = s.restaurant_id 
   AND t.capacity >= s.guest_count
ORDER BY s.dining_session_id, t.capacity ASC, random();

-- 3. Seed Restaurant Orders & Order Items
WITH 
generated_orders AS (
    INSERT INTO restaurant_order
    (
        restaurant_id,
        dining_session_id,
        employee_id,
        status,
        created_at,
        submitted_at,
        preparing_at,
        ready_at,
        served_at,
        cancelled_at,
        updated_at
    )
    SELECT
        ds.restaurant_id,
        ds.id AS dining_session_id,
        emp.id AS employee_id,
        
        CASE
            WHEN ds.status = 'CLOSED' THEN 'SERVED'
            ELSE (ARRAY['OPEN', 'SUBMITTED', 'PREPARING', 'READY', 'SERVED'])[1 + (abs(hashtext(ds.id::text || o_seq::text)) % 5)]
        END AS status,

        ds.started_at + ((o_seq - 1) * 20 + floor(random() * 10)) * interval '1 minute' AS created_at,
        ds.started_at + ((o_seq - 1) * 20 + floor(random() * 10) + 2) * interval '1 minute' AS submitted_at,
        ds.started_at + ((o_seq - 1) * 20 + floor(random() * 10) + 5) * interval '1 minute' AS preparing_at,
        ds.started_at + ((o_seq - 1) * 20 + floor(random() * 10) + 15) * interval '1 minute' AS ready_at,
        ds.started_at + ((o_seq - 1) * 20 + floor(random() * 10) + 20) * interval '1 minute' AS served_at,
        NULL AS cancelled_at,
        ds.started_at + ((o_seq - 1) * 20 + floor(random() * 10) + 20) * interval '1 minute' AS updated_at

    FROM dining_session ds
    CROSS JOIN LATERAL generate_series(1, 1 + (abs(hashtext(ds.id::text || 'ord_cnt')) % 3)) o_seq
    LEFT JOIN LATERAL (
        SELECT id 
        FROM employee 
        WHERE restaurant_id = ds.restaurant_id AND active = TRUE
        ORDER BY random() 
        LIMIT 1
    ) emp ON TRUE
    WHERE ds.status IN ('OPEN', 'CLOSED')
    RETURNING id AS order_id, restaurant_id, status AS order_status, created_at
)

INSERT INTO order_item
(
    order_id,
    menu_item_id,
    quantity,
    unit_price,
    status,
    created_at
)
SELECT
    go.order_id,
    mi.id AS menu_item_id,
    1 + (abs(hashtext(go.order_id::text || item_seq::text || 'qty')) % 3) AS quantity,
    COALESCE(CASE WHEN mi.discount_active THEN mi.discounted_price END, mi.price) AS unit_price,
    go.order_status AS status,
    go.created_at
FROM generated_orders go
CROSS JOIN LATERAL generate_series(1, 1 + (abs(hashtext(go.order_id::text || 'item_cnt')) % 4)) item_seq
JOIN LATERAL (
    SELECT id, price, discounted_price, discount_active
    FROM menu_item 
    WHERE restaurant_id = go.restaurant_id AND active = TRUE
    ORDER BY abs(hashtext(go.order_id::text || item_seq::text || id::text))
    LIMIT 1
) mi ON TRUE;

-- 4. Seed Checks & Payments
WITH 
session_totals AS (
    SELECT
        ds.id AS dining_session_id,
        ds.restaurant_id,
        ds.status AS session_status,
        ds.started_at,
        ds.ended_at,
        COALESCE(SUM(oi.quantity * oi.unit_price), 0.00) AS calculated_total
    FROM dining_session ds
    JOIN restaurant_order ro ON ro.dining_session_id = ds.id
    JOIN order_item oi ON oi.order_id = ro.id
    WHERE ro.status != 'CANCELLED' AND oi.status != 'CANCELLED'
    GROUP BY ds.id, ds.restaurant_id, ds.status, ds.started_at, ds.ended_at
    HAVING SUM(oi.quantity * oi.unit_price) > 0
),

inserted_checks AS (
    INSERT INTO restaurant_check
    (
        restaurant_id,
        dining_session_id,
        status,
        total_amount,
        opened_at,
        closed_at
    )
    SELECT
        st.restaurant_id,
        st.dining_session_id,

        CASE
            WHEN st.session_status = 'CLOSED' THEN 'PAID'
            ELSE 'OPEN'
        END AS status,

        st.calculated_total AS total_amount,

        CASE
            WHEN st.session_status = 'CLOSED' THEN st.ended_at - interval '15 minutes'
            ELSE st.started_at + interval '10 minutes'
        END AS opened_at,

        CASE
            WHEN st.session_status = 'CLOSED' THEN st.ended_at
            ELSE NULL
        END AS closed_at

    FROM session_totals st
    RETURNING id AS check_id, restaurant_id, status AS check_status, total_amount, opened_at, closed_at
)

INSERT INTO payment
(
    check_id,
    amount,
    payment_method,
    status,
    initiated_at,
    completed_at,
    failed_at,
    refunded_at
)
SELECT
    ic.check_id,
    ic.total_amount AS amount,

    (ARRAY['CARD', 'CASH', 'CARD', 'CARD', 'BANK_TRANSFER'])[1 + (abs(hashtext(ic.check_id::text)) % 5)] AS payment_method,

    'COMPLETED' AS status,

    ic.closed_at - interval '2 minutes' AS initiated_at,
    ic.closed_at AS completed_at,
    NULL AS failed_at,
    NULL AS refunded_at

FROM inserted_checks ic
WHERE ic.check_status = 'PAID';