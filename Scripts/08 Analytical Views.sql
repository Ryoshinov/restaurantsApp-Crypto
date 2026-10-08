-- Daily revenue view 
CREATE OR REPLACE VIEW v_daily_revenue as
SELECT
    rc.restaurant_id,
    r.name AS restaurant_name,
    DATE_TRUNC('day', p.completed_at)::DATE AS sales_date,
    COUNT(DISTINCT rc.id) AS total_checks,
    COUNT(p.id) AS total_payments,
    SUM(p.amount) AS gross_revenue,
    ROUND(AVG(rc.total_amount), 2) AS avg_check_amount,
    
    -- Payment methods used
    SUM(CASE WHEN p.payment_method = 'CARD' THEN p.amount ELSE 0 END) AS card_revenue,
    SUM(CASE WHEN p.payment_method = 'CASH' THEN p.amount ELSE 0 END) AS cash_revenue,
    SUM(CASE WHEN p.payment_method NOT IN ('CARD', 'CASH') THEN p.amount ELSE 0 END) AS other_revenue
FROM payment p
JOIN restaurant_check rc ON rc.id = p.check_id
JOIN restaurant r ON r.id = rc.restaurant_id
WHERE p.status = 'COMPLETED'
GROUP BY 
    rc.restaurant_id, 
    r.name, 
    DATE_TRUNC('day', p.completed_at)::DATE;
    
-- Table turns and utilization:
    
    CREATE OR REPLACE VIEW v_table_turnover AS
SELECT
    rt.restaurant_id,
    rt.id AS table_id,
    rt.table_number,
    f.name AS floor_name,
    rt.capacity,
    DATE_TRUNC('day', ds.started_at)::DATE AS activity_date,
    
    COUNT(DISTINCT ds.id) AS total_sessions,
    SUM(ds.guest_count) AS total_guests_seated,
    ROUND(
        SUM(ds.guest_count)::NUMERIC / NULLIF(rt.capacity * COUNT(DISTINCT ds.id), 0) * 100, 
        2
    ) AS avg_seat_occupancy_pct,
    
    ROUND(
        AVG(EXTRACT(EPOCH FROM (ds.ended_at - ds.started_at)) / 60)::NUMERIC, 
        1
    ) AS avg_duration_minutes
FROM dining_session ds
JOIN dining_session_table dst ON dst.dining_session_id = ds.id
JOIN restaurant_table rt ON rt.id = dst.table_id
JOIN floor f ON f.id = rt.floor_id
WHERE ds.status = 'CLOSED' AND ds.ended_at IS NOT NULL
GROUP BY 
    rt.restaurant_id, 
    rt.id, 
    rt.table_number, 
    f.name, 
    rt.capacity, 
    DATE_TRUNC('day', ds.started_at)::DATE;
    
 -- Popular menu items and Sales performance:
    
 CREATE OR REPLACE VIEW v_popular_menu_items AS
SELECT
    mi.restaurant_id,
    mc.name AS category_name,
    mi.id AS menu_item_id,
    mi.name AS item_name,
    mi.price AS current_price,
    
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * oi.unit_price) AS total_gross_sales,
    
    DENSE_RANK() OVER (
        PARTITION BY mi.restaurant_id 
        ORDER BY SUM(oi.quantity) DESC
    ) AS rank_by_units,
    
    DENSE_RANK() OVER (
        PARTITION BY mi.restaurant_id 
        ORDER BY SUM(oi.quantity * oi.unit_price) DESC
    ) AS rank_by_revenue
FROM order_item oi
JOIN menu_item mi ON mi.id = oi.menu_item_id
JOIN menu_category mc ON mc.id = mi.category_id
WHERE oi.status != 'CANCELLED'
GROUP BY 
    mi.restaurant_id, 
    mc.name, 
    mi.id, 
    mi.name, 
    mi.price;
    
 -- Peak dinning hours:
    
 CREATE OR REPLACE VIEW v_peak_dining_hours AS
SELECT
    ds.restaurant_id,
    TO_CHAR(ds.started_at, 'FMDay') AS day_of_week,
    EXTRACT(ISODOW FROM ds.started_at) AS day_number, -- 1=Mon, 7=Sun
    EXTRACT(HOUR FROM ds.started_at) AS hour_of_day,
    
    COUNT(ds.id) AS total_sessions,
    SUM(ds.guest_count) AS total_guests,
    ROUND(AVG(ds.guest_count), 1) AS avg_party_size
FROM dining_session ds
WHERE ds.status IN ('OPEN', 'CLOSED')
GROUP BY 
    ds.restaurant_id,
    TO_CHAR(ds.started_at, 'FMDay'),
    EXTRACT(ISODOW FROM ds.started_at),
    EXTRACT(HOUR FROM ds.started_at);
    
--- Most Ordered item per restaurant:
    
CREATE OR REPLACE VIEW v_top_ordered_item_per_restaurant AS
WITH ranked_items AS (
    SELECT
        r.id AS restaurant_id,
        r.name AS restaurant_name,
        mi.id AS menu_item_id,
        mi.name AS item_name,
        mc.name AS category_name,
        SUM(oi.quantity) AS total_units_sold,
        SUM(oi.quantity * oi.unit_price) AS total_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY r.id 
            ORDER BY SUM(oi.quantity) DESC, SUM(oi.quantity * oi.unit_price) DESC
        ) AS rank
    FROM order_item oi
    JOIN menu_item mi ON mi.id = oi.menu_item_id
    JOIN menu_category mc ON mc.id = mi.category_id
    JOIN restaurant r ON r.id = mi.restaurant_id
    WHERE oi.status != 'CANCELLED'
    GROUP BY r.id, r.name, mi.id, mi.name, mc.name
)
SELECT
    restaurant_id,
    restaurant_name,
    menu_item_id,
    item_name,
    category_name,
    total_units_sold,
    total_revenue
FROM ranked_items
WHERE rank = 1;
    
-- Busiest day by total customers on restaurant:
CREATE OR REPLACE VIEW v_busiest_days_by_customers AS
SELECT
    r.id AS restaurant_id,
    r.name AS restaurant_name,
    TO_CHAR(ds.started_at, 'FMDay') AS day_of_week,
    EXTRACT(ISODOW FROM ds.started_at) AS day_number,
    COUNT(ds.id) AS total_sessions,
    SUM(ds.guest_count) AS total_customers,
    ROUND(AVG(ds.guest_count), 2) AS avg_party_size,
    DENSE_RANK() OVER (
        PARTITION BY r.id 
        ORDER BY SUM(ds.guest_count) DESC
    ) AS customer_volume_rank
FROM dining_session ds
JOIN restaurant r ON r.id = ds.restaurant_id
WHERE ds.status IN ('OPEN', 'CLOSED')
GROUP BY 
    r.id, 
    r.name, 
    TO_CHAR(ds.started_at, 'FMDay'), 
    EXTRACT(ISODOW FROM ds.started_at);
-- SELECT FROM VIEW FOR BUSIEST DAY:
SELECT 
    day_of_week, 
    total_customers, 
    total_sessions, 
    avg_party_size
FROM v_busiest_days_by_customers
WHERE restaurant_id = 1
ORDER BY customer_volume_rank ASC;
-- Staff performance view - still in process - down are some metrics:
-- total_gross_sales & avg_sales_per_session: Measures employee revenue contribution and upselling efficiency per table/session.
--avg_time_to_submit_min: Measures waiter input speed (how fast they enter customer choices into the POS after opening the order).
--avg_kitchen_prep_min: Tracks back-of-house efficiency from order submission to item readiness.
--avg_time_to_serve_min: Measures table delivery efficiency (how long food sits on the pass before the server takes it to the customer).
--avg_total_fulfillment_min: Full turn-around metric from order creation to table delivery.
CREATE OR REPLACE VIEW v_employee_performance AS
SELECT
    r.id AS restaurant_id,
    r.name AS restaurant_name,
    e.id AS employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    ro_role.name AS role_name,
    
    -- Volume & Sales Metrics
    COUNT(DISTINCT ro.id) AS total_orders_handled,
    COUNT(DISTINCT ro.dining_session_id) AS total_sessions_served,
    COALESCE(SUM(oi.quantity * oi.unit_price), 0.00) AS total_gross_sales,
    
    ROUND(
        COALESCE(SUM(oi.quantity * oi.unit_price), 0.00) / 
        NULLIF(COUNT(DISTINCT ro.dining_session_id), 0), 
        2
    ) AS avg_sales_per_session,

    -- Order Fulfillment & Kitchen Speed (in minutes)
    -- 1. Time from order creation to kitchen submission
    ROUND(
        AVG(EXTRACT(EPOCH FROM (ro.submitted_at - ro.created_at)) / 60)::NUMERIC,
        2
    ) AS avg_time_to_submit_min,

    -- 2. Kitchen preparation time (from submitted/preparing to ready)
    ROUND(
        AVG(EXTRACT(EPOCH FROM (ro.ready_at - COALESCE(ro.preparing_at, ro.submitted_at))) / 60)::NUMERIC,
        2
    ) AS avg_kitchen_prep_min,

    -- 3. Delivery speed (from ready to served)
    ROUND(
        AVG(EXTRACT(EPOCH FROM (ro.served_at - ro.ready_at)) / 60)::NUMERIC,
        2
    ) AS avg_time_to_serve_min,

    -- 4. Total order lifecycle duration (from creation to served)
    ROUND(
        AVG(EXTRACT(EPOCH FROM (ro.served_at - ro.created_at)) / 60)::NUMERIC,
        2
    ) AS avg_total_fulfillment_min

FROM employee e
JOIN restaurant r ON r.id = e.restaurant_id
LEFT JOIN role ro_role ON ro_role.id = e.role_id
JOIN restaurant_order ro ON ro.employee_id = e.id
JOIN order_item oi ON oi.order_id = ro.id
WHERE ro.status != 'CANCELLED' 
  AND oi.status != 'CANCELLED'
GROUP BY
    r.id,
    r.name,
    e.id,
    e.first_name,
    e.last_name,
    ro_role.name;