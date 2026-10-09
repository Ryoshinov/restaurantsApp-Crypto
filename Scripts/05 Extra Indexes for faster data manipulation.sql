-- ============================================================================
-- 05 EXTRA INDEXES FOR FASTER DATA MANIPULATION
-- ============================================================================

-- 1. Foreign Key Indexes (Join Optimization)
CREATE INDEX IF NOT EXISTS idx_floor_restaurant_id ON floor(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_table_restaurant_id ON restaurant_table(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_table_floor_id ON restaurant_table(floor_id);
CREATE INDEX IF NOT EXISTS idx_table_seat_table_id ON table_seat(table_id);

CREATE INDEX IF NOT EXISTS idx_role_restaurant_id ON role(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_employee_restaurant_id ON employee(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_employee_role_id ON employee(role_id);

CREATE INDEX IF NOT EXISTS idx_menu_category_restaurant_id ON menu_category(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_menu_item_restaurant_id ON menu_item(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_menu_item_category_id ON menu_item(category_id);

CREATE INDEX IF NOT EXISTS idx_reservation_restaurant_id ON reservation(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_reservation_table_table_id ON reservation_table(table_id);

CREATE INDEX IF NOT EXISTS idx_dining_session_restaurant_id ON dining_session(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_dining_session_reservation_id ON dining_session(reservation_id);
CREATE INDEX IF NOT EXISTS idx_session_table_table_id ON dining_session_table(table_id);

CREATE INDEX IF NOT EXISTS idx_order_restaurant_id ON restaurant_order(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_order_dining_session_id ON restaurant_order(dining_session_id);
CREATE INDEX IF NOT EXISTS idx_order_employee_id ON restaurant_order(employee_id);
CREATE INDEX IF NOT EXISTS idx_order_item_order_id ON order_item(order_id);
CREATE INDEX IF NOT EXISTS idx_order_item_menu_item_id ON order_item(menu_item_id);

CREATE INDEX IF NOT EXISTS idx_check_restaurant_id ON restaurant_check(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_check_dining_session_id ON restaurant_check(dining_session_id);
CREATE INDEX IF NOT EXISTS idx_payment_check_id ON payment(check_id);

-- 2. Analytical View Optimizations
CREATE INDEX IF NOT EXISTS idx_payment_completed_analytics 
ON payment (check_id, completed_at) 
INCLUDE (amount, payment_method) 
WHERE status = 'COMPLETED';

CREATE INDEX IF NOT EXISTS idx_check_status 
ON restaurant_check (status) 
INCLUDE (restaurant_id, total_amount);

CREATE INDEX IF NOT EXISTS idx_dining_session_closed_turnover 
ON dining_session (restaurant_id, started_at) 
INCLUDE (id, guest_count, ended_at) 
WHERE status = 'CLOSED';

CREATE INDEX IF NOT EXISTS idx_order_item_active_sales 
ON order_item (menu_item_id, quantity, unit_price) 
WHERE status != 'CANCELLED';

CREATE INDEX IF NOT EXISTS idx_dining_session_peak_hours 
ON dining_session (restaurant_id, started_at) 
INCLUDE (guest_count) 
WHERE status IN ('OPEN', 'CLOSED');

-- 3. Operational Cleanup & Maintenance Indexes
CREATE INDEX IF NOT EXISTS idx_reservation_expiration_scan 
ON reservation (start_time, end_time) 
WHERE status IN ('PENDING', 'CONFIRMED', 'ARRIVED', 'SEATED');