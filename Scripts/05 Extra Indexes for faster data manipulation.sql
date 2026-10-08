--Here is a complete set of PostgreSQL index creation statements. They cover unindexed foreign keys (to speed up joins and prevent lock escalation on deletes) and composite/partial indexes tailored directly to the analytical views and mock queries built so far.
--1. Foreign Key Indexes (Join Optimization)

--PostgreSQL does not automatically index foreign key columns. Adding B-tree indexes on foreign keys dramatically improves JOIN execution times across the schema:

-- Floor & Table Lookups
CREATE INDEX IF NOT EXISTS idx_floor_restaurant_id ON floor(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_table_restaurant_id ON restaurant_table(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_table_floor_id ON restaurant_table(floor_id);
CREATE INDEX IF NOT EXISTS idx_table_seat_table_id ON table_seat(table_id);

-- Employee & Role Lookups
CREATE INDEX IF NOT EXISTS idx_role_restaurant_id ON role(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_employee_restaurant_id ON employee(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_employee_role_id ON employee(role_id);

-- Menu Structure
CREATE INDEX IF NOT EXISTS idx_menu_category_restaurant_id ON menu_category(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_menu_item_restaurant_id ON menu_item(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_menu_item_category_id ON menu_item(category_id);

-- Reservations & Junction
CREATE INDEX IF NOT EXISTS idx_reservation_restaurant_id ON reservation(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_reservation_table_table_id ON reservation_table(table_id);

-- Dining Session & Junction
CREATE INDEX IF NOT EXISTS idx_dining_session_restaurant_id ON dining_session(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_dining_session_reservation_id ON dining_session(reservation_id);
CREATE INDEX IF NOT EXISTS idx_session_table_table_id ON dining_session_table(table_id);

-- Orders & Items
CREATE INDEX IF NOT EXISTS idx_order_restaurant_id ON restaurant_order(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_order_dining_session_id ON restaurant_order(dining_session_id);
CREATE INDEX IF NOT EXISTS idx_order_employee_id ON restaurant_order(employee_id);
CREATE INDEX IF NOT EXISTS idx_order_item_order_id ON order_item(order_id);
CREATE INDEX IF NOT EXISTS idx_order_item_menu_item_id ON order_item(menu_item_id);

-- Billing & Payments
CREATE INDEX IF NOT EXISTS idx_check_restaurant_id ON restaurant_check(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_check_dining_session_id ON restaurant_check(dining_session_id);
CREATE INDEX IF NOT EXISTS idx_payment_check_id ON payment(check_id);

2. Analytical View Optimizations
For v_daily_revenue

Optimizes date truncation and payment status filtering for completed revenue aggregation:
SQL

-- Partial index for completed payments with covering columns
CREATE INDEX IF NOT EXISTS idx_payment_completed_analytics 
ON payment (check_id, completed_at) 
INCLUDE (amount, payment_method) 
WHERE status = 'COMPLETED';

-- Check status lookup
CREATE INDEX IF NOT EXISTS idx_check_status 
ON restaurant_check (status) 
INCLUDE (restaurant_id, total_amount);

For v_table_turnover

Optimizes table utilization metrics filtered by closed dining sessions:
SQL

-- Filtered index on closed dining sessions with started/ended timestamps
CREATE INDEX IF NOT EXISTS idx_dining_session_closed_turnover 
ON dining_session (restaurant_id, started_at) 
INCLUDE (id, guest_count, ended_at) 
WHERE status = 'CLOSED';

For v_popular_menu_items

Accelerates item-level aggregation by excluding cancelled items:
SQL

-- Partial index on non-cancelled order items
CREATE INDEX IF NOT EXISTS idx_order_item_active_sales 
ON order_item (menu_item_id, quantity, unit_price) 
WHERE status != 'CANCELLED';

For v_peak_dining_hours

Speeds up time/day breakdown queries across active and closed sessions:
SQL

-- Index on session start time filtering out cancelled sessions
CREATE INDEX IF NOT EXISTS idx_dining_session_peak_hours 
ON dining_session (restaurant_id, started_at) 
INCLUDE (guest_count) 
WHERE status IN ('OPEN', 'CLOSED');

3. Operational Cleanup & Maintenance Indexes

Accelerates status expiration background tasks (e.g., expire_past_reservations()):
SQL

-- Fast cleanup scan for past pending/confirmed reservations
CREATE INDEX IF NOT EXISTS idx_reservation_expiration_scan 
ON reservation (start_time, end_time) 
WHERE status IN ('PENDING', 'CONFIRMED', 'ARRIVED', 'SEATED');

---------
2. Analytical View OptimizationsFor v_daily_revenueOptimizes date truncation and payment status filtering for completed revenue aggregation:SQL-- Partial index for completed payments with covering columns
CREATE INDEX IF NOT EXISTS idx_payment_completed_analytics 
ON payment (check_id, completed_at) 
INCLUDE (amount, payment_method) 
WHERE status = 'COMPLETED';

-- Check status lookup
CREATE INDEX IF NOT EXISTS idx_check_status 
ON restaurant_check (status) 
INCLUDE (restaurant_id, total_amount);
For v_table_turnoverOptimizes table utilization metrics filtered by closed dining sessions:SQL-- Filtered index on closed dining sessions with started/ended timestamps
CREATE INDEX IF NOT EXISTS idx_dining_session_closed_turnover 
ON dining_session (restaurant_id, started_at) 
INCLUDE (id, guest_count, ended_at) 
WHERE status = 'CLOSED';
For v_popular_menu_itemsAccelerates item-level aggregation by excluding cancelled items:SQL-- Partial index on non-cancelled order items
CREATE INDEX IF NOT EXISTS idx_order_item_active_sales 
ON order_item (menu_item_id, quantity, unit_price) 
WHERE status != 'CANCELLED';
For v_peak_dining_hoursSpeeds up time/day breakdown queries across active and closed sessions:SQL-- Index on session start time filtering out cancelled sessions
CREATE INDEX IF NOT EXISTS idx_dining_session_peak_hours 
ON dining_session (restaurant_id, started_at) 
INCLUDE (guest_count) 
WHERE status IN ('OPEN', 'CLOSED');
3. Operational Cleanup & Maintenance IndexesAccelerates status expiration background tasks (e.g., expire_past_reservations()):SQL-- Fast cleanup scan for past pending/confirmed reservations
CREATE INDEX IF NOT EXISTS idx_reservation_expiration_scan 
ON reservation (start_time, end_time) 
WHERE status IN ('PENDING', 'CONFIRMED', 'ARRIVED', 'SEATED');
